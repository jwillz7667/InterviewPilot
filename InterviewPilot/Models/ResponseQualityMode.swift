import Foundation

enum ResponseQualityMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case premium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard, .premium:
            return "Standard"
        }
    }

    var description: String {
        switch self {
        case .standard, .premium:
            return "Technically deep, human-sounding interview answers calibrated to the specific role."
        }
    }

    var promptInstruction: String {
        switch self {
        case .standard, .premium:
            return """
            Deliver a top-tier interview answer:
            - Start with a clear headline answer immediately
            - Spend most of the answer on the candidate's actions, decisions, and judgment
            - Quantify impact when the resume supports it
            - Make the tradeoff or rationale explicit
            - End on why it mattered, what was learned, or how it maps to the target role when useful
            - Sound like a real engineer talking, never rehearsed or inflated
            """
        }
    }

    var preGenerationInstruction: String {
        switch self {
        case .standard, .premium:
            return """
            Generate top-tier answers that would impress a strong interviewer:
            prioritize structured impact, clear ownership, quantified outcomes when supported,
            explicit tradeoffs, and concise reflection without sounding canned.
            Make every answer sound like a real engineer talking, not a template.
            """
        }
    }

    var additionalTokenBudget: Int {
        switch self {
        case .standard, .premium:
            return 40
        }
    }

    var liveResponseTokenCap: Int {
        switch self {
        case .standard, .premium:
            return APIConfig.maxResponseTokens
        }
    }

    func liveTokenLimit(baseTokens: Int) -> Int {
        min(baseTokens + additionalTokenBudget, liveResponseTokenCap)
    }

    var requiresPriorityModels: Bool {
        false
    }
}
