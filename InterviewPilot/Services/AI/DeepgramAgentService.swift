import Foundation

/// Personal-device connection to Deepgram. The only credential is the user's
/// Deepgram key; no application server, login token or OpenAI key is involved.
@MainActor
final class DeepgramAgentService {
    private(set) var state: AgentConnectionState = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    var onStateChange: ((AgentConnectionState) -> Void)?
    var onEvent: ((AgentEvent) -> Void)?
    var onAudioGap: (() -> Void)?

    // This queue is safe to access directly from the AVAudioEngine callback.
    nonisolated private let audioQueue = AgentAudioQueue()

    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var active = false
    private var apiKey = ""
    private var prompt = ""
    private var history: [AgentHistoryMessage] = []
    private var retries = 0
    private var settingsSent = false
    private var userSpeaking = false
    private var responseInProgress = false
    private var pendingAnswerSince: ContinuousClock.Instant?
    private var audioSendStarted: ContinuousClock.Instant?
    private var lastAudioSent = ContinuousClock.now
    private var lastKeepAlive = ContinuousClock.now
    private var lastPing = ContinuousClock.now
    private var pingPendingSince: ContinuousClock.Instant?
    private var readySince = ContinuousClock.now
    private var rolloverRequested = false

    /// Connect returns immediately. Start the microphone only after `.ready`.
    func connect(apiKey: String, prompt: String, history: [AgentHistoryMessage] = []) {
        stop()
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            state = .failed(AgentClientError.missingKey.localizedDescription)
            return
        }
        do {
            _ = try DeepgramProtocol.settings(prompt: prompt, history: history)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        self.apiKey = key
        self.prompt = prompt
        self.history = DeepgramProtocol.boundedHistory(history)
        retries = 0
        active = true
        state = .connecting
        openConnection()
    }

    func stop() {
        active = false
        generation &+= 1
        reconnectTask?.cancel()
        reconnectTask = nil
        closeConnection()
        apiKey = ""
        prompt = ""
        history = []
        state = .idle
    }

    /// Updates only the next connection's snapshot. Major changes during a live
    /// interview should stop and restart, avoiding ambiguous UpdatePrompt rules.
    func updateContext(prompt: String, history: [AgentHistoryMessage]) {
        self.prompt = prompt
        self.history = DeepgramProtocol.boundedHistory(history)
    }

    nonisolated func sendAudio(_ pcm: Data) {
        audioQueue.push(pcm)
    }

    /// Exactly one transport attempt. Returning means the socket sent the frame,
    /// not that the model accepted it. Observe `.inputRejected` and the matching
    /// user transcript; preserve manual input until then. Never replay on reconnect.
    func sendText(_ text: String) async throws {
        let payload = try DeepgramProtocol.injectUser(text)
        try await sendControl(payload)
    }

    func forceEndTurn() async throws {
        guard active, state == .ready else { throw AgentClientError.notReady }
        let current = generation
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        // The caller must mute capture first. ForceEndTurn must follow every
        // accepted PCM frame, including the one already handed to socket.send.
        // Otherwise the final words can be assigned to the next turn.
        while audioQueue.bufferedBytes > 0 || audioSendStarted != nil {
            guard isCurrent(current), state == .ready else { throw AgentClientError.notReady }
            guard ContinuousClock.now < deadline else { throw AgentClientError.audioDrainTimeout }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard isCurrent(current), state == .ready else { throw AgentClientError.notReady }
        try await sendControl(DeepgramProtocol.forceEndTurn)
    }

    private func sendControl(_ payload: String) async throws {
        guard active, state == .ready, let socket else { throw AgentClientError.notReady }
        let current = generation
        do {
            try await socket.send(.string(payload))
            guard isCurrent(current), state == .ready else { throw AgentClientError.sendUncertain }
        } catch {
            if isCurrent(current) { connectionFailed(error, socket: socket, generation: current) }
            throw AgentClientError.sendUncertain
        }
    }

    private func openConnection() {
        guard active else { return }
        generation &+= 1
        let current = generation
        settingsSent = false
        userSpeaking = false
        responseInProgress = false
        pendingAnswerSince = nil
        audioSendStarted = nil
        pingPendingSince = nil
        rolloverRequested = false

        var request = URLRequest(url: DeepgramProtocol.endpoint)
        request.timeoutInterval = 12
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 7_200
        configuration.urlCache = nil
        let newSession = URLSession(configuration: configuration)
        let newSocket = newSession.webSocketTask(with: request)
        newSocket.maximumMessageSize = 1_048_576
        session = newSession
        socket = newSocket
        newSocket.resume()

        receiveTask = Task { [weak self, newSocket] in
            do {
                while !Task.isCancelled {
                    let message = try await newSocket.receive()
                    guard let self, self.isCurrent(current) else { return }
                    switch message {
                    case .string(let text):
                        try await self.receive(text, socket: newSocket, generation: current)
                    case .data:
                        // Suggestions stay silent. Deepgram may still generate
                        // and bill output speech; no playback is performed.
                        break
                    @unknown default: break
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.connectionFailed(error, socket: newSocket, generation: current)
            }
        }

        connectTimeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(12)) } catch { return }
            guard let self, self.isCurrent(current), self.state != .ready else { return }
            self.fail(DeepgramProtocol.failure(code: "CONNECT_TIMEOUT"), generation: current)
        }
    }

    private func receive(_ text: String, socket: URLSessionWebSocketTask, generation current: UInt64) async throws {
        guard isCurrent(current) else { return }
        switch try DeepgramProtocol.decode(text) {
        case .welcome:
            guard !settingsSent else { return }
            settingsSent = true
            // Welcome must arrive first. No audio, ping, keepalive or injection
            // is emitted before SettingsApplied.
            let payload = try DeepgramProtocol.settings(prompt: prompt, history: history)
            try await socket.send(.string(payload))
        case .settingsApplied:
            guard settingsSent else {
                fail(DeepgramProtocol.failure(code: "INVALID_SETTINGS"), generation: current)
                return
            }
            guard state != .ready else { return }
            connectTimeoutTask?.cancel()
            connectTimeoutTask = nil
            readySince = .now
            lastAudioSent = .now
            lastKeepAlive = .now
            lastPing = .now
            beginAudioPump(socket: socket, generation: current)
            beginWatchdog(socket: socket, generation: current)
            state = .ready
        case .event(let event):
            guard state == .ready else { return }
            switch event {
            case .userStartedSpeaking:
                userSpeaking = true
                responseInProgress = false
                pendingAnswerSince = nil
            case .userTranscript:
                userSpeaking = false
                responseInProgress = true
                pendingAnswerSince = .now
            case .thinking:
                responseInProgress = true
                if pendingAnswerSince == nil { pendingAnswerSince = .now }
            case .assistantText:
                userSpeaking = false
                responseInProgress = true
                pendingAnswerSince = nil
            case .responseFinished:
                responseInProgress = false
                pendingAnswerSince = nil
            case .latency, .warning, .inputRejected: break
            }
            onEvent?(event)
        case .error(let code):
            fail(DeepgramProtocol.failure(code: code), generation: current)
        case .warning(let code):
            if code == "MAXIMUM_SESSION_LENGTH_APPROACHING" { rolloverRequested = true }
            onEvent?(.warning(DeepgramProtocol.warning(code: code)))
        case .unknown: break
        }
    }

    private func beginAudioPump(socket: URLSessionWebSocketTask, generation current: UInt64) {
        let signals = audioQueue.start()
        let queue = audioQueue
        sendTask = Task { [weak self, socket] in
            for await _ in signals {
                guard !Task.isCancelled else { return }
                while let pcm = queue.pop() {
                    guard let self, self.isCurrent(current), self.state == .ready else { return }
                    // Missing frames can corrupt an interview question. Stop and
                    // recover visibly instead of feeding a delayed/incomplete turn.
                    if queue.takeDroppedFlag() {
                        self.fail(DeepgramProtocol.failure(code: "AUDIO_SEND_TIMEOUT"), generation: current)
                        return
                    }
                    self.audioSendStarted = .now
                    do {
                        try await socket.send(.data(pcm))
                        guard self.isCurrent(current) else { return }
                        self.audioSendStarted = nil
                        self.lastAudioSent = .now
                    } catch {
                        self.connectionFailed(error, socket: socket, generation: current)
                        return
                    }
                }
                if queue.takeDroppedFlag(), let self, self.isCurrent(current) {
                    self.fail(DeepgramProtocol.failure(code: "AUDIO_SEND_TIMEOUT"), generation: current)
                    return
                }
            }
        }
    }

    private func beginWatchdog(socket: URLSessionWebSocketTask, generation current: UInt64) {
        watchdogTask = Task { [weak self, socket] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, self.isCurrent(current), self.state == .ready else { return }
                self.watchdogTick(socket: socket, generation: current)
            }
        }
    }

    private func watchdogTick(socket: URLSessionWebSocketTask, generation current: UInt64) {
        let now = ContinuousClock.now
        if let started = audioSendStarted, started.duration(to: now) > .seconds(3) {
            fail(DeepgramProtocol.failure(code: "AUDIO_SEND_TIMEOUT"), generation: current)
            return
        }
        if let started = pingPendingSince, started.duration(to: now) > .seconds(6) {
            fail(DeepgramProtocol.failure(code: "HEARTBEAT_TIMEOUT"), generation: current)
            return
        }
        if let started = pendingAnswerSince, started.duration(to: now) > .seconds(25) {
            fail(.init(message: "Deepgram has not returned an answer. Reconnecting; repeat or type the unfinished question when ready.", canRetry: true), generation: current)
            return
        }
        if readySince.duration(to: now) > .seconds(110 * 60) { rolloverRequested = true }
        if rolloverRequested, !userSpeaking, !responseInProgress {
            renewConnection(generation: current)
            return
        }
        if lastAudioSent.duration(to: now) >= .seconds(4), lastKeepAlive.duration(to: now) >= .seconds(8) {
            lastKeepAlive = now
            socket.send(.string(DeepgramProtocol.keepAlive)) { [weak self, socket] error in
                guard let error else { return }
                Task { @MainActor [weak self] in
                    self?.connectionFailed(error, socket: socket, generation: current)
                }
            }
        }
        if pingPendingSince == nil, lastPing.duration(to: now) >= .seconds(10) {
            pingPendingSince = now
            lastPing = now
            socket.sendPing { [weak self, socket] error in
                Task { @MainActor [weak self] in
                    guard let self, self.isCurrent(current) else { return }
                    if let error {
                        self.connectionFailed(error, socket: socket, generation: current)
                    } else {
                        self.pingPendingSince = nil
                    }
                }
            }
        }
    }

    private func renewConnection(generation current: UInt64) {
        guard isCurrent(current) else { return }
        generation &+= 1
        closeConnection()
        state = .reconnecting(attempt: 0)
        onEvent?(.warning("Refreshing the Deepgram connection with your interview context. Wait for Ready before continuing."))
        openConnection()
    }

    private func connectionFailed(_ error: Error, socket: URLSessionWebSocketTask, generation current: UInt64) {
        guard isCurrent(current) else { return }
        let status = (socket.response as? HTTPURLResponse)?.statusCode
        if let clientError = error as? AgentClientError {
            fail(.init(message: clientError.localizedDescription, canRetry: false), generation: current)
        } else {
            // Do not include localizedDescription from networking/provider code:
            // some stacks put request headers or URLs in their error messages.
            fail(DeepgramProtocol.failure(code: "CONNECTION_LOST", httpStatus: status), generation: current)
        }
    }

    private func fail(_ failure: AgentFailure, generation current: UInt64) {
        guard isCurrent(current) else { return }
        let hadAudioConnection = state == .ready
        generation &+= 1 // Invalidates every callback from the retired socket.
        let reconnectGeneration = generation
        closeConnection()
        if hadAudioConnection { onAudioGap?() }
        // A callback may explicitly stop the session; never reconnect against
        // that newer user decision.
        guard active, generation == reconnectGeneration else { return }
        guard failure.canRetry, retries < DeepgramProtocol.maximumAutomaticRetries else {
            active = false
            apiKey = ""
            let suffix = failure.canRetry ? " Automatic retries stopped. Check the connection and tap Retry." : ""
            state = .failed(failure.message + suffix)
            return
        }
        retries += 1
        state = .reconnecting(attempt: retries)
        onEvent?(.warning(failure.message))
        let seconds = min(pow(2.0, Double(retries - 1)), 4) + Double.random(in: 0...0.25)
        reconnectTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self, self.active, self.generation == reconnectGeneration else { return }
            self.openConnection()
        }
    }

    private func isCurrent(_ candidate: UInt64) -> Bool {
        active && candidate == generation
    }

    private func closeConnection() {
        audioQueue.stop()
        receiveTask?.cancel()
        receiveTask = nil
        sendTask?.cancel()
        sendTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        audioSendStarted = nil
        pingPendingSince = nil
        pendingAnswerSince = nil
    }

    deinit {
        audioQueue.stop()
        receiveTask?.cancel()
        sendTask?.cancel()
        watchdogTask?.cancel()
        connectTimeoutTask?.cancel()
        reconnectTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }
}
