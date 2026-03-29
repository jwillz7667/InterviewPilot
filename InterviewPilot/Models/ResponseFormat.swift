import Foundation

enum ResponseFormat: String, Codable, CaseIterable {
    case fullAnswer, bulletPoints, hybrid, deepDive

    var displayName: String {
        switch self {
        case .fullAnswer:    return "Spoken Answer"
        case .bulletPoints:  return "Talking Points"
        case .hybrid:        return "Interview Ready"
        case .deepDive:      return "Deep Technical"
        }
    }

    var description: String {
        switch self {
        case .fullAnswer:    return "A clean answer you can say almost verbatim."
        case .bulletPoints:  return "Short prompts that keep you on track."
        case .hybrid:        return "Direct opener, structured middle, clean close."
        case .deepDive:      return "More technical depth for hard engineering questions."
        }
    }

    var promptInstruction: String {
        switch self {
        case .fullAnswer:
            return """
            Provide a natural spoken answer the candidate can say almost verbatim.
            Keep it to roughly 60-100 words.
            Use 3-6 short sentences max.
            Include at least one specific technical detail: a tool, library, pattern, metric, or tradeoff.
            """
        case .bulletPoints:
            return """
            Provide 3-4 short bullet points with the most useful talking points.
            Each bullet should be one concise sentence with a specific detail.
            Use \u{2022} as the bullet character.
            """
        case .hybrid:
            return """
            Provide a polished interview-ready answer with:
            - One direct opening sentence that answers the question
            - 2-3 short bullet points or middle sentences with specific implementation details
            - One short closing sentence connecting to impact or the target role
            Keep the total response under 100 words.
            """
        case .deepDive:
            return """
            Provide a concise but deeply technical spoken answer.
            Lead with the direct answer, then explain the architecture, key mechanism, tradeoff, and production considerations.
            Include specific technologies, patterns, or metrics where relevant.
            Keep it to roughly 90-140 words.
            """
        }
    }

    func maxWords(
        for emphasis: ResponseEmphasis,
        questionType: QuestionType?
    ) -> Int {
        let technicalBonus: Int
        switch questionType {
        case .technical, .systemDesign, .coding:
            technicalBonus = 20
        default:
            technicalBonus = 0
        }

        let emphasisBonus = emphasis == .technicalDepth ? 14 : 0

        switch self {
        case .fullAnswer:
            return 90 + technicalBonus + emphasisBonus
        case .bulletPoints:
            return 60 + min(technicalBonus, 10)
        case .hybrid:
            return 100 + technicalBonus + emphasisBonus
        case .deepDive:
            return 135 + technicalBonus + emphasisBonus
        }
    }

    func maxSentences(
        for emphasis: ResponseEmphasis,
        questionType: QuestionType?
    ) -> Int {
        switch self {
        case .bulletPoints:
            return 4
        case .fullAnswer:
            return emphasis == .technicalDepth || isTechnical(questionType) ? 6 : 5
        case .hybrid:
            return emphasis == .technicalDepth || isTechnical(questionType) ? 7 : 5
        case .deepDive:
            return 7
        }
    }

    func maxBullets(for emphasis: ResponseEmphasis) -> Int {
        switch self {
        case .bulletPoints:
            return emphasis == .technicalDepth ? 5 : 4
        case .hybrid:
            return 3
        case .fullAnswer, .deepDive:
            return 4
        }
    }

    func maxBulletWords(for emphasis: ResponseEmphasis) -> Int {
        switch self {
        case .bulletPoints:
            return emphasis == .technicalDepth ? 20 : 18
        case .hybrid:
            return 18
        case .fullAnswer, .deepDive:
            return 22
        }
    }

    func maxTokens(for emphasis: ResponseEmphasis, questionType: QuestionType?) -> Int {
        let baseline: Int
        switch self {
        case .bulletPoints:
            baseline = 200
        case .fullAnswer:
            baseline = 260
        case .hybrid:
            baseline = 280
        case .deepDive:
            baseline = 380
        }

        let technicalBonus = isTechnical(questionType) ? 50 : 0
        let emphasisBonus = emphasis == .technicalDepth ? 30 : 0
        return baseline + technicalBonus + emphasisBonus
    }

    private func isTechnical(_ questionType: QuestionType?) -> Bool {
        switch questionType {
        case .technical, .systemDesign, .coding:
            return true
        default:
            return false
        }
    }
}
