import Foundation
import Observation

@Observable
final class DeepgramService {
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var isConnected = false

    @ObservationIgnored var onPartialTranscript: ((String) -> Void)?
    @ObservationIgnored var onFinalTranscript: ((String) -> Void)?
    @ObservationIgnored var onSpeechStarted: (() -> Void)?
    @ObservationIgnored var onSpeechEnded: (() -> Void)?
    @ObservationIgnored var onError: ((String) -> Void)?

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func connect(keywords: [String] = []) async throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "DeepgramService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Deepgram API key not configured"]
            )
        }

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

        let session = URLSession(configuration: .default)
        self.urlSession = session
        self.webSocket = session.webSocketTask(with: request)
        self.webSocket?.resume()
        self.isConnected = true

        Task { await receiveMessages() }
    }

    func sendAudio(_ data: Data) {
        guard isConnected else { return }
        webSocket?.send(.data(data)) { error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.isConnected = false
                    self?.onError?(error.localizedDescription)
                }
            }
        }
    }

    func disconnect() {
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
            let shouldReportError = isConnected
            isConnected = false
            if shouldReportError {
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
