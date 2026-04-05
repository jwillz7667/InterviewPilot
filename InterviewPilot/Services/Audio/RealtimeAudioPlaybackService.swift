import AVFoundation
import Observation

@Observable
final class RealtimeAudioPlaybackService {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private(set) var isPlaying = false

    private let sampleRate: Double = Double(APIConfig.realtimeSampleRate)
    private let playbackFormat: AVAudioFormat

    init() {
        playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(APIConfig.realtimeSampleRate),
            channels: 1,
            interleaved: false
        )!
    }

    func start() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)

        engine.prepare()
        try engine.start()
        player.play()

        self.audioEngine = engine
        self.playerNode = player
        self.isPlaying = true
    }

    func enqueueAudio(_ data: Data) {
        guard let playerNode, let buffer = pcmBufferFromData(data) else { return }
        playerNode.scheduleBuffer(buffer)
        if !isPlaying {
            isPlaying = true
        }
    }

    func flush() {
        playerNode?.stop()
        // Restart the player so it's ready to accept new buffers
        playerNode?.play()
    }

    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        isPlaying = false
    }

    // MARK: - PCM Conversion

    private func pcmBufferFromData(_ data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count / 2) // PCM16 = 2 bytes per sample
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            let int16Samples = rawBuffer.bindMemory(to: Int16.self)
            guard let floatChannel = buffer.floatChannelData?[0] else { return }
            for i in 0..<Int(frameCount) {
                floatChannel[i] = Float(int16Samples[i]) / 32768.0
            }
        }

        return buffer
    }
}
