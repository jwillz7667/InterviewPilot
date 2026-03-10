import AVFoundation

@Observable
final class AudioPlaybackService {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false

    func speak(_ text: String, rate: Float = 0.52) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}
