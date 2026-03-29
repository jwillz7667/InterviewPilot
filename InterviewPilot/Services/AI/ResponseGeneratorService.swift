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

                // Streaming returned empty — retry once after a short delay
                try await Task.sleep(for: .seconds(1.5))

                if Task.isCancelled {
                    self.isGenerating = false
                    return
                }

                let retryResponse = try await self.streamResponse(
                    url: url,
                    body: messageBody
                )

                if Task.isCancelled {
                    self.isGenerating = false
                    return
                }

                guard !retryResponse.isEmpty else {
                    self.onError?("Response was empty after retry — check your OpenAI API key and model access")
                    self.isGenerating = false
                    return
                }

                self.onResponseComplete?(retryResponse)
                self.isGenerating = false

            } catch {
                if !Task.isCancelled {
                    self.onError?(error.localizedDescription)
                    self.isGenerating = false
                }
            }
        }
    }

    func cancelGeneration() {
        currentTask?.cancel()
        isGenerating = false
    }

    private func parseAPIError(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return body.isEmpty ? nil : String(body.prefix(200))
        }
        return message
    }

    private func streamResponse(url: URL, body: [String: Any]) async throws -> String {
        var payload = body
        payload["stream"] = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

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

            throw NSError(
                domain: "ResponseGeneratorService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: parseAPIError(from: errorBody) ?? "HTTP \(httpResponse.statusCode)"
                ]
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
