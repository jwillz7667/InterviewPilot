import Foundation

struct LinkedInProfileData: Sendable {
    let url: String
    let name: String?
    let headline: String?
    let about: String?
    let experience: [ExperienceEntry]
    let education: [EducationEntry]
    let skills: [String]
    let profileText: String

    struct ExperienceEntry: Sendable {
        let title: String
        let company: String
        let duration: String
        let description: String
    }

    struct EducationEntry: Sendable {
        let school: String
        let degree: String
        let dates: String
    }

    var formattedContext: String {
        var sections: [String] = []

        sections.append("LinkedIn: \(url)")
        if let name, !name.isEmpty {
            sections.append("Name: \(name)")
        }
        if let headline, !headline.isEmpty {
            sections.append("Headline: \(headline)")
        }
        if let about, !about.isEmpty {
            sections.append("\nAbout:\n\(about)")
        }

        if !experience.isEmpty {
            sections.append("\nExperience:")
            for entry in experience {
                var line = "- \(entry.title) at \(entry.company)"
                if !entry.duration.isEmpty {
                    line += " (\(entry.duration))"
                }
                sections.append(line)
                if !entry.description.isEmpty {
                    sections.append("  \(entry.description)")
                }
            }
        }

        if !education.isEmpty {
            sections.append("\nEducation:")
            for entry in education {
                var line = "- \(entry.school)"
                if !entry.degree.isEmpty {
                    line += " — \(entry.degree)"
                }
                if !entry.dates.isEmpty {
                    line += " (\(entry.dates))"
                }
                sections.append(line)
            }
        }

        if !skills.isEmpty {
            sections.append("\nSkills: \(skills.joined(separator: ", "))")
        }

        // If structured extraction didn't capture much, include raw text
        let structuredContentLength = experience.count + education.count + skills.count
        if structuredContentLength < 3 && !profileText.isEmpty {
            sections.append("\nFull Profile Content:\n\(profileText)")
        }

        return sections.joined(separator: "\n")
    }

    var isEmpty: Bool {
        name == nil && headline == nil && about == nil &&
        experience.isEmpty && education.isEmpty && skills.isEmpty &&
        profileText.isEmpty
    }
}

enum LinkedInServiceError: LocalizedError {
    case invalidURL
    case emptyProfile
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid LinkedIn profile URL (e.g., linkedin.com/in/username)."
        case .emptyProfile:
            return "Could not extract profile data. Paste your profile content below."
        case .fetchFailed(let detail):
            return "LinkedIn fetch failed: \(detail). Paste your profile content instead."
        }
    }
}

enum LinkedInService {

    // MARK: - URL Validation

    static func normalizeURL(_ input: String) -> String? {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle common formats
        if cleaned.hasPrefix("linkedin.com") {
            cleaned = "https://www." + cleaned
        } else if cleaned.hasPrefix("www.linkedin.com") {
            cleaned = "https://" + cleaned
        } else if cleaned.hasPrefix("http://") {
            cleaned = cleaned.replacingOccurrences(of: "http://", with: "https://")
        }

        // Ensure it's a valid LinkedIn profile URL
        guard cleaned.contains("linkedin.com/in/"),
              URL(string: cleaned) != nil else {
            return nil
        }

        // Strip query params and trailing slash
        if let range = cleaned.range(of: "?") {
            cleaned = String(cleaned[cleaned.startIndex..<range.lowerBound])
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return cleaned
    }

    // MARK: - Lightweight Public Fetch

    /// Attempts to extract basic info from LinkedIn's public profile page (JSON-LD + meta tags).
    /// This is best-effort — LinkedIn may block the request. Falls back gracefully.
    static func fetchBasicProfile(url: String) async -> (name: String?, headline: String?) {
        guard let requestURL = URL(string: url) else { return (nil, nil) }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10
        // Use a generic browser user-agent to get server-rendered SEO content
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<400).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return (nil, nil)
            }

            let name = extractMetaContent(from: html, property: "og:title")
                ?? extractJSONLDField(from: html, field: "name")
            let headline = extractMetaContent(from: html, property: "og:description")
                ?? extractJSONLDField(from: html, field: "jobTitle")

            return (name, headline)
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - Profile Text Parsing

    /// Parses user-pasted LinkedIn profile text into structured data.
    static func parseProfileText(_ text: String, url: String) -> LinkedInProfileData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var name: String?
        var headline: String?
        var about: String?
        var experience: [LinkedInProfileData.ExperienceEntry] = []
        var education: [LinkedInProfileData.EducationEntry] = []
        var skills: [String] = []

        // State machine for section parsing
        enum Section { case none, about, experience, education, skills, other }
        var currentSection: Section = .none
        var aboutLines: [String] = []
        var currentExpTitle: String?
        var currentExpCompany: String?
        var currentExpDuration: String?
        var currentExpDesc: [String] = []

        // Extract name from first non-empty line
        for line in lines {
            if !line.isEmpty {
                name = line
                break
            }
        }

        // Extract headline from second non-empty line (if not a section header)
        var nonEmptyCount = 0
        for line in lines {
            if !line.isEmpty {
                nonEmptyCount += 1
                if nonEmptyCount == 2 && !isSectionHeader(line) {
                    headline = line
                    break
                }
            }
        }

        for line in lines {
            let lowered = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Detect section headers
            if lowered == "about" || lowered == "about me" || lowered == "summary" {
                flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                                duration: &currentExpDuration, desc: &currentExpDesc)
                currentSection = .about
                continue
            }
            if lowered == "experience" || lowered == "work experience" {
                if currentSection == .about {
                    about = aboutLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    aboutLines = []
                }
                flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                                duration: &currentExpDuration, desc: &currentExpDesc)
                currentSection = .experience
                continue
            }
            if lowered == "education" {
                if currentSection == .about {
                    about = aboutLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    aboutLines = []
                }
                flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                                duration: &currentExpDuration, desc: &currentExpDesc)
                currentSection = .education
                continue
            }
            if lowered == "skills" || lowered == "top skills" || lowered.hasPrefix("skills & endorsements") {
                if currentSection == .about {
                    about = aboutLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    aboutLines = []
                }
                flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                                duration: &currentExpDuration, desc: &currentExpDesc)
                currentSection = .skills
                continue
            }
            if lowered == "certifications" || lowered == "licenses & certifications" ||
               lowered == "honors & awards" || lowered == "publications" ||
               lowered == "volunteer experience" || lowered == "languages" ||
               lowered == "recommendations" || lowered == "interests" ||
               lowered == "projects" || lowered == "courses" {
                if currentSection == .about {
                    about = aboutLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    aboutLines = []
                }
                flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                                duration: &currentExpDuration, desc: &currentExpDesc)
                currentSection = .other
                continue
            }

            guard !line.isEmpty else { continue }

            switch currentSection {
            case .about:
                aboutLines.append(line)

            case .experience:
                // Heuristic: lines with " · " or " at " or "•" separating company/title
                if line.contains(" · ") {
                    flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                                    duration: &currentExpDuration, desc: &currentExpDesc)
                    let parts = line.components(separatedBy: " · ")
                    currentExpCompany = parts.first?.trimmingCharacters(in: .whitespaces)
                    if parts.count > 1 {
                        currentExpDuration = parts.last?.trimmingCharacters(in: .whitespaces)
                    }
                } else if looksLikeDateRange(line) {
                    currentExpDuration = line
                } else if currentExpTitle == nil && currentExpCompany != nil {
                    currentExpTitle = line
                } else if currentExpCompany == nil {
                    // Could be title or company — treat first as company, second as title
                    if currentExpTitle == nil {
                        currentExpCompany = line
                    } else {
                        currentExpDesc.append(line)
                    }
                } else {
                    currentExpDesc.append(line)
                }

            case .education:
                if line.contains(" · ") || looksLikeDateRange(line) {
                    // Date line for education
                    if let last = education.indices.last {
                        education[last] = LinkedInProfileData.EducationEntry(
                            school: education[last].school,
                            degree: education[last].degree,
                            dates: line
                        )
                    }
                } else if education.isEmpty || (!education.last!.degree.isEmpty && !looksLikeDateRange(line)) {
                    education.append(LinkedInProfileData.EducationEntry(
                        school: line, degree: "", dates: ""
                    ))
                } else if let last = education.indices.last, education[last].degree.isEmpty {
                    education[last] = LinkedInProfileData.EducationEntry(
                        school: education[last].school,
                        degree: line,
                        dates: education[last].dates
                    )
                }

            case .skills:
                // Skills can be comma-separated, bullet-separated, or one per line
                let separators = CharacterSet(charactersIn: ",·•|")
                let parsed = line.components(separatedBy: separators)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                skills.append(contentsOf: parsed)

            case .none, .other:
                break
            }
        }

        // Flush remaining
        if currentSection == .about {
            about = aboutLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }
        flushExperience(&experience, title: &currentExpTitle, company: &currentExpCompany,
                        duration: &currentExpDuration, desc: &currentExpDesc)

        return LinkedInProfileData(
            url: url,
            name: name,
            headline: headline,
            about: about,
            experience: experience,
            education: education,
            skills: skills,
            profileText: text
        )
    }

    // MARK: - Private Helpers

    private static func flushExperience(
        _ entries: inout [LinkedInProfileData.ExperienceEntry],
        title: inout String?,
        company: inout String?,
        duration: inout String?,
        desc: inout [String]
    ) {
        if let t = title ?? company {
            entries.append(LinkedInProfileData.ExperienceEntry(
                title: title ?? "",
                company: company ?? t,
                duration: duration ?? "",
                description: desc.joined(separator: " ")
            ))
        }
        title = nil
        company = nil
        duration = nil
        desc = []
    }

    private static func isSectionHeader(_ line: String) -> Bool {
        let lowered = line.lowercased().trimmingCharacters(in: .whitespaces)
        let headers = ["about", "about me", "summary", "experience", "work experience",
                       "education", "skills", "top skills", "certifications",
                       "honors & awards", "publications", "volunteer experience",
                       "languages", "recommendations", "interests", "projects", "courses",
                       "licenses & certifications", "skills & endorsements"]
        return headers.contains(lowered)
    }

    private static func looksLikeDateRange(_ line: String) -> Bool {
        let lowered = line.lowercased()
        let dateKeywords = ["jan", "feb", "mar", "apr", "may", "jun",
                            "jul", "aug", "sep", "oct", "nov", "dec",
                            "present", "current", "20", "19"]
        let matchCount = dateKeywords.filter { lowered.contains($0) }.count
        return matchCount >= 2 || (lowered.contains("–") && matchCount >= 1) ||
               (lowered.contains("-") && matchCount >= 1) ||
               lowered.contains("yr") || lowered.contains("mos")
    }

    private static func extractMetaContent(from html: String, property: String) -> String? {
        // Match: <meta property="og:title" content="..." />
        let pattern = "property=\"\(property)\"\\s+content=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            // Try alternate format: content before property
            let altPattern = "content=\"([^\"]*)\"\\s+property=\"\(property)\""
            guard let altRegex = try? NSRegularExpression(pattern: altPattern),
                  let altMatch = altRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let altRange = Range(altMatch.range(at: 1), in: html) else {
                return nil
            }
            let value = String(html[altRange])
            return value.isEmpty ? nil : value
        }
        let value = String(html[range])
        return value.isEmpty ? nil : value
    }

    private static func extractJSONLDField(from html: String, field: String) -> String? {
        // Find the JSON-LD block
        guard let scriptStart = html.range(of: "application/ld+json"),
              let braceStart = html[scriptStart.upperBound...].range(of: "{"),
              let braceEnd = html[braceStart.lowerBound...].range(of: "</script>") else {
            return nil
        }

        let jsonString = String(html[braceStart.lowerBound..<braceEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json[field] as? String else {
            return nil
        }

        return value.isEmpty ? nil : value
    }
}
