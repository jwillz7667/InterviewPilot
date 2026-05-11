import Foundation
import Observation

enum DeepgramConnectError: LocalizedError {
    case handshakeTimedOut
    case handshakeFailed(underlying: Error)
    case socketUnavailable

    var errorDescription: String? {
        switch self {
        case .handshakeTimedOut:
            return "Transcription service did not respond within 5 seconds. Check your network and try again."
        case .handshakeFailed(let underlying):
            return "Transcription handshake failed: \(underlying.localizedDescription)"
        case .socketUnavailable:
            return "Transcription socket was not available."
        }
    }
}

@Observable
final class DeepgramService {
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var isConnected = false
    private(set) var isReconnecting = false

    @ObservationIgnored var onPartialTranscript: ((String) -> Void)?
    @ObservationIgnored var onFinalTranscript: ((String) -> Void)?
    @ObservationIgnored var onSpeechStarted: (() -> Void)?
    @ObservationIgnored var onSpeechEnded: (() -> Void)?
    @ObservationIgnored var onError: ((String) -> Void)?
    @ObservationIgnored var onReconnected: (() -> Void)?

    private let aiClient: AIClient
    private var lastConnectKeywords: [String] = []
    private var reconnectAttempts = 0
    private var intentionalDisconnect = false
    private var keepAliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private static let maxReconnectAttempts = 5
    private static let keepAliveIntervalSeconds: UInt64 = 8

    init(aiClient: AIClient = .shared) {
        self.aiClient = aiClient
    }

    func connect(keywords: [String] = []) async throws {
        intentionalDisconnect = false
        reconnectAttempts = 0
        lastConnectKeywords = keywords
        try await connectInternal(keywords: keywords)
    }

    private func connectInternal(keywords: [String]) async throws {
        // Clean up previous connection
        cleanupConnection()

        let apiKey = try await aiClient.currentDeepgramKey()

        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: APIConfig.deepgramModel),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "utterance_end_ms", value: String(APIConfig.utteranceEndMs)),
            URLQueryItem(name: "vad_events", value: "true"),
            URLQueryItem(name: "encoding", value: APIConfig.deepgramEncoding),
            URLQueryItem(name: "sample_rate", value: String(APIConfig.deepgramSampleRate)),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "endpointing", value: String(APIConfig.endpointingMs)),
        ]

        let boostTerms = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(50)

        let usesNovaThree = APIConfig.deepgramModel.lowercased().contains("nova-3")
        for term in boostTerms {
            components.queryItems?.append(
                URLQueryItem(
                    name: usesNovaThree ? "keyterm" : "keywords",
                    value: usesNovaThree ? term : "\(term):2.0"
                )
            )
        }

        var request = URLRequest(url: components.url!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600  // 1 hour for long interviews
        let session = URLSession(configuration: config)
        self.urlSession = session
        self.webSocket = session.webSocketTask(with: request)
        self.webSocket?.resume()

        // Wait for the first message to confirm the WebSocket handshake completed.
        // Setting isConnected before the handshake finishes causes audio sent in
        // that window to be silently dropped. If Deepgram refuses the socket
        // (auth, scope, account state), the receive throws — surface it instead
        // of leaving the UI stuck on "waiting for interviewer".
        do {
            try await receiveFirstMessage()
        } catch {
            CrashReportingService.breadcrumb(
                category: "deepgram",
                message: "ws.handshake_failed: \(error.localizedDescription)"
            )
            cleanupConnection()
            throw error
        }
        self.isConnected = true
        CrashReportingService.breadcrumb(category: "deepgram", message: "ws.opened")

        startKeepAlive()
        Task { await receiveMessages() }
    }

    func sendAudio(_ data: Data) {
        guard isConnected, !isReconnecting else { return }
        webSocket?.send(.data(data)) { error in
            if let error {
                Task { @MainActor [weak self] in
                    guard let self, self.isConnected else { return }
                    self.isConnected = false
                    self.attemptReconnect(reason: error.localizedDescription)
                }
            }
        }
    }

    func disconnect() {
        intentionalDisconnect = true
        CrashReportingService.breadcrumb(category: "deepgram", message: "ws.closed")
        reconnectTask?.cancel()
        reconnectTask = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil

        let socket = webSocket
        let session = urlSession
        let closeMessage = #"{"type": "CloseStream"}"#

        Task { @MainActor [weak self, socket, session] in
            if let socket {
                try? await socket.send(.string(closeMessage))
                socket.cancel(with: .normalClosure, reason: nil)
            }

            session?.invalidateAndCancel()
            self?.webSocket = nil
            self?.urlSession = nil
            self?.isConnected = false
            self?.isReconnecting = false
            self?.reconnectAttempts = 0
        }
    }

    // MARK: - Keep-Alive

    private func startKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.keepAliveIntervalSeconds * 1_000_000_000)
                guard !Task.isCancelled else { break }
                guard let self, self.isConnected, !self.isReconnecting else { continue }

                // Send a Deepgram KeepAlive message to prevent idle timeout
                let keepAlive = #"{"type": "KeepAlive"}"#
                self.webSocket?.send(.string(keepAlive)) { error in
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
            CrashReportingService.breadcrumb(category: "deepgram", message: "ws.reconnect_failed", level: .error, data: ["reason": reason])
            onError?("Connection lost after \(Self.maxReconnectAttempts) reconnect attempts: \(reason)")
            return
        }

        isReconnecting = true
        reconnectAttempts += 1
        let attempt = reconnectAttempts
        let keywords = lastConnectKeywords

        // Exponential backoff with full jitter, capped at 30s. Jitter avoids
        // thundering-herd reconnects when many clients drop on a regional outage.
        let base = min(30.0, 0.5 * pow(2.0, Double(attempt - 1)))
        let delaySeconds = Double.random(in: (base / 2)...base)

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, !self.intentionalDisconnect else { return }

            do {
                try await self.connectInternal(keywords: keywords)
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

    /// Waits for the first WebSocket message to confirm the handshake completed.
    /// Deepgram sends metadata on connect; receiving it proves the connection is live.
    /// Times out after 5 seconds and throws so the caller can surface the failure.
    private func receiveFirstMessage() async throws {
        guard let ws = webSocket else { throw DeepgramConnectError.socketUnavailable }
        let message: URLSessionWebSocketTask.Message
        do {
            message = try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
                group.addTask {
                    try await ws.receive()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    throw DeepgramConnectError.handshakeTimedOut
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch let error as DeepgramConnectError {
            throw error
        } catch {
            throw DeepgramConnectError.handshakeFailed(underlying: error)
        }
        // Process the first message so it isn't lost
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
        case "Results":
            guard let channel = json["channel"] as? [String: Any],
                  let alternatives = channel["alternatives"] as? [[String: Any]],
                  let first = alternatives.first,
                  let transcript = first["transcript"] as? String,
                  !transcript.isEmpty else { return }

            let isFinal = (json["is_final"] as? Bool) ?? false
            let speechFinal = (json["speech_final"] as? Bool) ?? false

            if isFinal || speechFinal {
                self.onFinalTranscript?(transcript)
            } else {
                self.onPartialTranscript?(transcript)
            }

        case "SpeechStarted":
            self.onSpeechStarted?()

        case "UtteranceEnd":
            self.onSpeechEnded?()

        case "Error":
            isConnected = false
            onError?(extractErrorMessage(from: json) ?? "Deepgram transcription failed")

        default:
            if type.lowercased().contains("error") {
                isConnected = false
                onError?(extractErrorMessage(from: json) ?? "Deepgram transcription failed")
            }
        }
    }

    private func extractErrorMessage(from payload: [String: Any]) -> String? {
        if let error = payload["error"] as? [String: Any] {
            return extractErrorMessage(from: error)
        }

        if let message = payload["description"] as? String, !message.isEmpty {
            return message
        }

        if let message = payload["message"] as? String, !message.isEmpty {
            return message
        }

        if let message = payload["err_msg"] as? String, !message.isEmpty {
            return message
        }

        return nil
    }
}
