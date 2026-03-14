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
            Keep it to roughly 45-70 words.
            Use 3-5 short sentences max.
            """
        case .bulletPoints:
            return """
            Provide 3 short bullet points with the most useful talking points.
            Each bullet should be one concise sentence.
            Use \u{2022} as the bullet character.
            """
        case .hybrid:
            return """
            Provide a polished interview-ready answer with:
            - One direct opening sentence
            - 2 short bullet points or 2 short middle sentences
            - One short closing sentence
            Keep the total response under 70 words.
            """
        case .deepDive:
            return """
            Provide a concise but more technical spoken answer.
            Lead with the direct answer, then explain the key mechanism, tradeoff, and one production consideration.
            Keep it to roughly 70-110 words.
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
            technicalBonus = 12
        default:
            technicalBonus = 0
        }

        let emphasisBonus = emphasis == .technicalDepth ? 8 : 0

        switch self {
        case .fullAnswer:
            return 62 + technicalBonus + emphasisBonus
        case .bulletPoints:
            return 42 + min(technicalBonus, 6)
        case .hybrid:
            return 72 + technicalBonus + emphasisBonus
        case .deepDive:
            return 96 + technicalBonus + emphasisBonus
        }
    }

    func maxSentences(
        for emphasis: ResponseEmphasis,
        questionType: QuestionType?
    ) -> Int {
        switch self {
        case .bulletPoints:
            return 3
        case .fullAnswer:
            return emphasis == .technicalDepth || isTechnical(questionType) ? 4 : 3
        case .hybrid:
            return emphasis == .technicalDepth || isTechnical(questionType) ? 5 : 4
        case .deepDive:
            return 5
        }
    }

    func maxBullets(for emphasis: ResponseEmphasis) -> Int {
        switch self {
        case .bulletPoints:
            return emphasis == .technicalDepth ? 4 : 3
        case .hybrid:
            return 2
        case .fullAnswer, .deepDive:
            return 3
        }
    }

    func maxBulletWords(for emphasis: ResponseEmphasis) -> Int {
        switch self {
        case .bulletPoints:
            return emphasis == .technicalDepth ? 16 : 14
        case .hybrid:
            return 14
        case .fullAnswer, .deepDive:
            return 18
        }
    }

    func maxTokens(for emphasis: ResponseEmphasis, questionType: QuestionType?) -> Int {
        let baseline: Int
        switch self {
        case .bulletPoints:
            baseline = 140
        case .fullAnswer:
            baseline = 180
        case .hybrid:
            baseline = 200
        case .deepDive:
            baseline = 260
        }

        let technicalBonus = isTechnical(questionType) ? 30 : 0
        let emphasisBonus = emphasis == .technicalDepth ? 20 : 0
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
