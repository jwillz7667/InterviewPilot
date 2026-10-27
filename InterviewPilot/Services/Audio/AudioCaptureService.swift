import AVFoundation
import Observation
import Synchronization

enum AudioCaptureError: LocalizedError {
    case microphonePermissionDenied
    case engineSetupFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Enable microphone access in Settings to start listening."
        case .engineSetupFailed(let detail):
            return "Audio capture stopped: \(detail)"
        }
    }
}

/// Owns the microphone. Interruption and route changes require explicit resume;
/// the app must never silently switch to a different microphone while listening.
@MainActor @Observable
final class AudioCaptureService {
    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0

    /// Runs on the audio processing queue. The consumer must enqueue without blocking.
    @ObservationIgnored var onAudioBuffer: (@Sendable (Data) -> Void)?
    @ObservationIgnored var onInterruption: ((Bool) -> Void)?
    @ObservationIgnored var onRouteChange: (() -> Void)?
    @ObservationIgnored var onError: ((Error) -> Void)?

    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var processor: AudioBufferProcessor?
    @ObservationIgnored private var levelTask: Task<Void, Never>?
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []
    private var tapInstalled = false
    private var captureGeneration = UUID()
    private let targetSampleRate: Double
    private let sessionMode: AVAudioSession.Mode
    private let categoryOptions: AVAudioSession.CategoryOptions
    private let bufferDurationSeconds: Double

    init(
        targetSampleRate: Double = 16_000,
        sessionMode: AVAudioSession.Mode = .measurement,
        categoryOptions: AVAudioSession.CategoryOptions = [.allowBluetoothHFP, .defaultToSpeaker],
        bufferDurationSeconds: Double = 0.02
    ) {
        self.targetSampleRate = targetSampleRate
        self.sessionMode = sessionMode
        self.categoryOptions = categoryOptions
        self.bufferDurationSeconds = min(max(bufferDurationSeconds, 0.02), 0.05)
        registerNotifications()
    }

    deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        levelTask?.cancel()
        processor?.stop()
        audioEngine?.stop()
    }

    func ensureMicrophonePermission() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return
        case .undetermined:
            guard await AVAudioApplication.requestRecordPermission() else {
                throw AudioCaptureError.microphonePermissionDenied
            }
        case .denied:
            throw AudioCaptureError.microphonePermissionDenied
        @unknown default:
            throw AudioCaptureError.microphonePermissionDenied
        }
    }

    func configureSession() throws {
        guard targetSampleRate.isFinite, targetSampleRate > 0 else {
            throw AudioCaptureError.engineSetupFailed("invalid sample rate")
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: sessionMode, options: categoryOptions)
        try session.setPreferredSampleRate(targetSampleRate)
        try session.setPreferredIOBufferDuration(bufferDurationSeconds)
        try session.setActive(true)
    }

    func startCapture() throws {
        guard !isCapturing else { return }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw AudioCaptureError.microphonePermissionDenied
        }
        captureGeneration = UUID()
        let generation = captureGeneration
        do {
            try configureSession()
            let engine = AVAudioEngine()
            audioEngine = engine
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.sampleRate.isFinite, inputFormat.sampleRate > 0,
                  inputFormat.channelCount > 0 else {
                throw AudioCaptureError.engineSetupFailed("no microphone input is available")
            }

            let processor = try AudioBufferProcessor(
                inputFormat: inputFormat,
                sampleRate: targetSampleRate,
                onAudio: onAudioBuffer ?? { _ in },
                onFailure: { [weak self] detail in
                    Task { @MainActor [weak self] in
                        guard let self, self.captureGeneration == generation, self.isCapturing else { return }
                        self.stopCapture()
                        self.onError?(AudioCaptureError.engineSetupFailed(detail))
                    }
                }
            )
            self.processor = processor
            // Tap frame counts use the device's actual sample rate, not 16 kHz.
            let nativeFrames = AVAudioFrameCount(inputFormat.sampleRate * bufferDurationSeconds)
            input.installTap(onBus: 0, bufferSize: max(256, nativeFrames), format: inputFormat) {
                buffer, _ in processor.enqueue(buffer)
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            isCapturing = true
            // One long-lived task, at 10 Hz; never create UI tasks from the render callback.
            levelTask = Task { @MainActor [weak self, weak processor] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) }
                    catch { break }
                    guard let self, let processor, self.captureGeneration == generation else { break }
                    self.audioLevel = processor.currentLevel
                }
            }
        } catch {
            stopCapture()
            throw error
        }
    }

    func stopCapture() {
        // Invalidate pending processing/error callbacks before releasing the microphone.
        captureGeneration = UUID()
        isCapturing = false
        levelTask?.cancel()
        levelTask = nil
        processor?.stop()
        processor = nil
        if tapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine?.stop()
        audioEngine = nil
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func registerNotifications() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                if type == .began {
                    guard self.isCapturing else { return }
                    self.stopCapture()
                    self.onInterruption?(true)
                } else if type == .ended {
                    // Readiness notification only. The owner decides when to resume.
                    self.onInterruption?(false)
                }
            }
        })
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            guard [.oldDeviceUnavailable, .newDeviceAvailable, .override,
                   .routeConfigurationChange, .noSuitableRouteForCategory].contains(reason) else { return }
            MainActor.assumeIsolated {
                guard let self, self.isCapturing else { return }
                self.stopCapture()
                self.onRouteChange?()
            }
        })
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isCapturing else { return }
                self.stopCapture()
                self.onError?(AudioCaptureError.engineSetupFailed("audio services restarted; tap Resume to reconnect"))
            }
        })
    }
}

/// The render callback is the sole producer and the processing queue the sole
/// consumer. Acquire/release indices transfer ownership of preallocated slots;
/// no lock, conversion, network operation or Data allocation runs in the tap.
nonisolated private final class AudioBufferProcessor: @unchecked Sendable {
    private final class Slot {
        let buffer: AVAudioPCMBuffer
        var queuedAt = ContinuousClock.now
        init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    }

    private let queue = DispatchQueue(label: "InterviewPilot.audio.processing", qos: .userInteractive)
    private let converter: AVAudioConverter
    private let output: AVAudioPCMBuffer
    private let slots: [Slot]
    private let signal: DispatchSourceUserDataAdd
    private let overflowSignal: DispatchSourceUserDataAdd
    private let onAudio: @Sendable (Data) -> Void
    private let onFailure: @Sendable (String) -> Void
    private let chunkBytes: Int
    private let writeIndex = Atomic<UInt64>(0)
    private let readIndex = Atomic<UInt64>(0)
    private let active = Atomic<Bool>(true)
    private let level = Atomic<Float>(0)
    // Only the consumer queue touches this storage.
    private var pendingPCM = Data()

    init(
        inputFormat: AVAudioFormat,
        sampleRate: Double,
        onAudio: @escaping @Sendable (Data) -> Void,
        onFailure: @escaping @Sendable (String) -> Void
    ) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate,
                                         channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: inputFormat, to: format) else {
            throw AudioCaptureError.engineSetupFailed("the microphone format cannot be converted to PCM16")
        }
        let capacity: AVAudioFrameCount = 8_192
        let outputCapacity = AVAudioFrameCount(ceil(Double(capacity) * sampleRate / inputFormat.sampleRate)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity) else {
            throw AudioCaptureError.engineSetupFailed("could not allocate audio conversion storage")
        }
        var slots: [Slot] = []
        for _ in 0..<8 {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: capacity) else {
                throw AudioCaptureError.engineSetupFailed("could not allocate microphone buffers")
            }
            slots.append(Slot(buffer))
        }
        self.converter = converter
        self.output = output
        self.slots = slots
        self.chunkBytes = Int(sampleRate * 0.02) * MemoryLayout<Int16>.size
        self.onAudio = onAudio
        self.onFailure = onFailure
        signal = DispatchSource.makeUserDataAddSource(queue: queue)
        overflowSignal = DispatchSource.makeUserDataAddSource(queue: queue)
        pendingPCM.reserveCapacity(Int(outputCapacity) * 2)
        signal.setEventHandler { [weak self] in self?.drain() }
        overflowSignal.setEventHandler { [weak self] in
            self?.fail("audio processing could not keep up; tap Resume to restart")
        }
        signal.activate()
        overflowSignal.activate()
    }

    var currentLevel: Float { level.load(ordering: .relaxed) }

    func enqueue(_ input: AVAudioPCMBuffer) {
        guard active.load(ordering: .acquiring), input.frameLength > 0 else { return }
        let write = writeIndex.load(ordering: .relaxed)
        let read = readIndex.load(ordering: .acquiring)
        guard write &- read < UInt64(slots.count) else {
            overflowSignal.add(data: 1)
            return
        }
        let slot = slots[Int(write % UInt64(slots.count))]
        let destination = slot.buffer
        guard input.frameLength <= destination.frameCapacity else {
            overflowSignal.add(data: 1)
            return
        }
        destination.frameLength = input.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(input.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else {
            overflowSignal.add(data: 1)
            return
        }
        for channel in sourceBuffers.indices {
            guard let source = sourceBuffers[channel].mData,
                  let target = destinationBuffers[channel].mData,
                  sourceBuffers[channel].mDataByteSize <= destinationBuffers[channel].mDataByteSize else {
                overflowSignal.add(data: 1)
                return
            }
            memcpy(target, source, Int(sourceBuffers[channel].mDataByteSize))
        }
        slot.queuedAt = .now
        writeIndex.store(write &+ 1, ordering: .releasing)
        signal.add(data: 1)
    }

    func stop() {
        active.store(false, ordering: .releasing)
        level.store(0, ordering: .relaxed)
        signal.cancel()
        overflowSignal.cancel()
    }

    private func fail(_ detail: String) {
        if active.exchange(false, ordering: .acquiringAndReleasing) {
            onFailure(detail)
        }
    }

    private func drain() {
        while active.load(ordering: .acquiring) {
            let read = readIndex.load(ordering: .relaxed)
            guard read != writeIndex.load(ordering: .acquiring) else { return }
            let index = Int(read % UInt64(slots.count))
            guard slots[index].queuedAt.duration(to: .now) < .milliseconds(250) else {
                fail("microphone audio became delayed; tap Resume to restart")
                return
            }
            var fed = false
            var error: NSError?
            output.frameLength = 0
            // Conversion is synchronous on this queue. The producer cannot reuse
            // this slot until readIndex advances after convert returns.
            let status = converter.convert(to: output, error: &error) { _, outStatus in
                guard !fed else { outStatus.pointee = .noDataNow; return nil }
                fed = true
                outStatus.pointee = .haveData
                return self.slots[index].buffer
            }
            readIndex.store(read &+ 1, ordering: .releasing)
            guard active.load(ordering: .acquiring) else { return }
            guard status != .error, error == nil else {
                fail("microphone audio conversion failed; tap Resume to restart")
                return
            }
            guard output.frameLength > 0, let samples = output.int16ChannelData?[0] else { continue }
            let count = Int(output.frameLength)
            var squared: Float = 0
            for index in 0..<count {
                let sample = Float(samples[index]) / 32_768
                squared += sample * sample
            }
            level.store(min(sqrt(squared / Float(count)) * 3, 1), ordering: .relaxed)
            pendingPCM.append(UnsafeBufferPointer(start: UnsafeRawPointer(samples).assumingMemoryBound(to: UInt8.self),
                                                 count: count * MemoryLayout<Int16>.size))
            while pendingPCM.count >= chunkBytes {
                guard active.load(ordering: .acquiring) else { return }
                onAudio(Data(pendingPCM.prefix(chunkBytes)))
                pendingPCM.removeFirst(chunkBytes)
            }
        }
    }
}
