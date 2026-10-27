import Foundation

struct ImportedJobDescription: Sendable, Equatable {
    let url: URL
    let title: String
    let company: String
    let text: String
}

enum JobDescriptionImportError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case unsafeURL
    case blockedPage
    case insufficientContent
    case tooLarge
    case timedOut
    case unsupportedContent
    case httpStatus(Int)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a complete http or https job posting URL, or paste the job description."
        case .unsafeURL:
            return "Use a public job website without sign-in details or a custom port. Local and private addresses cannot be imported."
        case .blockedPage:
            return "This site requires sign-in, JavaScript, or a verification check. Open the posting in your browser and paste its job description."
        case .insufficientContent:
            return "A complete job description could not be found on this page. Open the specific posting and paste its description."
        case .tooLarge:
            return "This page is too large to import safely. Copy and paste the relevant job description instead."
        case .timedOut:
            return "The job website did not respond within 15 seconds. Try again or paste the job description."
        case .unsupportedContent:
            return "This link does not contain a readable web page. Open the job posting and paste its description."
        case .httpStatus(let status):
            return "The job website returned HTTP \(status). Open the posting in your browser and paste its description."
        case .networkUnavailable:
            return "The job website could not be reached. Check your connection, try again, or paste the job description."
        }
    }
}

/// Foundation-only parsing. It never fetches linked resources or executes page scripts.
enum JobDescriptionExtractor {
    static let maximumPageBytes = 2 * 1_024 * 1_024
    static let maximumTextCharacters = 50_000

    static func validatedURL(from rawURL: String) throws -> URL {
        let raw = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.count <= 4_096,
              var parts = URLComponents(string: raw),
              let scheme = parts.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let originalHost = parts.host?.lowercased(),
              !originalHost.isEmpty else {
            throw JobDescriptionImportError.invalidURL
        }
        let host = originalHost.hasSuffix(".") ? String(originalHost.dropLast()) : originalHost
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let blockedSuffixes = [
            "localhost", "local", "localdomain", "internal", "intranet",
            "lan", "home", "test", "invalid", "example", "onion"
        ]
        guard parts.user == nil, parts.password == nil,
              parts.port == nil || (scheme == "https" && parts.port == 443)
                || (scheme == "http" && parts.port == 80),
              labels.count >= 2,
              labels.allSatisfy({ label in
                  !label.isEmpty && label.count <= 63
                    && !label.hasPrefix("-") && !label.hasSuffix("-")
                    && label.unicodeScalars.allSatisfy {
                        CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-").contains($0)
                    }
              }),
              let last = labels.last,
              last.count >= 2,
              last.contains(where: { $0.isLetter }),
              !blockedSuffixes.contains(where: { host == $0 || host.hasSuffix("." + $0) }),
              !host.contains(":"),
              !host.hasPrefix("0x"),
              !host.hasSuffix(".arpa")
        else { throw JobDescriptionImportError.unsafeURL }
        parts.scheme = scheme
        parts.host = host
        parts.fragment = nil
        guard let result = parts.url else { throw JobDescriptionImportError.invalidURL }
        return result
    }

    static func extract(html: String, sourceURL: URL) throws -> ImportedJobDescription {
        let safeURL = try validatedURL(from: sourceURL.absoluteString)
        guard html.utf8.count <= maximumPageBytes else { throw JobDescriptionImportError.tooLarge }
        // A JSON-LD JobPosting is more precise than the surrounding board/navigation.
        let scriptPattern = #"<script\b(?=[^>]*\btype\s*=\s*["']application/ld\+json["'])[^>]*>([\s\S]*?)</script\s*>"#
        for script in captures(scriptPattern, in: html, group: 1) {
            let source = script
                .replacingOccurrences(of: "<!--", with: "")
                .replacingOccurrences(of: "-->", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidates = [source, decodeEntities(source)]
            for candidate in candidates {
                guard let data = candidate.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) else { continue }
                for posting in jobPostings(in: object) {
                    guard let description = posting["description"] as? String else { continue }
                    let text = readableText(description)
                    guard hasEnoughContent(text, structured: true) else { continue }
                    guard text.count <= maximumTextCharacters else { throw JobDescriptionImportError.tooLarge }
                    let title = readableText(posting["title"] as? String ?? "")
                    let organization = posting["hiringOrganization"] as? [String: Any]
                    let company = readableText(organization?["name"] as? String ?? "")
                    return .init(url: safeURL, title: title, company: company, text: text)
                }
            }
        }

        let title = readableText(captures(#"<title\b[^>]*>([\s\S]*?)</title\s*>"#, in: html, group: 1).first ?? "")
        let visible = readableText(html)
        let lowerTitle = title.lowercased()
        let start = String(visible.prefix(3_000)).lowercased()
        let blockedTitles = ["access denied", "just a moment", "captcha", "sign in", "log in", "login", "page not found", "404 not found", "403 forbidden", "something went wrong"]
        let blockedMessages = ["verify you are human", "verify that you are human", "enable javascript and cookies", "checking your browser", "unusual traffic from your", "complete the security check", "you have been blocked", "please enable javascript to continue"]
        if blockedTitles.contains(where: { lowerTitle.contains($0) })
            || blockedMessages.contains(where: { start.contains($0) }) {
            throw JobDescriptionImportError.blockedPage
        }

        // Prefer a dedicated content region, then a main/article, before considering the page body.
        let dedicated = captures(#"<(?:div|section|article)\b[^>]*(?:id|class)\s*=\s*["'][^"']*(?:job-description|job_description|jobdescription|description__text)[^"']*["'][^>]*>([\s\S]*?)</(?:div|section|article)\s*>"#, in: html, group: 1)
        let main = captures(#"<(?:main|article)\b[^>]*>([\s\S]*?)</(?:main|article)\s*>"#, in: html, group: 1)
        let choices = (dedicated + main).map(readableText) + [visible]
        guard let text = choices.first(where: { hasEnoughContent($0, structured: false) }) else {
            throw JobDescriptionImportError.insufficientContent
        }
        guard text.count <= maximumTextCharacters else { throw JobDescriptionImportError.tooLarge }
        let heading = readableText(captures(#"<h1\b[^>]*>([\s\S]*?)</h1\s*>"#, in: html, group: 1).first ?? "")
        return .init(url: safeURL, title: heading.isEmpty ? title : heading, company: "", text: text)
    }

    static func readableText(_ html: String) -> String {
        var text = replace(#"<!--[\s\S]*?-->"#, in: html, with: "")
        text = replace(#"<(script|style|noscript|template|svg|nav|footer|header|aside|form)\b[^>]*>[\s\S]*?</\1\s*>"#, in: text, with: "")
        text = replace(#"<[^>]+\b(?:hidden|aria-hidden\s*=\s*["']true["'])[^>]*>[\s\S]*?</[^>]+>"#, in: text, with: "")
        text = replace(#"<li\b[^>]*>"#, in: text, with: "\n• ")
        text = replace(#"<br\s*/?>|</(?:p|div|li|h[1-6]|section|article|tr|ul|ol)\s*>"#, in: text, with: "\n")
        text = replace(#"<[^>]+>"#, in: text, with: " ")
        text = decodeEntities(text)
        let lines = text.components(separatedBy: .newlines).map {
            replace(#"[\t \u00A0]+"#, in: $0, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var cleaned: [String] = []
        for line in lines where !line.isEmpty {
            cleaned.append(line)
        }
        return cleaned.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ input: String) -> String {
        let entities: [String: String] = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
            "ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’",
            "ldquo": "“", "rdquo": "”", "hellip": "…", "bull": "•",
            "middot": "·", "copy": "©", "reg": "®", "trade": "™",
            "euro": "€", "pound": "£", "yen": "¥", "cent": "¢",
            "times": "×", "divide": "÷", "plusmn": "±", "laquo": "«", "raquo": "»",
            "aacute": "á", "eacute": "é", "iacute": "í", "oacute": "ó", "uacute": "ú",
            "Aacute": "Á", "Eacute": "É", "ntilde": "ñ", "Ntilde": "Ñ",
            "uuml": "ü", "ouml": "ö", "auml": "ä", "szlig": "ß"
        ]
        guard let regex = try? NSRegularExpression(pattern: #"&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[A-Za-z]+);"#) else { return input }
        var result = input
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        for match in matches.reversed() {
            guard let whole = Range(match.range, in: result),
                  let tokenRange = Range(match.range(at: 1), in: input) else { continue }
            let token = String(input[tokenRange])
            var replacement = entities[token]
            if token.hasPrefix("#") {
                let hex = token.lowercased().hasPrefix("#x")
                let digits = token.dropFirst(hex ? 2 : 1)
                if let number = UInt32(digits, radix: hex ? 16 : 10),
                   let scalar = UnicodeScalar(number), number >= 32 || number == 10 || number == 9 {
                    replacement = String(scalar)
                }
            }
            if let replacement { result.replaceSubrange(whole, with: replacement) }
        }
        return result
    }

    private static func hasEnoughContent(_ text: String, structured: Bool) -> Bool {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        guard text.count >= (structured ? 180 : 300), words.count >= (structured ? 25 : 45) else { return false }
        if structured { return true }
        let normalized = text.lowercased()
        let signals = ["responsibilities", "qualifications", "requirements", "experience", "skills", "benefits", "salary", "employment", "duties", "position", "this role", "apply"]
        return signals.filter { normalized.contains($0) }.count >= 2
    }

    private static func jobPostings(in object: Any, depth: Int = 0) -> [[String: Any]] {
        guard depth < 20 else { return [] }
        if let list = object as? [Any] {
            return list.flatMap { jobPostings(in: $0, depth: depth + 1) }
        }
        guard let dictionary = object as? [String: Any] else { return [] }
        let types = (dictionary["@type"] as? [String]) ?? [dictionary["@type"] as? String ?? ""]
        if types.contains(where: { $0 == "JobPosting" || $0.hasSuffix("/JobPosting") }) { return [dictionary] }
        return dictionary.values.flatMap { jobPostings(in: $0, depth: depth + 1) }
    }

    private static func captures(_ pattern: String, in source: String, group: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap {
            guard let range = Range($0.range(at: group), in: source) else { return nil }
            return String(source[range])
        }
    }

    private static func replace(_ pattern: String, in source: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return source }
        return regex.stringByReplacingMatches(in: source, range: NSRange(source.startIndex..., in: source), withTemplate: replacement)
    }
}

