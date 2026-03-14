import Foundation

enum ResponseTone: String, Codable, CaseIterable {
    case natural, confident, warm, executive

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .confident: return "Confident"
        case .warm: return "Warm"
        case .executive: return "Executive"
        }
    }

    var description: String {
        switch self {
        case .natural:
            return "Plainspoken, human, and easy to say out loud."
        case .confident:
            return "Senior-level, crisp, and decisive."
        case .warm:
            return "Calm, personable, and approachable."
        case .executive:
            return "High-signal, concise, and outcome-focused."
        }
    }

    var promptInstruction: String {
        switch self {
        case .natural:
            return "Use natural spoken language with contractions and no canned interview filler."
        case .confident:
            return "Sound decisive and credible without exaggerating or becoming stiff."
        case .warm:
            return "Keep the answer personable and grounded while staying technically sharp."
        case .executive:
            return "Prioritize signal over detail, stay concise, and emphasize judgment and outcomes."
        }
    }

    var temperature: Double {
        switch self {
        case .natural: return 0.62
        case .confident: return 0.56
        case .warm: return 0.66
        case .executive: return 0.52
        }
    }
}
