import Foundation
import UIKit

struct JobListingAnalysis: Sendable {
    let url: URL
    let title: String
    let extractedText: String
    let jobCategory: JobCategory
    let positionLevel: PositionLevel
}

enum JobListingAnalysisError: LocalizedError {
    case invalidURL
    case unsupportedURLScheme
    case fetchFailed(String)
    case unusableContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid job listing URL."
        case .unsupportedURLScheme:
            return "Use an http or https job listing URL."
        case .fetchFailed(let detail):
            return detail
        case .unusableContent:
            return "The job listing could not be parsed. Try a different public listing URL."
        }
    }
}

enum JobListingAnalysisService {
    static func analyze(urlText: String) async throws -> JobListingAnalysis {
        let url = try normalizeURL(from: urlText)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JobListingAnalysisError.fetchFailed("The job listing did not return a valid response.")
        }

        guard (200..<400).contains(httpResponse.statusCode) else {
            throw JobListingAnalysisError.fetchFailed("The job listing returned HTTP \(httpResponse.statusCode).")
        }

        let html = decodeHTML(data: data)
        let sanitizedHTML = stripHTMLNoise(from: html)

        let title = extractMetadata(using: [
            #"(?is)<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
            #"(?is)<meta[^>]+name=["']twitter:title["'][^>]+content=["']([^"']+)["']"#,
            #"(?is)<title[^>]*>(.*?)</title>"#
        ], from: sanitizedHTML)
        let description = extractMetadata(using: [
            #"(?is)<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']"#,
            #"(?is)<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']"#
        ], from: sanitizedHTML)

        let bodyText = extractPlainText(from: sanitizedHTML)
        let extractedText = normalizeExtractedText(title: title, description: description, bodyText: bodyText)

        guard extractedText.count >= 180 else {
            throw JobListingAnalysisError.unusableContent
        }

        return JobListingAnalysis(
            url: url,
            title: title ?? fallbackTitle(for: url),
            extractedText: extractedText,
            jobCategory: JobCategory.infer(from: extractedText, title: title),
            positionLevel: PositionLevel.infer(from: extractedText, title: title)
        )
    }

    private static func normalizeURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw JobListingAnalysisError.invalidURL
        }

        let candidate = URL(string: trimmed) ?? URL(string: "https://\(trimmed)")
        guard let candidate else {
            throw JobListingAnalysisError.invalidURL
        }

        guard let scheme = candidate.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw JobListingAnalysisError.unsupportedURLScheme
        }

        return candidate
    }

    private static func decodeHTML(data: Data) -> String {
        if let html = String(data: data, encoding: .utf8), !html.isEmpty {
            return html
        }

        return String(decoding: data, as: UTF8.self)
    }

    private static func stripHTMLNoise(from html: String) -> String {
        var cleaned = html
        let patterns = [
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<noscript\b[^>]*>.*?</noscript>"#,
            #"(?is)<svg\b[^>]*>.*?</svg>"#
        ]

        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return cleaned
    }

    private static func extractMetadata(using patterns: [String], from html: String) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, range: range),
                  let captureRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let raw = String(html[captureRange])
            let value = decodeHTMLEntities(in: raw)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private static func extractPlainText(from html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return decodeHTMLEntities(in: html)
        }

        return attributed.string
    }

    private static func normalizeExtractedText(
        title: String?,
        description: String?,
        bodyText: String
    ) -> String {
        let bodyLines = bodyText
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty &&
                line.count > 2 &&
                !["apply", "save job", "share", "sign in"].contains(line.lowercased())
            }

        let uniqueLines = bodyLines.reduce(into: [String]()) { result, line in
            if result.last != line {
                result.append(line)
            }
        }

        let combined = ([title, description].compactMap { $0 } + uniqueLines)
            .joined(separator: "\n")
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if combined.count <= 12_000 {
            return combined
        }

        let prefix = String(combined.prefix(12_000))
        if let lastNewline = prefix.lastIndex(of: "\n") {
            return String(prefix[..<lastNewline]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        guard let data = text.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return text
        }

        return attributed.string
    }

    private static func fallbackTitle(for url: URL) -> String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }
}
