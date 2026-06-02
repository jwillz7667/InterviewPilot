import Foundation

enum DeepgramConnectError: LocalizedError {
    case handshakeTimedOut
    case handshakeFailed(status: Int?, body: String?, underlying: Error)
    case socketUnavailable

    var errorDescription: String? {
        switch self {
        case .handshakeTimedOut:
            return "Transcription service did not respond within 10 seconds. Check your network and try again."
        case .handshakeFailed(let status, let body, let underlying):
            // Surface the actual HTTP status (and short body excerpt) so operators
            // can distinguish 401 (key) from 403 (scope/credits) from 400 (params)
            // instead of the opaque "bad response from server" URLError default.
            var parts: [String] = []
            if let status {
                parts.append("HTTP \(status) \(DeepgramConnectError.diagnose(status: status))")
            }
            if let body, !body.isEmpty {
                parts.append(body)
            }
            if parts.isEmpty {
                parts.append(underlying.localizedDescription)
            }
            return "Transcription handshake failed: \(parts.joined(separator: " — "))"
        case .socketUnavailable:
            return "Transcription socket was not available."
        }
    }

    private static func diagnose(status: Int) -> String {
        switch status {
        case 400: return "Invalid streaming parameters (model/encoding/sample rate)."
        case 401: return "Deepgram rejected the credential. The minted key is invalid."
        case 402: return "Deepgram account is out of credits or has no active streaming plan."
        case 403: return "Key is missing usage:write or the project lacks streaming permission."
        case 404: return "Streaming endpoint not found for this model. Check model name."
        case 429: return "Deepgram rate-limited the connection. Retry shortly."
        case 500...599: return "Deepgram upstream error."
        default: return ""
        }
    }
}

/// Deepgram Nova-3 live transcription over a raw WSS socket.
///
/// Connection confirmation is done on the WebSocket **upgrade** (HTTP 101),
/// delivered via `URLSessionWebSocketDelegate.didOpenWithProtocol`. Deepgram's
/// streaming endpoint stays completely silent until it receives audio — it does
/// NOT emit any metadata/handshake message on connect — so blocking on a first
/// message (as an OpenAI-Realtime-style handshake would) deadlocks until the
/// timeout and kills the session before audio ever starts. We therefore confirm
/// on the open event and treat a non-101 completion as the failure path, which
/// also carries the real HTTP status for diagnostics.
final class DeepgramService: NSObject {
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var isConnected = false
    private(set) var isReconnecting = false

    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onSpeechStarted: (() -> Void)?
    var onSpeechEnded: (() -> Void)?
    var onError: ((String) -> Void)?
    var onReconnected: (() -> Void)?

    private let aiClient: AIClient
    private var lastConnectKeywords: [String] = []
    private var reconnectAttempts = 0
    private var intentionalDisconnect = false
    private var keepAliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    // Handshake confirmation plumbing — resolved by the URLSession delegate.
    private var handshakeContinuation: CheckedContinuation<Void, Error>?
    private var handshakeTimeoutTask: Task<Void, Never>?

    private static let maxReconnectAttempts = 5
    private static let keepAliveIntervalSeconds: UInt64 = 8
    private static let handshakeTimeoutSeconds: UInt64 = 10

    init(aiClient: AIClient = .shared) {
        self.aiClient = aiClient
        super.init()
    }

    deinit {
        // Guarantee teardown even if the owner is dropped without disconnect():
        // URLSession retains its delegate (self) and keeps the socket + receive
        // loop alive until invalidated. Only Sendable members are touched here so
        // this is safe from the nonisolated deinit; invalidateAndCancel also
        // cancels the underlying WebSocket task.
        keepAliveTask?.cancel()
        reconnectTask?.cancel()
        handshakeTimeoutTask?.cancel()
        urlSession?.invalidateAndCancel()
    }

    func connect(keywords: [String] = []) async throws {
        intentionalDisconnect = false
        reconnectAttempts = 0
        lastConnectKeywords = keywords
        try await connectInternal(keywords: keywords)
    }

    private func connectInternal(keywords: [String], forceKeyRefresh: Bool = false) async throws {
        // Clean up previous connection
        cleanupConnection()

        // On reconnect, mint a fresh key: if the drop was caused by a revoked or
        // expired ephemeral key, reusing the cached one fails identically on
        // every attempt until the reconnect budget is exhausted.
        let apiKey = try await aiClient.currentDeepgramKey(forceRefresh: forceKeyRefresh)

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
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.urlSession = session
        self.webSocket = session.webSocketTask(with: request)
        self.webSocket?.resume()

        // Confirm the WSS upgrade (HTTP 101) via the delegate open event. If
        // Deepgram refuses the socket (auth, scope, account state, bad params)
        // the upgrade is rejected with a non-101 status, surfaced through
        // didCompleteWithError with the real HTTP status. Setting isConnected
        // before the upgrade would let audio be sent into a dead socket.
        do {
            try await waitForHandshake()
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
        // Unblock any in-flight handshake so a connect() awaiting confirmation
        // doesn't hang past teardown.
        resolveHandshake(.failure(DeepgramConnectError.socketUnavailable))
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

    // MARK: - Handshake confirmation

    /// Suspends until the WebSocket upgrade is confirmed (delegate open event),
    /// the upgrade is rejected (delegate completion with a status), or the
    /// timeout elapses. Resolved exactly once via `resolveHandshake`.
    private func waitForHandshake() async throws {
        handshakeTimeoutTask?.cancel()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.handshakeContinuation = continuation
            self.handshakeTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.handshakeTimeoutSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.resolveHandshake(.failure(DeepgramConnectError.handshakeTimedOut))
            }
        }
    }

    private func resolveHandshake(_ result: Result<Void, Error>) {
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        guard let continuation = handshakeContinuation else { return }
        handshakeContinuation = nil
        continuation.resume(with: result)
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
                try await self.connectInternal(keywords: keywords, forceKeyRefresh: true)
                self.reconnectAttempts = 0
                self.isReconnecting = false
                self.onReconnected?()
            } catch {
                self.attemptReconnect(reason: error.localizedDescription)
            }
        }
    }

    private func cleanupConnection() {
        // Resolve any pending handshake before tearing the socket down so a
        // suspended waitForHandshake() never leaks its continuation.
        resolveHandshake(.failure(DeepgramConnectError.socketUnavailable))
        keepAliveTask?.cancel()
        keepAliveTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
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

// MARK: - URLSessionWebSocketDelegate

extension DeepgramService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor [weak self] in
            self?.resolveHandshake(.success(()))
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // On a rejected upgrade, URLSession stores the HTTPURLResponse on the
        // task — surface the real status (401/402/403/...) instead of an opaque
        // URLError. Only meaningful while the handshake is still pending; after a
        // successful open this fires on normal/dropped close and is handled by
        // the receiveMessages() loop, so we no-op when nothing is awaiting.
        let status = (task.response as? HTTPURLResponse)?.statusCode
        Task { @MainActor [weak self] in
            guard let self, self.handshakeContinuation != nil else { return }
            self.resolveHandshake(.failure(DeepgramConnectError.handshakeFailed(
                status: status,
                body: nil,
                underlying: error ?? URLError(.badServerResponse)
            )))
        }
    }
}
