import AVFoundation

@MainActor
final class RealtimeAudioPlaybackService {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let outputFormat: AVAudioFormat

    private var pendingBufferCount = 0
    private var streamFinished = false

    private(set) var isPlaying = false

    var onPlaybackStarted: (() -> Void)?
    var onPlaybackFinished: (() -> Void)?

    init(sampleRate: Double = 24000) {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("Failed to create realtime playback format")
        }

        self.outputFormat = format
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
    }

    func start() throws {
        guard !audioEngine.isRunning else { return }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func enqueuePCM16(_ data: Data) {
        guard !data.isEmpty, let buffer = makeBuffer(from: data) else { return }

        do {
            try start()
        } catch {
            return
        }

        streamFinished = false
        pendingBufferCount += 1

        if !playerNode.isPlaying {
            playerNode.play()
        }

        if !isPlaying {
            isPlaying = true
            onPlaybackStarted?()
        }

        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { [weak self] in
                await self?.handleBufferPlaybackCompleted()
            }
        }
    }

    func markStreamFinished() {
        streamFinished = true
        finishPlaybackIfNeeded()
    }

    func stop() {
        playerNode.stop()
        pendingBufferCount = 0
        streamFinished = false

        let wasPlaying = isPlaying
        isPlaying = false

        if wasPlaying {
            onPlaybackFinished?()
        }
    }

    private func makeBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let frameCount = data.count / MemoryLayout<Int16>.size
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: AVAudioFrameCount(frameCount)
              ),
              let channelData = buffer.int16ChannelData else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            memcpy(channelData[0], baseAddress, data.count)
        }

        return buffer
    }

    private func handleBufferPlaybackCompleted() {
        pendingBufferCount = max(0, pendingBufferCount - 1)
        finishPlaybackIfNeeded()
    }

    private func finishPlaybackIfNeeded() {
        guard streamFinished, pendingBufferCount == 0 else { return }

        if playerNode.isPlaying {
            playerNode.stop()
        }

        guard isPlaying else { return }
        isPlaying = false
        onPlaybackFinished?()
    }
}
