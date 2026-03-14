import Foundation

enum ResponseEmphasis: String, Codable, CaseIterable {
    case balanced, technicalDepth, businessImpact, leadership, productThinking

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .technicalDepth: return "Technical Depth"
        case .businessImpact: return "Business Impact"
        case .leadership: return "Ownership & Leadership"
        case .productThinking: return "Product Thinking"
        }
    }

    var description: String {
        switch self {
        case .balanced:
            return "Mix clarity, specifics, and just enough detail."
        case .technicalDepth:
            return "Lean into architecture, implementation, and tradeoffs."
        case .businessImpact:
            return "Stress outcomes, metrics, and user value."
        case .leadership:
            return "Show ownership, alignment, and execution."
        case .productThinking:
            return "Highlight prioritization, customer judgment, and strategy."
        }
    }

    var promptInstruction: String {
        switch self {
        case .balanced:
            return "Balance technical credibility, ownership, and concise delivery."
        case .technicalDepth:
            return "Bias toward concrete technical details, constraints, tradeoffs, and production considerations."
        case .businessImpact:
            return "Bias toward measurable outcomes, business value, and why the work mattered."
        case .leadership:
            return "Bias toward ownership, decision-making, cross-functional coordination, and raising the bar."
        case .productThinking:
            return "Bias toward customer problems, prioritization, scope tradeoffs, and product judgment."
        }
    }
}
