import AVFoundation

@Observable
final class AudioCaptureService {
    private var audioEngine: AVAudioEngine?
    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0.0

    @ObservationIgnored var onAudioBuffer: (@Sendable (Data) -> Void)?

    // Target format for Deepgram: 16kHz, 16-bit PCM, mono
    private let targetSampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1600  // 100ms at 16kHz

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [
            .allowBluetooth,
            .defaultToSpeaker,
            .mixWithOthers
        ])
        try session.setPreferredSampleRate(targetSampleRate)
        try session.setActive(true)
    }

    func startCapture() throws {
        try configureSession()

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else { return }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return }

        let onBuffer = self.onAudioBuffer

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in

            // Calculate audio level for waveform display
            let level = AudioCaptureService.calculateRMS(buffer: buffer)
            Task { @MainActor in
                self?.audioLevel = level
            }

            // Convert to 16kHz PCM16 mono
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat,
                frameCapacity: AVAudioFrameCount(16000 * 0.1)
            ) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if let channelData = convertedBuffer.int16ChannelData {
                let data = Data(
                    bytes: channelData[0],
                    count: Int(convertedBuffer.frameLength) * 2
                )
                onBuffer?(data)
            }
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    func stopCapture() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isCapturing = false
        audioLevel = 0.0
    }

    nonisolated private static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channelData[0][i]
            sum += sample * sample
        }
        return min(sqrt(sum / Float(frames)) * 3.0, 1.0)
    }
}
