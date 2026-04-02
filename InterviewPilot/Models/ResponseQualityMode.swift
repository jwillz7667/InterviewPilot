import Foundation

enum ResponseQualityMode: String, Codable, CaseIterable, Identifiable {
    case free
    case standard
    case premium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Standard"
        case .standard: return "Enhanced"
        case .premium: return "Premium"
        }
    }

    var description: String {
        switch self {
        case .free:
            return "Helpful interview guidance with standard AI."
        case .standard:
            return "Deep, role-specific interview answers with enhanced AI models."
        case .premium:
            return "Top-tier interview answers with premium AI models and coding support."
        }
    }

    var promptInstruction: String {
        switch self {
        case .free:
            return """
            Deliver a helpful interview answer:
            - Start with a clear, direct answer
            - Keep it concise and practical
            - Include one concrete example if possible
            - Sound natural and conversational
            """
        case .standard:
            return """
            Deliver a top-tier interview answer:
            - Start with a clear headline answer immediately
            - Spend most of the answer on the candidate's actions, decisions, and judgment
            - Quantify impact when the resume supports it
            - Make the tradeoff or rationale explicit
            - End on why it mattered, what was learned, or how it maps to the target role when useful
            - Sound like a real engineer talking, never rehearsed or inflated
            """
        case .premium:
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
        case .free:
            return """
            Generate clear, practical interview answers:
            focus on direct answers with one example each.
            Keep answers concise and naturally conversational.
            """
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
        case .free: return 0
        case .standard: return 40
        case .premium: return 80
        }
    }

    var liveResponseTokenCap: Int {
        switch self {
        case .free: return APIConfig.freeResponseTokens
        case .standard: return APIConfig.maxResponseTokens
        case .premium: return APIConfig.maxPremiumResponseTokens
        }
    }

    func liveTokenLimit(baseTokens: Int) -> Int {
        min(baseTokens + additionalTokenBudget, liveResponseTokenCap)
    }

    var requiresPriorityModels: Bool {
        self == .premium
    }
}
