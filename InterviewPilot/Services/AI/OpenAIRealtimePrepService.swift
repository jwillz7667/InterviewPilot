import Foundation

@MainActor
final class OpenAIRealtimePrepService {
    private struct SessionConfiguration {
        let resume: String
        let jobDescription: String
        let interviewType: InterviewType
    }

    private let apiKey: String

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingConfiguration: SessionConfiguration?

    private var hasSentSessionUpdate = false
    private var hasStartedInterview = false
    private var assistantTranscript = ""
    private var userTranscriptByItemID: [String: String] = [:]

    private(set) var isConnected = false

    var onReady: (() -> Void)?
    var onAssistantResponseStarted: (() -> Void)?
    var onAssistantAudioStarted: (() -> Void)?
    var onAssistantAudioChunk: ((Data) -> Void)?
    var onAssistantAudioFinished: (() -> Void)?
    var onAssistantTranscriptUpdated: ((String) -> Void)?
    var onAssistantTranscriptCompleted: ((String) -> Void)?
    var onUserSpeechStarted: (() -> Void)?
    var onUserSpeechStopped: (() -> Void)?
    var onUserTranscriptUpdated: ((String) -> Void)?
    var onUserTranscriptCompleted: ((String) -> Void)?
    var onError: ((String) -> Void)?

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func connect(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType
    ) async throws {
        guard !apiKey.isEmpty else {
            throw NSError(
                domain: "OpenAIRealtimePrepService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"]
            )
        }

        pendingConfiguration = SessionConfiguration(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType
        )
        hasSentSessionUpdate = false
        hasStartedInterview = false
        assistantTranscript = ""
        userTranscriptByItemID = [:]

        let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(APIConfig.realtimePrepModel)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let session = URLSession(configuration: .default)
        let socket = session.webSocketTask(with: request)

        urlSession = session
        webSocket = socket
        isConnected = true

        socket.resume()

        Task { [weak self] in
            await self?.receiveMessages()
        }
    }

    func disconnect() {
        let socket = webSocket
        let session = urlSession

        Task { @MainActor [weak self] in
            socket?.cancel(with: .normalClosure, reason: nil)
            session?.invalidateAndCancel()

            self?.webSocket = nil
            self?.urlSession = nil
            self?.isConnected = false
            self?.assistantTranscript = ""
            self?.userTranscriptByItemID = [:]
            self?.hasSentSessionUpdate = false
            self?.hasStartedInterview = false
        }
    }

    func sendAudio(_ data: Data) {
        guard isConnected, !data.isEmpty else { return }

        let payload: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString()
        ]

        Task {
            try? await sendEvent(payload)
        }
    }

    func requestNextQuestion() {
        Task {
            try? await sendEvent(["type": "response.cancel"])
            try? await sendEvent([
                "type": "response.create",
                "response": [
                    "output_modalities": ["audio"],
                    "instructions": """
                    Move to the next likely interview question for this role.
                    Ask one concise question only.
                    Do not give feedback or commentary unless the candidate explicitly asked for it.
                    """
                ]
            ])
        }
    }

    private func receiveMessages() async {
        guard let socket = webSocket else { return }

        do {
            while isConnected {
                let message = try await socket.receive()
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
            isConnected = false
            onError?(error.localizedDescription)
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "session.created":
            guard !hasSentSessionUpdate else { return }
            hasSentSessionUpdate = true
            Task {
                try? await sendSessionUpdate()
            }

        case "session.updated":
            onReady?()
            guard !hasStartedInterview else { return }
            hasStartedInterview = true
            Task {
                try? await requestInitialQuestion()
            }

        case "response.created":
            assistantTranscript = ""
            onAssistantResponseStarted?()

        case "response.output_audio.delta", "response.audio.delta":
            guard let encoded = json["delta"] as? String,
                  let audioData = Data(base64Encoded: encoded) else { return }
            onAssistantAudioStarted?()
            onAssistantAudioChunk?(audioData)

        case "response.output_audio.done", "response.audio.done":
            onAssistantAudioFinished?()

        case "response.output_audio_transcript.delta", "response.audio_transcript.delta":
            guard let delta = json["delta"] as? String else { return }
            assistantTranscript += delta
            onAssistantTranscriptUpdated?(assistantTranscript.trimmingCharacters(in: .whitespacesAndNewlines))

        case "response.output_audio_transcript.done", "response.audio_transcript.done":
            let transcript = (json["transcript"] as? String ?? assistantTranscript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            assistantTranscript = transcript
            onAssistantTranscriptCompleted?(transcript)

        case "input_audio_buffer.speech_started":
            onUserSpeechStarted?()

        case "input_audio_buffer.speech_stopped":
            onUserSpeechStopped?()

        case "conversation.item.input_audio_transcription.delta":
            guard let itemID = json["item_id"] as? String,
                  let delta = json["delta"] as? String else { return }
            let existing = userTranscriptByItemID[itemID] ?? ""
            let updated = existing + delta
            userTranscriptByItemID[itemID] = updated
            onUserTranscriptUpdated?(updated.trimmingCharacters(in: .whitespacesAndNewlines))

        case "conversation.item.input_audio_transcription.completed":
            guard let itemID = json["item_id"] as? String else { return }
            let transcript = (
                json["transcript"] as? String
                ?? userTranscriptByItemID[itemID]
                ?? ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            userTranscriptByItemID.removeValue(forKey: itemID)
            onUserTranscriptCompleted?(transcript)

        case "error":
            let message = extractErrorMessage(from: json) ?? "Realtime API request failed"
            onError?(message)

        default:
            if type.contains("error") {
                let message = extractErrorMessage(from: json) ?? "Realtime API request failed"
                onError?(message)
            }
        }
    }

    private func sendSessionUpdate() async throws {
        guard let configuration = pendingConfiguration else { return }

        let payload: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "instructions": PromptBuilder.buildVoicePrepPrompt(
                    resume: configuration.resume,
                    jobDescription: configuration.jobDescription,
                    interviewType: configuration.interviewType
                ),
                "output_modalities": ["audio"],
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": APIConfig.realtimePrepSampleRate
                        ],
                        "noise_reduction": [
                            "type": "near_field"
                        ],
                        "transcription": [
                            "model": APIConfig.realtimePrepTranscriptionModel,
                            "language": "en"
                        ],
                        "turn_detection": [
                            "type": "semantic_vad",
                            "create_response": true,
                            "interrupt_response": false
                        ]
                    ],
                    "output": [
                        "format": [
                            "type": "audio/pcm"
                        ],
                        "voice": APIConfig.realtimePrepVoice
                    ]
                ]
            ]
        ]

        try await sendEvent(payload)
    }

    private func requestInitialQuestion() async throws {
        let payload: [String: Any] = [
            "type": "response.create",
            "response": [
                "output_modalities": ["audio"],
                "instructions": """
                Start the mock interview now.
                Give a brief greeting and ask the first likely interview question.
                Keep the full spoken turn concise.
                """
            ]
        ]

        try await sendEvent(payload)
    }

    private func sendEvent(_ payload: [String: Any]) async throws {
        guard let socket = webSocket else { return }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(decoding: data, as: UTF8.self)
        try await socket.send(.string(text))
    }

    private func extractErrorMessage(from json: [String: Any]) -> String? {
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }

        return json["message"] as? String
    }
}
