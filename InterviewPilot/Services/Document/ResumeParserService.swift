import Foundation
import PDFKit

enum ResumeParserService {
    static func extractText(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }

        var fullText = ""
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        return fullText.isEmpty ? nil : fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractText(from data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }

        var fullText = ""
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        return fullText.isEmpty ? nil : fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
