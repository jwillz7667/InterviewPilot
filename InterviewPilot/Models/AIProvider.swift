import Foundation

/// Which backend chat-completion provider generates interview answers. The API
/// keys live server-side; this only selects which one the backend routes to.
/// Switching is gated to developer / full-access accounts and persists to the
/// user's settings (`chatProvider`), which the AI routes honor server-side.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openai
    case deepseek
    case groq

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        case .groq: return "Groq"
        }
    }

    var description: String {
        switch self {
        case .openai:
            return "GPT-4.1 family. Highest answer quality; needs OpenAI credit."
        case .deepseek:
            return "deepseek-chat. Very low cost with slightly higher latency."
        case .groq:
            return "Llama 3.3 70B on Groq. Fastest responses at the lowest cost."
        }
    }

    var iconName: String {
        switch self {
        case .openai: return "brain.head.profile"
        case .deepseek: return "magnifyingglass"
        case .groq: return "bolt.fill"
        }
    }
}
