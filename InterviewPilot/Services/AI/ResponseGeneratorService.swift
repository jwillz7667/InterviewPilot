import Foundation
import Observation

/// Routing slot — tells the backend which model variant to use within the
/// session's locked-in `InterviewQuality`. The backend's `MODEL_BY_QUALITY`
/// table is the source of truth; client cannot bypass it by editing IPA.
enum ChatRouting: String {
    case `default`
    case technical
    case coding

    init(for questionType: QuestionType?) {
        switch questionType {
        case .coding:
            self = .coding
        case .technical, .systemDesign:
            self = .technical
        default:
            self = .default
        }
    }
}

@Observable
final class ResponseGeneratorService {
    private var currentTask: Task<Void, Never>?
    private(set) var isGenerating = false

    @ObservationIgnored var onTokenReceived: ((String) -> Void)?
    @ObservationIgnored var onResponseComplete: ((String) -> Void)?
    @ObservationIgnored var onError: ((String) -> Void)?

    private let aiClient: AIClient
    private static let maxRetries = 3

    init(aiClient: AIClient = .shared) {
        self.aiClient = aiClient
    }

    /// No-op: connection pre-warming is handled by the backend SSE proxy.
    func preWarmConnection() {}

    /// Fast path: uses a pre-built base prompt and appends per-question context.
    /// `sessionClientId` ties this generation to the SessionAccessGrant minted at
    /// quota-claim time — the backend reads `quality` off the grant and never
    /// trusts a client-supplied model.
    func generateResponse(
        sessionClientId: UUID,
        question: String,
        cachedBasePrompt: String,
        questionType: QuestionType?,
        format: ResponseFormat,
        emphasis: ResponseEmphasis,
        exchangeHistory: [PromptBuilder.ExchangeSummary] = [],
        qualityMode: ResponseQualityMode,
        tone: ResponseTone
    ) {
        let systemPrompt = PromptBuilder.buildFullPrompt(
            basePrompt: cachedBasePrompt,
            questionType: questionType,
            format: format,
            emphasis: emphasis,
            exchangeHistory: exchangeHistory
        )
        dispatchGeneration(
            sessionClientId: sessionClientId,
            question: question,
            systemPrompt: systemPrompt,
            routing: ChatRouting(for: questionType),
            tone: tone
        )
    }

    /// Legacy path: builds the full prompt from scratch each time.
    func generateResponse(
        sessionClientId: UUID,
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
        qualityMode: ResponseQualityMode
    ) {
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
            qualityMode: qualityMode,
            includeResume: qualityMode != .free
        )
        dispatchGeneration(
            sessionClientId: sessionClientId,
            question: question,
            systemPrompt: systemPrompt,
            routing: ChatRouting(for: questionType),
            tone: tone
        )
    }

    private func dispatchGeneration(
        sessionClientId: UUID,
        question: String,
        systemPrompt: String,
        routing: ChatRouting,
        tone: ResponseTone
    ) {
        currentTask?.cancel()

        currentTask = Task { [weak self] in
            guard let self else { return }

            self.isGenerating = true
            CrashReportingService.breadcrumb(category: "openai", message: "request.start", data: ["routing": routing.rawValue])
            // Server is authoritative on model + token cap. Client supplies
            // `sessionClientId` (binds to a SessionAccessGrant) and `routing`
            // (default/technical/coding). Temperature + penalties are still
            // permitted client overrides per the chatStreamSchema.
            let messageBody: [String: Any] = [
                "sessionClientId": sessionClientId.uuidString,
                "routing": routing.rawValue,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "Interview question: \"\(question)\"\n\nGenerate the next answer the candidate should say out loud."]
                ],
                "temperature": tone.temperature,
                "frequency_penalty": APIConfig.responseFrequencyPenalty,
                "presence_penalty": APIConfig.responsePresencePenalty,
                "stream_options": ["include_usage": false],
            ]

            var lastError: String?

            for attempt in 0..<Self.maxRetries {
                if Task.isCancelled {
                    self.isGenerating = false
                    return
                }

                if attempt > 0 {
                    let delay = 1.5 * Double(attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled {
                        self.isGenerating = false
                        return
                    }
                }

                do {
                    let streamedResponse = try await self.streamResponse(body: messageBody)

                    if Task.isCancelled {
                        self.isGenerating = false
                        return
                    }

                    if !streamedResponse.isEmpty {
                        CrashReportingService.breadcrumb(category: "openai", message: "response.complete", data: ["chars": streamedResponse.count])
                        self.onResponseComplete?(streamedResponse)
                        self.isGenerating = false
                        return
                    }

                    lastError = "Response was empty"
                    continue

                } catch let error as NSError {
                    if Task.isCancelled {
                        self.isGenerating = false
                        return
                    }

                    let statusCode = error.code
                    lastError = error.localizedDescription

                    if Self.isNonRetryable(statusCode: statusCode) {
                        CrashReportingService.breadcrumb(category: "openai", message: "response.failed", level: .error, data: ["status": statusCode, "error": error.localizedDescription])
                        self.onError?(error.localizedDescription)
                        self.isGenerating = false
                        return
                    }

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

    func tearDown() {}

    /// Returns true for HTTP status codes that should NOT be retried.
    private static func isNonRetryable(statusCode: Int) -> Bool {
        switch statusCode {
        // 402 = quota exhausted (no retry will help)
        // 422 = Zod validation error (request shape is wrong; retry is futile)
        case 400, 401, 402, 403, 404, 422:
            return true
        default:
            // Network errors (negative), rate limits (429), server errors (5xx) are retryable
            return false
        }
    }

    private func parseAPIError(from body: String) -> (message: String?, statusCode: Int?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (body.isEmpty ? nil : String(body.prefix(200)), nil)
        }

        // Backend sends `{ message, error?, requiredFeature?, requiredTier? }`.
        if let message = json["message"] as? String, !message.isEmpty {
            return (message, nil)
        }

        // Fall through to OpenAI-style nested error shape (defensive — should
        // not occur via our proxy but we keep parsing robust).
        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String
            let code = error["code"] as? String
            let isAuthError = code == "invalid_api_key" || code == "insufficient_quota"
            return (message, isAuthError ? 401 : nil)
        }

        return (body.isEmpty ? nil : String(body.prefix(200)), nil)
    }

    private func streamResponse(body: [String: Any]) async throws -> String {
        let (bytes, httpResponse) = try await aiClient.chatStream(body: body)

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
