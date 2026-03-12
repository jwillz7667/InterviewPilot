import Foundation

enum SessionMode: String, CaseIterable, Identifiable {
    case liveInterview
    case voicePrep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liveInterview:
            return "Live Interview"
        case .voicePrep:
            return "Voice Prep"
        }
    }

    var subtitle: String {
        switch self {
        case .liveInterview:
            return "Keep the current Deepgram + on-screen answer flow for a real interview."
        case .voicePrep:
            return "Run a full spoken mock interview with OpenAI Realtime voice."
        }
    }

    var icon: String {
        switch self {
        case .liveInterview:
            return "waveform.and.mic"
        case .voicePrep:
            return "person.wave.2.fill"
        }
    }

    var startButtonTitle: String {
        switch self {
        case .liveInterview:
            return "Start Interview Session"
        case .voicePrep:
            return "Start Voice Prep"
        }
    }
}
