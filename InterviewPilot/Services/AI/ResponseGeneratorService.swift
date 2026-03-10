import Foundation

@Observable
final class ResponseGeneratorService {
    private var currentTask: Task<Void, Never>?
    private(set) var isGenerating = false

    var onTokenReceived: ((String) -> Void)?
    var onResponseComplete: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateResponse(
        question: String,
        resume: String,
        jobDescription: String,
        interviewType: String,
        format: ResponseFormat,
        model: String = APIConfig.defaultResponseModel
    ) {
        currentTask?.cancel()

        let systemPrompt = PromptBuilder.buildResponsePrompt(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            format: format
        )

        currentTask = Task { [weak self] in
            guard let self else { return }

            self.isGenerating = true

            var fullResponse = ""

            do {
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "model": model,
                    "stream": true,
                    "max_tokens": APIConfig.maxResponseTokens,
                    "temperature": APIConfig.responseTemperature,
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": "Interview question: \"\(question)\"\n\nGenerate the ideal response."]
                    ]
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.onError?("No HTTP response received")
                    self.isGenerating = false
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    // Collect the error response body
                    var errorBody = ""
                    for try await line in bytes.lines {
                        errorBody += line
                    }
                    let errorMessage = self.parseAPIError(from: errorBody)
                        ?? "HTTP \(httpResponse.statusCode)"
                    self.onError?(errorMessage)
                    self.isGenerating = false
                    return
                }

                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    guard line.hasPrefix("data: "),
                          line != "data: [DONE]" else { continue }

                    let jsonString = String(line.dropFirst(6))
                    guard let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let delta = choices.first?["delta"] as? [String: Any],
                          let content = delta["content"] as? String else { continue }

                    fullResponse += content
                    self.onTokenReceived?(content)
                }

                self.onResponseComplete?(fullResponse)
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
}
