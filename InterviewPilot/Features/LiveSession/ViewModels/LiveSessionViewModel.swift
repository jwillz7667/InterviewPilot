import Foundation
import Observation
import UIKit

/// Owns a single interview. Provider credentials never enter saved configuration/history.
@MainActor
@Observable
final class LiveSessionViewModel {
    let configuration: InterviewConfiguration
    let agent = DeepgramAgentService()
    let audio = AudioCaptureService()
    let id = UUID()
    let startedAt = Date()
    private(set) var connectionState: AgentConnectionState = .idle
    private(set) var messages: [InterviewMessage] = []
    private(set) var latestAnswer = ""
    private(set) var latestQuestion = ""
    private(set) var isRunning = false
    private(set) var isStarting = false
    private(set) var microphoneEnabled = true
    private(set) var isThinking = false
    private(set) var userIsSpeaking = false
    var rejectedQuestion = ""
    private(set) var firstResponseLatencyMS: Double?
    private(set) var currentResponseLatencyMS: Double?
    private(set) var notice: String?
    private(set) var saveError: String?
    private(set) var elapsedSeconds: TimeInterval = 0

    @ObservationIgnored private let store: LocalInterviewStore
    @ObservationIgnored private var lifetime = UUID()
    @ObservationIgnored private var currentAnswerID: UUID?
    @ObservationIgnored private var responseStartedAt: Date?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var checkpointTask: Task<Void, Never>?
    @ObservationIgnored private var pendingManualText: (text: String, sentAt: Date)?
    @ObservationIgnored private var practiceStarted = false

    init(configuration: InterviewConfiguration, store: LocalInterviewStore) {
        self.configuration = configuration
        self.store = store
        audio.onAudioBuffer = { [weak agent] data in agent?.sendAudio(data) }
        audio.onInterruption = { [weak self] interrupted in
            guard interrupted else { return }
            self?.pause(reason: "Audio was interrupted. Resume when you are ready.")
        }
        audio.onRouteChange = { [weak self] in
            self?.pause(reason: "The microphone route changed. Check your input and resume.")
        }
        audio.onError = { [weak self] _ in
            self?.pause(reason: "Audio capture could not keep up. Resume or use typed questions.")
        }
        agent.onStateChange = { [weak self] state in self?.connectionChanged(state) }
        agent.onEvent = { [weak self] event in self?.receive(event) }
        agent.onAudioGap = { [weak self] in
            self?.notice = "Some audio was dropped while the connection recovered. Repeat the last question if needed."
        }
    }

    var isReady: Bool {
        if case .ready = connectionState { return true }
        return false
    }

    var connectionLabel: String {
        switch connectionState {
        case .idle: return isStarting ? "Starting…" : "Paused"
        case .connecting: return "Connecting to Deepgram…"
        case .ready: return audio.isCapturing ? "Listening" : "Ready for typed questions"
        case .reconnecting(let attempt): return "Reconnecting (\(attempt)/3)…"
        case .failed: return "Connection stopped"
        }
    }

    var transcriptText: String {
        messages.map { "\($0.role == .user ? "Input" : "Suggestion"): \($0.content)" }
            .joined(separator: "\n\n")
    }

    func start(useMicrophone: Bool = true) async {
        guard !isRunning, !isStarting else { return }
        lifetime = UUID()
        let ticket = lifetime
        isStarting = true
        notice = nil
        microphoneEnabled = useMicrophone
        defer { if lifetime == ticket { isStarting = false } }
        do {
            guard let key = try DeepgramKeyStore.load(), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                notice = "Add your Deepgram API key in Settings before starting."
                return
            }
            if useMicrophone {
                do { try await audio.ensureMicrophonePermission() }
                catch {
                    guard lifetime == ticket else { return }
                    microphoneEnabled = false
                    notice = "Microphone access is unavailable. You can still send typed questions, or enable access in iOS Settings."
                }
            }
            guard lifetime == ticket, !Task.isCancelled else { return }
            isRunning = true
            UIApplication.shared.isIdleTimerDisabled = true
            agent.connect(apiKey: key, prompt: configuration.systemPrompt, history: history)
            startClock()
        } catch {
            notice = "The Deepgram key could not be read securely. Save it again in Settings."
        }
    }

    func pause(reason: String? = nil) {
        lifetime = UUID()
        isStarting = false
        isRunning = false
        audio.stopCapture()
        agent.stop()
        timeoutTask?.cancel()
        clockTask?.cancel()
        isThinking = false
        userIsSpeaking = false
        responseStartedAt = nil
        pendingManualText = nil
        UIApplication.shared.isIdleTimerDisabled = false
        elapsedSeconds = Date().timeIntervalSince(startedAt)
        if let reason { notice = reason }
        checkpoint()
    }

    func finish() async {
        pause()
        checkpointTask?.cancel()
        await persistSnapshot()
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        microphoneEnabled = enabled
        if !enabled {
            audio.stopCapture()
            if isReady, userIsSpeaking { await answerNow() }
            return
        }
        guard isReady, isRunning else { return }
        do {
            try await audio.ensureMicrophonePermission()
            guard isReady, isRunning, microphoneEnabled else { return }
            try audio.startCapture()
        } catch {
            microphoneEnabled = false
            notice = "Microphone capture is unavailable. Check iOS permissions and your audio input, or use typed questions."
        }
    }

    @discardableResult
    func sendQuestion(_ raw: String) async -> Bool {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(8_000))
        guard !text.isEmpty, isReady, isRunning, !isThinking, !userIsSpeaking else { return false }
        let ticket = lifetime
        let message = InterviewMessage(role: .user, content: text)
        messages.append(message)
        latestQuestion = text
        pendingManualText = (text, Date())
        beginResponse()
        updateHistory()
        do {
            try await agent.sendText(text)
            guard lifetime == ticket else { return false }
            checkpoint()
            return true
        } catch {
            // Do not replay an uncertain send automatically: it could duplicate the question.
            guard lifetime == ticket else { return false }
            pause(reason: "The question could not be confirmed. Resume and resend it if no answer arrived.")
            return false
        }
    }

    func answerNow() async {
        guard isReady else { return }
        let resumeCapture = audio.isCapturing
        audio.stopCapture()
        do { try await agent.forceEndTurn() }
        catch { notice = "Could not finish this turn. Repeat or type the question." }
        if resumeCapture, microphoneEnabled, isReady, isRunning {
            do { try audio.startCapture() }
            catch { microphoneEnabled = false; notice = "Microphone could not resume. Typed questions are available." }
        }
    }

    private var history: [AgentHistoryMessage] {
        messages.suffix(80).map {
            AgentHistoryMessage(role: $0.role == .user ? .user : .assistant, content: $0.content)
        }
    }

    private func updateHistory() {
        agent.updateContext(prompt: configuration.systemPrompt, history: history)
    }

    private func connectionChanged(_ state: AgentConnectionState) {
        connectionState = state
        switch state {
        case .ready:
            guard isRunning else { return }
            if microphoneEnabled {
                do { try audio.startCapture() }
                catch {
                    microphoneEnabled = false
                    notice = "Microphone capture failed. Typed questions are still available."
                }
            }
            if configuration.mode == .practice, !practiceStarted {
                practiceStarted = true
                Task { [weak self] in
                    guard let self else { return }
                    let sent = await self.sendQuestion("Start the practice interview with one role-specific question.")
                    if !sent { self.practiceStarted = false }
                }
            }
        case .connecting, .reconnecting:
            audio.stopCapture()
            userIsSpeaking = false
            timeoutTask?.cancel()
            isThinking = false
            responseStartedAt = nil
        case .failed(let message):
            audio.stopCapture()
            userIsSpeaking = false
            isRunning = false
            isStarting = false
            isThinking = false
            timeoutTask?.cancel()
            clockTask?.cancel()
            notice = message
            UIApplication.shared.isIdleTimerDisabled = false
            checkpoint()
        case .idle:
            audio.stopCapture()
        }
    }

    private func receive(_ event: AgentEvent) {
        guard isRunning else { return }
        switch event {
        case .userStartedSpeaking:
            userIsSpeaking = true
            // Keep the last useful answer visible while the next question is being spoken.
            timeoutTask?.cancel()
            isThinking = false
            responseStartedAt = nil
        case .userTranscript(let raw):
            userIsSpeaking = false
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if let pending = pendingManualText,
               pending.text == text, Date().timeIntervalSince(pending.sentAt) < 10 {
                pendingManualText = nil
            } else {
                messages.append(InterviewMessage(role: .user, content: text))
            }
            latestQuestion = text
            beginResponse()
            updateHistory()
            checkpoint()
        case .thinking:
            if !isThinking { beginResponse() }
        case .assistantText(let raw):
            userIsSpeaking = false
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            if currentAnswerID == nil {
                if let start = responseStartedAt {
                    let measured = Date().timeIntervalSince(start) * 1_000
                    currentResponseLatencyMS = measured
                    if firstResponseLatencyMS == nil { firstResponseLatencyMS = measured }
                }
                let message = InterviewMessage(role: .assistant, content: text)
                currentAnswerID = message.id
                messages.append(message)
                latestAnswer = text
            } else if let index = messages.lastIndex(where: { $0.id == currentAnswerID }) {
                // Deepgram emits statements; render them at arrival with no synthetic delay.
                messages[index].content += " " + text
                latestAnswer = messages[index].content
            }
            pendingManualText = nil
            isThinking = true
            armResponseTimeout()
            updateHistory()
            checkpoint()
        case .responseFinished:
            isThinking = false
            timeoutTask?.cancel()
            responseStartedAt = nil
            checkpoint()
        case .latency:
            break // Provider total is first audio, not this UI's time to first text.
        case .inputRejected(let message):
            if let pending = pendingManualText {
                rejectedQuestion = pending.text
                if messages.last?.role == .user, messages.last?.content == pending.text { messages.removeLast() }
            }
            pendingManualText = nil
            isThinking = false
            timeoutTask?.cancel()
            notice = message
            updateHistory()
            checkpoint()
        case .warning(let message):
            notice = message
        }
    }

    private func beginResponse() {
        currentAnswerID = nil
        responseStartedAt = Date()
        currentResponseLatencyMS = nil
        isThinking = true
        armResponseTimeout()
    }

    private func armResponseTimeout() {
        timeoutTask?.cancel()
        let ticket = lifetime
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) }
            catch { return }
            guard let self, self.lifetime == ticket, self.isRunning else { return }
            self.pause(reason: "Deepgram took too long to respond. Your last answer and context are saved. Resume to try again.")
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard let self else { return }
                self.elapsedSeconds = Date().timeIntervalSince(self.startedAt)
            }
        }
    }

    private func checkpoint() {
        checkpointTask?.cancel()
        checkpointTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) }
            catch { return }
            await self?.persistSnapshot()
        }
    }

    private func persistSnapshot() async {
        guard !messages.isEmpty else { return }
        let snapshot = SavedInterview(
            id: id, startedAt: startedAt, configuration: configuration, messages: messages,
            durationSeconds: Date().timeIntervalSince(startedAt),
            firstResponseLatencyMS: firstResponseLatencyMS
        )
        do {
            try await store.saveSession(snapshot)
            saveError = nil
        } catch {
            saveError = "This session could not be saved on the device. Export the transcript before closing."
        }
    }
}
