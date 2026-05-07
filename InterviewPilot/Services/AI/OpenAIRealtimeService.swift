import Foundation
import Observation

@Observable
final class OpenAIRealtimeService {
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var isConnected = false
    private(set) var isReconnecting = false

    @ObservationIgnored var onSessionCreated: (() -> Void)?
    @ObservationIgnored var onSpeechStarted: (() -> Void)?
    @ObservationIgnored var onSpeechStopped: (() -> Void)?
    @ObservationIgnored var onAudioDelta: ((Data) -> Void)?
    @ObservationIgnored var onTranscriptDelta: ((String) -> Void)?
    @ObservationIgnored var onInputTranscript: ((String) -> Void)?
    @ObservationIgnored var onResponseDone: (() -> Void)?
    @ObservationIgnored var onError: ((String) -> Void)?
    @ObservationIgnored var onReconnected: (() -> Void)?

    private let aiClient: AIClient
    private var lastInstructions: String = ""
    private var lastVoice: String = APIConfig.realtimeVoice
    private var reconnectAttempts = 0
    private var intentionalDisconnect = false
    private var reconnectTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?

    private static let maxReconnectAttempts = 5
    private static let keepAliveIntervalSeconds: UInt64 = 25

    init(aiClient: AIClient = .shared) {
        self.aiClient = aiClient
    }

    // MARK: - Connection

    func connect(instructions: String, voice: String = APIConfig.realtimeVoice) async throws {
        intentionalDisconnect = false
        reconnectAttempts = 0
        lastInstructions = instructions
        lastVoice = voice
        try await connectInternal(instructions: instructions, voice: voice)
    }

    private func connectInternal(instructions: String, voice: String) async throws {
        cleanupConnection()

        // Mint a fresh ephemeral client_secret from the backend. The token
        // is bound to this session only and expires in ~1 minute.
        let realtime = try await aiClient.createRealtimeSession(
            instructions: instructions,
            voice: voice,
            model: APIConfig.realtimeModel,
            transcription: (model: "whisper-1", language: "en"),
            turnDetection: (
                threshold: Double(APIConfig.realtimeVadThreshold),
                prefixPaddingMs: APIConfig.realtimeVadPrefixPaddingMs,
                silenceDurationMs: APIConfig.realtimeVadSilenceDurationMs
            )
        )

        let urlString = "wss://api.openai.com/v1/realtime?model=\(realtime.model)"
        guard let url = URL(string: urlString) else {
            throw RealtimeServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(realtime.clientSecret)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config)
        self.urlSession = session
        self.webSocket = session.webSocketTask(with: request)
        self.webSocket?.resume()

        // Wait for session.created handshake
        try await receiveFirstMessage()
        self.isConnected = true

        // Configure the session
        try await sendSessionUpdate(instructions: instructions, voice: voice)

        startKeepAlive()
        Task { await receiveMessages() }
    }

    // MARK: - Audio Sending

    func sendAudio(_ data: Data) {
        guard isConnected, !isReconnecting else { return }

        let base64Audio = data.base64EncodedString()
        let json = """
        {"type":"input_audio_buffer.append","audio":"\(base64Audio)"}
        """

        webSocket?.send(.string(json)) { error in
            if let error {
                Task { @MainActor [weak self] in
                    guard let self, self.isConnected else { return }
                    self.isConnected = false
                    self.attemptReconnect(reason: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Response Control

    /// Triggers the AI to generate a new response turn (e.g., skip to next question).
    func sendResponseCreate() {
        guard isConnected, !isReconnecting else { return }

        let json = #"{"type":"response.create"}"#
        webSocket?.send(.string(json)) { error in
            if let error {
                Task { @MainActor [weak self] in
                    guard let self, self.isConnected else { return }
                    self.isConnected = false
                    self.attemptReconnect(reason: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        intentionalDisconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil

        let socket = webSocket
        let session = urlSession

        Task { @MainActor [weak self, socket, session] in
            socket?.cancel(with: .normalClosure, reason: nil)
            session?.invalidateAndCancel()
            self?.webSocket = nil
            self?.urlSession = nil
            self?.isConnected = false
            self?.isReconnecting = false
            self?.reconnectAttempts = 0
        }
    }

    // MARK: - Session Update
    // Session config (instructions, voice, VAD, transcription) is set at mint
    // time on the ephemeral session itself, so no follow-up session.update
    // is needed after connect. Suppress unused-parameter warning.
    private func sendSessionUpdate(instructions: String, voice: String) async throws {
        _ = (instructions, voice)
    }

    // MARK: - Keep-Alive

    private func startKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.keepAliveIntervalSeconds * 1_000_000_000)
                guard !Task.isCancelled else { break }
                guard let self, self.isConnected, !self.isReconnecting else { continue }

                // Send a ping to keep the connection alive
                let ping = #"{"type":"input_audio_buffer.append","audio":""}"#
                self.webSocket?.send(.string(ping)) { error in
                    if let error {
                        Task { @MainActor [weak self] in
                            guard let self, self.isConnected else { return }
                            self.isConnected = false
                            self.attemptReconnect(reason: "Keep-alive failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Auto-Reconnection

    private func attemptReconnect(reason: String) {
        guard !intentionalDisconnect else { return }
        guard reconnectAttempts < Self.maxReconnectAttempts else {
            isReconnecting = false
            onError?("Connection lost after \(Self.maxReconnectAttempts) reconnect attempts: \(reason)")
            return
        }

        isReconnecting = true
        reconnectAttempts += 1
        let attempt = reconnectAttempts
        let instructions = lastInstructions
        let voice = lastVoice

        // Exponential backoff: 0.5s, 1s, 2s, 4s, 8s
        let delaySeconds = 0.5 * pow(2.0, Double(attempt - 1))

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, !self.intentionalDisconnect else { return }

            do {
                try await self.connectInternal(instructions: instructions, voice: voice)
                self.reconnectAttempts = 0
                self.isReconnecting = false
                self.onReconnected?()
            } catch {
                self.attemptReconnect(reason: error.localizedDescription)
            }
        }
    }

    private func cleanupConnection() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    // MARK: - Message Receiving

    private func receiveFirstMessage() async throws {
        guard let ws = webSocket else {
            throw RealtimeServiceError.notConnected
        }

        let message = try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
            group.addTask {
                try await ws.receive()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                throw RealtimeServiceError.handshakeTimeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        // Verify it's session.created
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "session.created" else {
                throw RealtimeServiceError.unexpectedHandshake
            }
            onSessionCreated?()
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                guard let jsonData = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String,
                      type == "session.created" else {
                    throw RealtimeServiceError.unexpectedHandshake
                }
                onSessionCreated?()
            }
        @unknown default:
            throw RealtimeServiceError.unexpectedHandshake
        }
    }

    private func receiveMessages() async {
        guard let ws = webSocket else { return }

        do {
            while isConnected {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            guard isConnected else { return }
            isConnected = false

            if !intentionalDisconnect {
                attemptReconnect(reason: error.localizedDescription)
            } else {
                onError?(error.localizedDescription)
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "session.created":
            onSessionCreated?()

        case "input_audio_buffer.speech_started":
            onSpeechStarted?()

        case "input_audio_buffer.speech_stopped":
            onSpeechStopped?()

        case "response.audio.delta":
            guard let deltaBase64 = json["delta"] as? String,
                  let audioData = Data(base64Encoded: deltaBase64) else { return }
            onAudioDelta?(audioData)

        case "response.audio_transcript.delta":
            guard let delta = json["delta"] as? String else { return }
            onTranscriptDelta?(delta)

        case "conversation.item.input_audio_transcription.completed":
            guard let transcript = json["transcript"] as? String else { return }
            onInputTranscript?(transcript)

        case "response.done":
            onResponseDone?()

        case "error":
            let message = extractErrorMessage(from: json) ?? "OpenAI Realtime API error"
            onError?(message)

        default:
            break
        }
    }

    private func extractErrorMessage(from payload: [String: Any]) -> String? {
        if let error = payload["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let code = error["code"] as? String, !code.isEmpty {
                return code
            }
        }
        if let message = payload["message"] as? String, !message.isEmpty {
            return message
        }
        return nil
    }
}

// MARK: - Error Types

enum RealtimeServiceError: LocalizedError {
    case invalidURL
    case notConnected
    case handshakeTimeout
    case unexpectedHandshake

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Realtime API URL"
        case .notConnected:
            return "WebSocket is not connected"
        case .handshakeTimeout:
            return "Realtime session handshake timed out"
        case .unexpectedHandshake:
            return "Unexpected handshake response from Realtime API"
        }
    }
}
