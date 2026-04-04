import Foundation

struct SessionHistoryItem: Identifiable {
    enum Source {
        case local
        case remote
    }

    let id: String
    let serverId: String?
    let clientId: UUID?
    let source: Source
    let sessionMode: SessionMode?
    let startedAt: Date
    let endedAt: Date?
    let interviewType: String
    let responseFormat: String
    let modelUsed: String
    let totalTokensUsed: Int
    let estimatedCost: Double
    let exchangeCount: Int
    let exchanges: [Exchange]?
    let telemetrySummary: SessionTelemetrySummary?
    let jobDescription: String?
    let overallScore: Int?

    var duration: TimeInterval {
        let endDate = endedAt ?? Date()
        return max(endDate.timeIntervalSince(startedAt), 0)
    }

    var reviewInterviewType: InterviewType {
        InterviewType(rawValue: interviewType) ?? .general
    }

    var effectiveTelemetrySummary: SessionTelemetrySummary? {
        telemetrySummary ?? SessionTelemetrySummary.build(from: exchanges ?? [])
    }

    // MARK: - Job Description Parsing

    var positionTitle: String? {
        guard let jobDescription else { return nil }
        return Self.extractField("ROLE TITLE", from: jobDescription)
    }

    var companyName: String? {
        guard let jobDescription else { return nil }
        // First try the structured requirements section "Company: ..."
        if let company = Self.extractCompanyFromStructuredRequirements(jobDescription) {
            return company
        }
        // Fallback: try top-level "COMPANY:" field
        return Self.extractField("COMPANY", from: jobDescription)
    }

    var displayTitle: String {
        let position = positionTitle
        let company = companyName
        if let position, let company {
            return "\(position) @ \(company)"
        }
        if let position {
            return position
        }
        return reviewInterviewType.displayName
    }

    private static func extractField(_ fieldName: String, from text: String) -> String? {
        let pattern = "(?m)^\(NSRegularExpression.escapedPattern(for: fieldName)):\\s*(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = text[valueRange].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func extractCompanyFromStructuredRequirements(_ text: String) -> String? {
        // Look for "Company: ..." within the STRUCTURED JOB REQUIREMENTS section
        guard let sectionRange = text.range(of: "STRUCTURED JOB REQUIREMENTS", options: .caseInsensitive) else {
            return nil
        }
        let sectionText = String(text[sectionRange.upperBound...])
        return extractField("Company", from: sectionText)
    }
}
