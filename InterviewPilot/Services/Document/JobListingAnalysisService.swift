import Foundation
import UIKit
@preconcurrency import WebKit

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
        var staticCandidate: ExtractionCandidate?
        var staticFailure: Error?

        do {
            staticCandidate = try await fetchStaticCandidate(from: url)

            if let staticCandidate,
               let analysis = buildAnalysis(from: staticCandidate, fallbackURL: url) {
                return analysis
            }
        } catch {
            staticFailure = error
        }

        do {
            let renderedCandidate = try await RenderedPageExtractor.extract(from: url)
            let mergedCandidate = merge(primary: renderedCandidate, fallback: staticCandidate)

            if let analysis = buildAnalysis(from: mergedCandidate, fallbackURL: url) {
                return analysis
            }
        } catch {
            if staticFailure == nil {
                staticFailure = error
            }
        }

        if let staticFailure {
            throw staticFailure
        }

        throw JobListingAnalysisError.unusableContent
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

    private static func fetchStaticCandidate(from url: URL) async throws -> ExtractionCandidate {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JobListingAnalysisError.fetchFailed("The job listing did not return a valid response.")
        }

        guard (200..<400).contains(httpResponse.statusCode) else {
            throw JobListingAnalysisError.fetchFailed("The job listing returned HTTP \(httpResponse.statusCode).")
        }

        let resolvedURL = httpResponse.url ?? url
        let html = decodeHTML(data: data)
        let structuredJobPosting = extractStructuredJobPosting(from: html, baseURL: resolvedURL)
        let sanitizedHTML = stripHTMLNoise(from: html)

        let title = structuredJobPosting.title ?? extractMetadata(using: [
            #"(?is)<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
            #"(?is)<meta[^>]+name=["']twitter:title["'][^>]+content=["']([^"']+)["']"#,
            #"(?is)<title[^>]*>(.*?)</title>"#
        ], from: sanitizedHTML)
        let description = structuredJobPosting.description ?? extractMetadata(using: [
            #"(?is)<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']"#,
            #"(?is)<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']"#
        ], from: sanitizedHTML)
        let canonicalURL = structuredJobPosting.canonicalURL
            ?? extractCanonicalURL(from: sanitizedHTML, baseURL: resolvedURL)
            ?? resolvedURL

        let extractedSegments = [
            structuredJobPosting.bodyText,
            extractPlainText(from: sanitizedHTML)
        ].compactMap { value -> String? in
            let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return normalized.isEmpty ? nil : normalized
        }

        return ExtractionCandidate(
            title: title,
            description: description,
            bodyText: deduplicateSegments(extractedSegments),
            canonicalURL: canonicalURL
        )
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

    private static func extractCanonicalURL(from html: String, baseURL: URL) -> URL? {
        let href = extractMetadata(
            using: [#"(?is)<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']"#],
            from: html
        )

        return normalizedURLCandidate(from: href, baseURL: baseURL)
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

    private static func buildAnalysis(from candidate: ExtractionCandidate, fallbackURL: URL) -> JobListingAnalysis? {
        let extractedText = normalizeExtractedText(
            title: candidate.title,
            description: candidate.description,
            bodyText: candidate.bodyText
        )

        guard extractedText.count >= 140 else {
            return nil
        }

        let resolvedURL = candidate.canonicalURL ?? fallbackURL
        let resolvedTitle = candidate.title ?? fallbackTitle(for: resolvedURL)

        return JobListingAnalysis(
            url: resolvedURL,
            title: resolvedTitle,
            extractedText: extractedText,
            jobCategory: JobCategory.infer(from: extractedText, title: resolvedTitle),
            positionLevel: PositionLevel.infer(from: extractedText, title: resolvedTitle)
        )
    }

    private static func merge(primary: ExtractionCandidate, fallback: ExtractionCandidate?) -> ExtractionCandidate {
        guard let fallback else { return primary }

        return ExtractionCandidate(
            title: firstNonEmpty(primary.title, fallback.title),
            description: firstNonEmpty(primary.description, fallback.description),
            bodyText: deduplicateSegments([primary.bodyText, fallback.bodyText]),
            canonicalURL: primary.canonicalURL ?? fallback.canonicalURL
        )
    }

    private static func firstNonEmpty(_ lhs: String?, _ rhs: String?) -> String? {
        let left = lhs?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let left, !left.isEmpty {
            return left
        }

        let right = rhs?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let right, !right.isEmpty {
            return right
        }

        return nil
    }

    private static func deduplicateSegments(_ segments: [String]) -> String {
        var seen = Set<String>()
        var result: [String] = []

        for segment in segments {
            for line in segment.components(separatedBy: .newlines) {
                let normalized = line
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !normalized.isEmpty else { continue }

                let key = normalized.lowercased()
                if seen.insert(key).inserted {
                    result.append(normalized)
                }
            }
        }

        return result.joined(separator: "\n")
    }

    private static func extractStructuredJobPosting(from html: String, baseURL: URL) -> StructuredJobPosting {
        let scripts = extractJSONLDScripts(from: html)
        let candidates = scripts.compactMap { script in
            parseStructuredJobPosting(from: script, baseURL: baseURL)
        }

        let bestCandidate = candidates.max { lhs, rhs in
            lhs.textScore < rhs.textScore
        }

        return bestCandidate ?? StructuredJobPosting()
    }

    private static func extractJSONLDScripts(from html: String) -> [String] {
        let pattern = #"(?is)<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        return matches.compactMap { match in
            guard let scriptRange = Range(match.range(at: 1), in: html) else { return nil }
            let raw = String(html[scriptRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
    }

    private static func parseStructuredJobPosting(from jsonString: String, baseURL: URL) -> StructuredJobPosting? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let jobPostings = collectStructuredJobPostings(from: jsonObject, baseURL: baseURL)
        return jobPostings.max { lhs, rhs in
            lhs.textScore < rhs.textScore
        }
    }

    private static func collectStructuredJobPostings(from jsonObject: Any, baseURL: URL) -> [StructuredJobPosting] {
        switch jsonObject {
        case let array as [Any]:
            return array.flatMap { collectStructuredJobPostings(from: $0, baseURL: baseURL) }

        case let dictionary as [String: Any]:
            var results: [StructuredJobPosting] = []

            if isJobPosting(dictionary) {
                results.append(buildStructuredJobPosting(from: dictionary, baseURL: baseURL))
            }

            for value in dictionary.values {
                results.append(contentsOf: collectStructuredJobPostings(from: value, baseURL: baseURL))
            }

            return results

        default:
            return []
        }
    }

    private static func isJobPosting(_ dictionary: [String: Any]) -> Bool {
        if let type = dictionary["@type"] as? String,
           type.localizedCaseInsensitiveContains("JobPosting") {
            return true
        }

        if let types = dictionary["@type"] as? [String],
           types.contains(where: { $0.localizedCaseInsensitiveContains("JobPosting") }) {
            return true
        }

        return dictionary["description"] != nil && dictionary["hiringOrganization"] != nil
    }

    private static func buildStructuredJobPosting(from dictionary: [String: Any], baseURL: URL) -> StructuredJobPosting {
        let bodySegments: [String?] = [
            stringValue(from: dictionary["description"]),
            stringValue(from: dictionary["responsibilities"]),
            stringValue(from: dictionary["qualifications"]),
            stringValue(from: dictionary["skills"]),
            stringValue(from: dictionary["experienceRequirements"]),
            stringValue(from: dictionary["educationRequirements"]),
            stringValue(from: dictionary["jobBenefits"]),
            stringValue(from: dictionary["occupationalCategory"]),
            stringValue(from: dictionary["industry"]),
            stringValue(from: dictionary["employmentType"]),
            stringValue(from: dictionary["validThrough"])
        ]

        let organization = stringValue(from: dictionary["hiringOrganization"])
        let location = stringValue(from: dictionary["jobLocation"])
        let baseBody = deduplicateSegments(bodySegments.compactMap { $0 })
        let enrichedBody = deduplicateSegments([organization, location, baseBody].compactMap { $0 })

        return StructuredJobPosting(
            title: stringValue(from: dictionary["title"]) ?? stringValue(from: dictionary["name"]),
            description: stringValue(from: dictionary["description"]),
            bodyText: enrichedBody,
            canonicalURL: normalizedURLCandidate(
                from: stringValue(from: dictionary["url"]) ?? stringValue(from: dictionary["sameAs"]),
                baseURL: baseURL
            )
        )
    }

    private static func stringValue(from rawValue: Any?) -> String? {
        guard let rawValue else { return nil }

        if let string = rawValue as? String {
            let normalized = decodeHTMLEntities(in: string)
                .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
                .replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return normalized.isEmpty ? nil : normalized
        }

        if let number = rawValue as? NSNumber {
            return number.stringValue
        }

        if let array = rawValue as? [Any] {
            let combined = array.compactMap { stringValue(from: $0) }
            return combined.isEmpty ? nil : deduplicateSegments(combined)
        }

        if let dictionary = rawValue as? [String: Any] {
            let preferredKeys = [
                "name",
                "title",
                "value",
                "text",
                "description",
                "streetAddress",
                "addressLocality",
                "addressRegion",
                "postalCode",
                "addressCountry"
            ]

            let preferredValues = preferredKeys.compactMap { stringValue(from: dictionary[$0]) }
            if !preferredValues.isEmpty {
                return deduplicateSegments(preferredValues)
            }

            let combined = dictionary.values.compactMap { stringValue(from: $0) }
            return combined.isEmpty ? nil : deduplicateSegments(combined)
        }

        return nil
    }

    private static func normalizedURLCandidate(from rawValue: String?, baseURL: URL) -> URL? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absolute = URL(string: trimmed), let scheme = absolute.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return absolute
        }

        if let relative = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL,
           let scheme = relative.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return relative
        }

        return nil
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

private struct ExtractionCandidate {
    let title: String?
    let description: String?
    let bodyText: String
    let canonicalURL: URL?
}

private struct StructuredJobPosting {
    var title: String?
    var description: String?
    var bodyText: String?
    var canonicalURL: URL?

    var textScore: Int {
        [title, description, bodyText]
            .compactMap { $0?.count }
            .reduce(0, +)
    }
}

private struct RenderedPageSnapshot: Decodable {
    let title: String
    let description: String
    let bodyText: String
    let canonicalURL: String
}

private final class RenderedPageExtractor: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<ExtractionCandidate, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var hasFinished = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.suppressesIncrementalRendering = false

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isHidden = true
    }

    @MainActor
    static func extract(from url: URL) async throws -> ExtractionCandidate {
        let extractor = RenderedPageExtractor()
        return try await extractor.load(url: url)
    }

    @MainActor
    private func load(url: URL) async throws -> ExtractionCandidate {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ExtractionCandidate, Error>) in
            self.continuation = continuation

            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                self?.complete(with: .failure(JobListingAnalysisError.fetchFailed("The job listing timed out while loading.")))
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 25
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

            webView.load(request)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await self.captureSnapshot()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(with: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        complete(with: .failure(error))
    }

    @MainActor
    private func captureSnapshot() async {
        let script = #"""
        (() => {
          const content = (selectors) => {
            for (const selector of selectors) {
              const match = document.querySelector(selector);
              const value = match?.content || match?.innerText || match?.textContent || '';
              if (value && value.trim().length > 0) { return value.trim(); }
            }
            return '';
          };

          const canonical = () => {
            const link = document.querySelector('link[rel="canonical"]');
            const href = link?.href || '';
            return href.trim().length > 0 ? href.trim() : (window.location.href || '');
          };

          return JSON.stringify({
            title: document.title || '',
            description: content([
              'meta[name="description"]',
              'meta[property="og:description"]',
              'meta[name="twitter:description"]'
            ]),
            bodyText: document.body?.innerText || '',
            canonicalURL: canonical()
          });
        })();
        """#

        do {
            let result = try await webView.evaluateJavaScript(script)
            guard let json = result as? String,
                  let data = json.data(using: .utf8) else {
                throw JobListingAnalysisError.unusableContent
            }

            let snapshot = try JSONDecoder().decode(RenderedPageSnapshot.self, from: data)
            let candidate = ExtractionCandidate(
                title: snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                description: snapshot.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                bodyText: snapshot.bodyText,
                canonicalURL: URL(string: snapshot.canonicalURL)
            )

            complete(with: .success(candidate))
        } catch {
            complete(with: .failure(error))
        }
    }

    @MainActor
    private func complete(with result: Result<ExtractionCandidate, Error>) {
        guard !hasFinished, let continuation else { return }

        hasFinished = true
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil

        switch result {
        case .success(let candidate):
            continuation.resume(returning: candidate)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
