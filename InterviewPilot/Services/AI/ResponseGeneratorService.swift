import Foundation
import Observation

@Observable
final class ResponseGeneratorService {
    private var currentTask: Task<Void, Never>?
    private(set) var isGenerating = false

    @ObservationIgnored var onTokenReceived: ((String) -> Void)?
    @ObservationIgnored var onResponseComplete: ((String) -> Void)?
    @ObservationIgnored var onError: ((String) -> Void)?

    private let apiKey: String
    private static let maxRetries = 3

    /// Dedicated URLSession with long timeouts for streaming during extended interviews.
    @ObservationIgnored private var _streamingSession: URLSession?
    private var streamingSession: URLSession {
        if let session = _streamingSession { return session }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30      // 30s to establish connection
        config.timeoutIntervalForResource = 300    // 5 min max per streaming response
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        let session = URLSession(configuration: config)
        _streamingSession = session
        return session
    }

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateResponse(
        question: String,
        resume: String,
        jobDescription: String,
        interviewType: String,
        jobCategory: JobCategory,
        positionLevel: PositionLevel,
        questionType: QuestionType?,
        format: ResponseFormat,
        behavior: ResponseBehavior,
        tone: ResponseTone,
        emphasis: ResponseEmphasis,
        qualityMode: ResponseQualityMode,
        model: String = APIConfig.defaultResponseModel
    ) {
        currentTask?.cancel()
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onError?("OpenAI API key not configured")
            return
        }

        let systemPrompt = PromptBuilder.buildResponsePrompt(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobCategory: jobCategory,
            positionLevel: positionLevel,
            questionType: questionType,
            format: format,
            behavior: behavior,
            tone: tone,
            emphasis: emphasis,
            qualityMode: qualityMode
        )
        let tokenLimit = qualityMode.liveTokenLimit(
            baseTokens: format.maxTokens(for: emphasis, questionType: questionType)
        )

        currentTask = Task { [weak self] in
            guard let self else { return }

            self.isGenerating = true
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            let isReasoningModel = model.hasPrefix("o1") || model.hasPrefix("o3") || model.hasPrefix("o4")
            var messageBody: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "Interview question: \"\(question)\"\n\nGenerate the next answer the candidate should say out loud."]
                ]
            ]
            if isReasoningModel {
                messageBody["max_completion_tokens"] = tokenLimit
            } else {
                messageBody["max_tokens"] = tokenLimit
                messageBody["temperature"] = tone.temperature
                messageBody["frequency_penalty"] = APIConfig.responseFrequencyPenalty
                messageBody["presence_penalty"] = APIConfig.responsePresencePenalty
            }

            var lastError: String?

            for attempt in 0..<Self.maxRetries {
                if Task.isCancelled {
                    self.isGenerating = false
                    return
                }

                // Exponential backoff on retries: 0s, 1.5s, 3s
                if attempt > 0 {
                    let delay = 1.5 * Double(attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled {
                        self.isGenerating = false
                        return
                    }
                }

                do {
                    let streamedResponse = try await self.streamResponse(
                        url: url,
                        body: messageBody
                    )

                    if Task.isCancelled {
                        self.isGenerating = false
                        return
                    }

                    if !streamedResponse.isEmpty {
                        self.onResponseComplete?(streamedResponse)
                        self.isGenerating = false
                        return
                    }

                    lastError = "Response was empty"
                    // Empty response — retry
                    continue

                } catch let error as NSError {
                    if Task.isCancelled {
                        self.isGenerating = false
                        return
                    }

                    let statusCode = error.code
                    lastError = error.localizedDescription

                    // Non-retryable errors: auth failures, invalid requests
                    if Self.isNonRetryable(statusCode: statusCode) {
                        self.onError?(error.localizedDescription)
                        self.isGenerating = false
                        return
                    }

                    // Retryable: rate limits (429), server errors (500, 502, 503), timeouts, network errors
                    continue
                }
            }

            if !Task.isCancelled {
                self.onError?(lastError ?? "Request failed after \(Self.maxRetries) attempts")
                self.isGenerating = false
            }
        }
    }

    func cancelGeneration() {
        currentTask?.cancel()
        isGenerating = false
    }

    /// Returns true for HTTP status codes that should NOT be retried.
    private static func isNonRetryable(statusCode: Int) -> Bool {
        switch statusCode {
        case 400, 401, 403, 404:
            return true
        default:
            // Network errors (negative), rate limits (429), server errors (5xx) are retryable
            return false
        }
    }

    private func parseAPIError(from body: String) -> (message: String?, statusCode: Int?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return (body.isEmpty ? nil : String(body.prefix(200)), nil)
        }
        let message = error["message"] as? String
        let code = error["code"] as? String
        // Map known error codes
        let isAuthError = code == "invalid_api_key" || code == "insufficient_quota"
        return (message, isAuthError ? 401 : nil)
    }

    private func streamResponse(url: URL, body: [String: Any]) async throws -> String {
        var payload = body
        payload["stream"] = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await streamingSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ResponseGeneratorService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No HTTP response received"]
            )
        }

        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }

            let parsed = parseAPIError(from: errorBody)
            let errorMessage = parsed.message ?? "HTTP \(httpResponse.statusCode)"

            throw NSError(
                domain: "ResponseGeneratorService",
                code: parsed.statusCode ?? httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }

        var fullResponse = ""

        for try await line in bytes.lines {
            if Task.isCancelled { break }

            guard line.hasPrefix("data: "),
                  line != "data: [DONE]" else { continue }

            let jsonString = String(line.dropFirst(6))
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = extractText(from: delta["content"]),
                  !content.isEmpty else { continue }

            fullResponse += content
            onTokenReceived?(content)
        }

        return fullResponse
    }

    private func extractText(from content: Any?) -> String? {
        switch content {
        case let text as String:
            return text
        case let parts as [[String: Any]]:
            let combined = parts.compactMap { part -> String? in
                if let text = part["text"] as? String {
                    return text
                }

                if let text = part["text"] as? [String: Any],
                   let value = text["value"] as? String {
                    return value
                }

                return nil
            }.joined()
            return combined.isEmpty ? nil : combined
        default:
            return nil
        }
    }
}
