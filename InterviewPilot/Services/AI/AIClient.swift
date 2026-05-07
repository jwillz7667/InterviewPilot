import Foundation

/// Ephemeral OpenAI Realtime session credentials minted by the backend.
/// The `clientSecret` is short-lived (~1 minute) and bound to a single session.
struct RealtimeSession: Codable, Sendable {
    let sessionId: String
    let model: String
    let clientSecret: String
    let expiresAt: Double
}

/// Ephemeral Deepgram credentials minted by the backend. When the backend
/// has `DEEPGRAM_PROJECT_ID` configured, `ephemeral` is true and the key is
/// scope-limited (`usage:write`) with a TTL. Otherwise the master key is
/// returned as a temporary fallback (`ephemeral: false`).
struct TranscriptionSession: Codable, Sendable {
    let apiKey: String
    let expiresAt: Double?
    let ephemeral: Bool
}

enum AIClientError: LocalizedError {
    case invalidURL
    case unauthenticated
    case invalidResponse
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid backend URL."
        case .unauthenticated: return "Please sign in again."
        case .invalidResponse: return "The server returned an invalid response."
        case .server(let code, let message): return "AI request failed (\(code)): \(message)"
        }
    }
}

/// Backend proxy for OpenAI + Deepgram. All AI calls flow through the backend
/// — no master keys are ever held on-device. Realtime and transcription
/// sessions are minted fresh and cached briefly until expiry.
final class AIClient {
    static let shared = AIClient()

    private let authService: AuthService
    private let baseURL: String
    private let session: URLSession

    private var cachedTranscription: TranscriptionSession?
    private var cachedTranscriptionExpiry: Date?
    private let transcriptionLock = NSLock()

    init(
        authService: AuthService = .shared,
        baseURL: String = AppEnvironment.backendBaseURL
    ) {
        self.authService = authService
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)
    }

    /// Streaming variant of /api/v1/ai/chat/stream. Returns the byte stream
    /// and the underlying response so the caller can verify status before
    /// consuming the SSE events.
    func chatStream(body: [String: Any]) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let url = try requireURL(path: "/api/v1/ai/chat/stream")
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw AIClientError.unauthenticated
        }
        return (bytes, httpResponse)
    }

    /// Non-streaming variant of /api/v1/ai/chat. Returns parsed JSON.
    func chat(body: [String: Any]) async throws -> [String: Any] {
        let url = try requireURL(path: "/api/v1/ai/chat")
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw AIClientError.unauthenticated
        }
        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data) ?? "Request failed"
            throw AIClientError.server(statusCode: httpResponse.statusCode, message: message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIClientError.invalidResponse
        }
        return json
    }

    /// Mints a fresh ephemeral OpenAI Realtime session. Call once per WSS connect;
    /// the returned `clientSecret` is single-session and short-lived.
    func createRealtimeSession(
        instructions: String,
        voice: String,
        model: String? = nil,
        inputAudioFormat: String = "pcm16",
        outputAudioFormat: String = "pcm16",
        transcription: (model: String, language: String)? = nil,
        turnDetection: (threshold: Double, prefixPaddingMs: Int, silenceDurationMs: Int)? = nil
    ) async throws -> RealtimeSession {
        var body: [String: Any] = [
            "instructions": instructions,
            "voice": voice,
            "inputAudioFormat": inputAudioFormat,
            "outputAudioFormat": outputAudioFormat,
        ]
        if let model { body["model"] = model }
        if let transcription {
            body["inputAudioTranscription"] = [
                "model": transcription.model,
                "language": transcription.language,
            ]
        }
        if let turnDetection {
            body["turnDetection"] = [
                "type": "server_vad",
                "threshold": turnDetection.threshold,
                "prefixPaddingMs": turnDetection.prefixPaddingMs,
                "silenceDurationMs": turnDetection.silenceDurationMs,
            ]
        }

        let url = try requireURL(path: "/api/v1/ai/realtime/session")
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw AIClientError.unauthenticated
        }
        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data) ?? "Failed to create realtime session"
            throw AIClientError.server(statusCode: httpResponse.statusCode, message: message)
        }
        return try JSONDecoder().decode(RealtimeSession.self, from: data)
    }

    /// Returns a Deepgram API key suitable for direct WSS to api.deepgram.com.
    /// Caches per-process until 60s before expiry. Pass `forceRefresh: true`
    /// after a 401/403 to mint a new key.
    func currentDeepgramKey(ttlSeconds: Int = 900, forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let cached = cachedTokenIfFresh() {
            return cached.apiKey
        }

        let body: [String: Any] = ["ttlSeconds": ttlSeconds]
        let url = try requireURL(path: "/api/v1/ai/transcription/session")
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw AIClientError.unauthenticated
        }
        guard httpResponse.statusCode == 200 else {
            let message = parseErrorMessage(from: data) ?? "Failed to mint transcription key"
            throw AIClientError.server(statusCode: httpResponse.statusCode, message: message)
        }

        let session = try JSONDecoder().decode(TranscriptionSession.self, from: data)
        storeTranscriptionSession(session)
        return session.apiKey
    }

    func clearCaches() {
        transcriptionLock.lock()
        cachedTranscription = nil
        cachedTranscriptionExpiry = nil
        transcriptionLock.unlock()
    }

    // MARK: - Internals

    private func cachedTokenIfFresh() -> TranscriptionSession? {
        transcriptionLock.lock()
        defer { transcriptionLock.unlock() }
        guard let session = cachedTranscription, let expiry = cachedTranscriptionExpiry else {
            return nil
        }
        // Refresh 60s before expiry.
        if Date().addingTimeInterval(60) >= expiry {
            cachedTranscription = nil
            cachedTranscriptionExpiry = nil
            return nil
        }
        return session
    }

    private func storeTranscriptionSession(_ session: TranscriptionSession) {
        transcriptionLock.lock()
        cachedTranscription = session
        // If backend returned no expiry (master-key fallback), cache for 5 minutes.
        if let expiresAt = session.expiresAt {
            cachedTranscriptionExpiry = Date(timeIntervalSince1970: expiresAt)
        } else {
            cachedTranscriptionExpiry = Date().addingTimeInterval(300)
        }
        transcriptionLock.unlock()
    }

    private func requireURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AIClientError.invalidURL
        }
        return url
    }

    private func authenticatedRequest(url: URL) async throws -> URLRequest {
        guard let request = await authService.authenticatedRequest(url: url) else {
            throw AIClientError.unauthenticated
        }
        return request
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let error = json["error"] as? String, !error.isEmpty {
            return error
        }
        return nil
    }
}
