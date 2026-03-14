import Foundation

enum ResponseQualityMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case premium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .premium:
            return "Top Tier"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Fast, strong interview answers tuned to the selected format and style."
        case .premium:
            return "Sharper headline, stronger evidence, clearer tradeoffs, and higher-signal impact framing."
        }
    }

    var promptInstruction: String {
        switch self {
        case .standard:
            return """
            Keep the answer crisp, natural, and directly useful in a live interview.
            """
        case .premium:
            return """
            Deliver a top-tier interview answer:
            - Start with a clear headline answer immediately
            - Spend most of the answer on the candidate's actions, decisions, and judgment
            - Quantify impact when the resume or prompt supports it
            - Make the tradeoff or rationale explicit
            - End on why it mattered, what was learned, or how it maps to the target role when useful
            - Sound prepared but never rehearsed or inflated
            """
        }
    }

    var preGenerationInstruction: String {
        switch self {
        case .standard:
            return "Generate strong candidate-ready answers that are concise, direct, and natural out loud."
        case .premium:
            return """
            Generate top-tier answers that would impress a strong interviewer:
            prioritize structured impact, clear ownership, quantified outcomes when supported,
            explicit tradeoffs, and concise reflection without sounding canned.
            """
        }
    }

    var additionalTokenBudget: Int {
        switch self {
        case .standard:
            return 0
        case .premium:
            return 24
        }
    }

    var liveResponseTokenCap: Int {
        switch self {
        case .standard:
            return APIConfig.maxResponseTokens
        case .premium:
            return APIConfig.maxPremiumResponseTokens
        }
    }

    func liveTokenLimit(baseTokens: Int) -> Int {
        min(baseTokens + additionalTokenBudget, liveResponseTokenCap)
    }

    var requiresPriorityModels: Bool {
        self == .premium
    }
}
