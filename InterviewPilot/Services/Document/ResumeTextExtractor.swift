import Foundation
import PDFKit
import UIKit
import Vision

/// Multi-format resume text extractor with Vision OCR fallback for scanned PDFs.
///
/// Single entry point: `ResumeTextExtractor.extract(...)`. Returns a `Result`
/// describing the source format, page count, whether OCR was used, and the
/// extracted plain text — already trimmed and length-capped so it can be
/// handed straight to the LLM.
///
/// All work runs on a background-isolated executor so callers can `await` it
/// from `@MainActor` without blocking the UI.
enum ResumeTextExtractor {
    enum Failure: LocalizedError, Sendable {
        case unsupportedFormat
        case fileTooLarge(bytes: Int)
        case empty
        case corrupted
        case ocrFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "We can read PDF, DOCX, RTF, Markdown and plain text resumes."
            case .fileTooLarge(let bytes):
                let mb = Double(bytes) / (1024 * 1024)
                return String(format: "Resume file is too large (%.1f MB). The maximum is %.0f MB.", mb, Double(maxFileBytes) / (1024 * 1024))
            case .empty:
                return "We couldn't find any text in this file. If it's a scanned PDF, try a higher-quality scan or paste the text manually."
            case .corrupted:
                return "This file appears to be corrupted or password-protected."
            case .ocrFailed(let detail):
                return "Optical character recognition failed: \(detail)"
            case .cancelled:
                return "Resume processing was cancelled."
            }
        }
    }

    struct Result: Sendable {
        let text: String
        let format: ResumeFileFormat
        let pageCount: Int?
        let usedOCR: Bool
    }

    nonisolated static let maxFileBytes = 15 * 1024 * 1024
    nonisolated static let maxCharacterCount = 60_000
    /// If a PDF page yields fewer than this many extracted characters, we
    /// suspect it's a scanned image and try OCR.
    nonisolated static let ocrThresholdPerPage = 80

    nonisolated static func extract(from url: URL) async throws -> Result {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw Failure.corrupted
        }
        return try await extract(from: data, filename: url.lastPathComponent)
    }

    nonisolated static func extract(from data: Data, filename: String?) async throws -> Result {
        guard data.count <= maxFileBytes else {
            throw Failure.fileTooLarge(bytes: data.count)
        }
        guard let format = ResumeFileFormat.detect(filename: filename, data: data) else {
            throw Failure.unsupportedFormat
        }

        try Task.checkCancellation()

        let raw: String
        var pageCount: Int?
        var usedOCR = false

        switch format {
        case .pdf:
            let pdf = try extractPDFText(from: data)
            raw = pdf.text
            pageCount = pdf.pageCount
            if pdf.shouldOCR {
                let ocr = try await runOCR(on: pdf.document)
                if ocr.count > raw.count {
                    return finalize(text: ocr, format: .pdf, pageCount: pdf.pageCount, usedOCR: true)
                }
                usedOCR = true  // attempted but didn't beat the text layer
            }
        case .rtf:
            raw = try extractAttributedString(from: data, type: .rtf)
        case .plainText, .markdown:
            guard let text = decodeText(data: data) else {
                throw Failure.corrupted
            }
            raw = text
        }

        return finalize(text: raw, format: format, pageCount: pageCount, usedOCR: usedOCR)
    }

    // MARK: - PDF

    private struct PDFExtraction: Sendable {
        let text: String
        let pageCount: Int
        let shouldOCR: Bool
        let document: PDFDocument
    }

    nonisolated private static func extractPDFText(from data: Data) throws -> PDFExtraction {
        guard let document = PDFDocument(data: data) else {
            throw Failure.corrupted
        }
        if document.isLocked {
            throw Failure.corrupted
        }

        var pieces: [String] = []
        var emptyPages = 0
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageText = page.string ?? ""
            pieces.append(pageText)
            if pageText.trimmingCharacters(in: .whitespacesAndNewlines).count < ocrThresholdPerPage {
                emptyPages += 1
            }
        }

        let text = pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // Trigger OCR if more than half the pages came back near-empty, OR
        // total extracted text is implausibly small for a resume.
        let shouldOCR = (document.pageCount > 0 && emptyPages * 2 >= document.pageCount)
            || text.count < ocrThresholdPerPage
        return PDFExtraction(text: text, pageCount: document.pageCount, shouldOCR: shouldOCR, document: document)
    }

    nonisolated private static func runOCR(on document: PDFDocument) async throws -> String {
        var pages: [String] = []
        for i in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: i) else { continue }

            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0  // 2x renders ~144 DPI — sweet spot for OCR accuracy vs memory
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.translateBy(x: 0, y: size.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            guard let cg = image.cgImage else { continue }

            let recognized = try await recognizeText(in: cg)
            pages.append(recognized)
        }
        return pages.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: Failure.ocrFailed(error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: Failure.ocrFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Attributed string formats

    nonisolated private static func extractAttributedString(
        from data: Data,
        type: NSAttributedString.DocumentType
    ) throws -> String {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: type,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        do {
            let attr = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return attr.string
        } catch {
            throw Failure.corrupted
        }
    }

    // MARK: - Plain text

    nonisolated private static func decodeText(data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        return String(data: data, encoding: .isoLatin1)
    }

    // MARK: - Finalize

    nonisolated private static func finalize(
        text: String,
        format: ResumeFileFormat,
        pageCount: Int?,
        usedOCR: Bool
    ) -> Result {
        let cleaned = normalize(text)
        return Result(text: cleaned, format: format, pageCount: pageCount, usedOCR: usedOCR)
    }

    /// Collapses runs of whitespace, strips zero-width characters, normalizes
    /// line endings, and caps total length so the LLM call stays within
    /// budget regardless of resume size.
    nonisolated private static func normalize(_ text: String) -> String {
        var out = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{200B}", with: "")  // zero-width space
            .replacingOccurrences(of: "\u{FEFF}", with: "")  // BOM
        // Collapse 3+ consecutive newlines to 2.
        while out.contains("\n\n\n") {
            out = out.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.count > maxCharacterCount {
            let idx = out.index(out.startIndex, offsetBy: maxCharacterCount)
            out = String(out[..<idx])
        }
        return out
    }
}
