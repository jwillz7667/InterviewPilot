import AVFoundation

@Observable
final class AudioCaptureService {
    private var audioEngine: AVAudioEngine?
    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0.0

    @ObservationIgnored var onAudioBuffer: (@Sendable (Data) -> Void)?
    @ObservationIgnored var onInterruption: ((Bool) -> Void)?  // true = interrupted, false = resumed
    @ObservationIgnored var onRouteChange: (() -> Void)?

    // Target format for downstream speech services.
    private let targetSampleRate: Double
    private let sessionMode: AVAudioSession.Mode
    private let categoryOptions: AVAudioSession.CategoryOptions
    private let bufferDurationSeconds: Double
    private var isInterrupted = false

    init(
        targetSampleRate: Double = 16000,
        sessionMode: AVAudioSession.Mode = .measurement,
        categoryOptions: AVAudioSession.CategoryOptions = [
            .allowBluetoothHFP,
            .defaultToSpeaker
        ],
        bufferDurationSeconds: Double = 0.1
    ) {
        self.targetSampleRate = targetSampleRate
        self.sessionMode = sessionMode
        self.categoryOptions = categoryOptions
        self.bufferDurationSeconds = bufferDurationSeconds
        registerNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private var bufferSize: AVAudioFrameCount {
        AVAudioFrameCount(targetSampleRate * bufferDurationSeconds)
    }

    // MARK: - Audio Session Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.isInterrupted = true
                self.onInterruption?(true)

            case .ended:
                self.isInterrupted = false
                let shouldResume: Bool
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        .contains(.shouldResume)
                } else {
                    shouldResume = true
                }

                if shouldResume && self.isCapturing {
                    self.restartEngine()
                }
                self.onInterruption?(false)

            @unknown default:
                break
            }
        }
    }

    @objc nonisolated private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        Task { @MainActor [weak self] in
            guard let self, self.isCapturing else { return }

            switch reason {
            case .oldDeviceUnavailable, .newDeviceAvailable, .override, .routeConfigurationChange:
                // Audio route changed — restart engine to bind to new input device
                self.restartEngine()
                self.onRouteChange?()
            default:
                break
            }
        }
    }

    @objc nonisolated private func handleMediaServicesReset() {
        Task { @MainActor [weak self] in
            guard let self, self.isCapturing else { return }
            // Media services were reset (rare but fatal) — full restart
            self.stopEngineOnly()
            self.restartEngine()
        }
    }

    /// Restart the audio engine without tearing down the full capture pipeline.
    private func restartEngine() {
        stopEngineOnly()

        do {
            try configureSession()
            try buildAndStartEngine()
        } catch {
            // If restart fails, notify via interruption callback
            onInterruption?(true)
        }
    }

    private func stopEngineOnly() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: sessionMode, options: categoryOptions)
        try session.setPreferredSampleRate(targetSampleRate)
        try session.setPreferredIOBufferDuration(bufferDurationSeconds)
        // .notifyOthersOnDeactivation ensures we reclaim audio after other apps
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func startCapture() throws {
        try configureSession()
        try buildAndStartEngine()
        isCapturing = true
        isInterrupted = false
        CrashReportingService.breadcrumb(category: "audio", message: "capture.started")
    }

    private func buildAndStartEngine() throws {
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
        let sampleRateRatio = outputFormat.sampleRate / inputFormat.sampleRate
        // Throttle waveform-level updates: the tap fires ~30x/sec, but the UI
        // only needs ~10Hz. Spawning a MainActor Task per buffer floods the
        // main actor and re-renders the waveform far more than necessary.
        var levelUpdateCounter = 0

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in

            levelUpdateCounter &+= 1
            if levelUpdateCounter % 3 == 0 {
                let level = AudioCaptureService.calculateRMS(buffer: buffer)
                Task { @MainActor in
                    self?.audioLevel = level
                }
            }

            // Convert to 16kHz PCM16 mono. Size the output buffer from the
            // actual input frame count and the sample-rate ratio (input is the
            // device's native rate, e.g. 48kHz → 16kHz is 3:1) so resampling
            // isn't truncated.
            let outputCapacity = AVAudioFrameCount(
                (Double(buffer.frameLength) * sampleRateRatio).rounded(.up)
            ) + 16
            guard outputCapacity > 0, let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: outputCapacity
            ) else { return }

            // Feed the captured buffer exactly ONCE, then report end-of-input.
            // AVAudioConverter pulls input repeatedly until its output buffer is
            // full; returning the same buffer with `.haveData` every time would
            // re-process the same samples and emit duplicated/garbled audio to
            // Deepgram. The one-shot flag + `.noDataNow` is the correct pull idiom.
            var didFeedInput = false
            var conversionError: NSError?
            let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                if didFeedInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                didFeedInput = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, conversionError == nil,
                  convertedBuffer.frameLength > 0,
                  let channelData = convertedBuffer.int16ChannelData else { return }

            let data = Data(
                bytes: channelData[0],
                count: Int(convertedBuffer.frameLength) * 2
            )
            onBuffer?(data)
        }

        engine.prepare()
        try engine.start()
    }

    func stopCapture() {
        stopEngineOnly()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isCapturing = false
        isInterrupted = false
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
