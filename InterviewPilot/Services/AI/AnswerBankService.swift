import Foundation

enum APIError: LocalizedError {
    case httpError(statusCode: Int, message: String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let message):
            switch code {
            case 401: return "Invalid API key. Check your OpenAI key in Settings."
            case 429: return "Rate limit exceeded. Wait a moment and try again."
            case 400: return "Bad request: \(message)"
            case 500...599: return "OpenAI server error (\(code)). Try again later."
            default: return "API error \(code): \(message)"
            }
        case .invalidResponse(let detail):
            return "Failed to parse response: \(detail)"
        }
    }
}

@Observable
final class AnswerBankService {
    private(set) var answers: [PreComputedAnswer]
    private(set) var isGenerating = false

    init(answers: [PreComputedAnswer] = []) {
        self.answers = answers
    }

    func findMatch(query: String, threshold: Float) -> PreComputedAnswer? {
        var bestMatch: PreComputedAnswer?
        var bestScore: Float = 0

        for answer in answers {
            if let queryEmbedding = answer.embedding {
                _ = queryEmbedding
            }

            let score = SimilarityMatchService.wordOverlapSimilarity(query, answer.question)
            if score > bestScore && score >= threshold {
                bestScore = score
                bestMatch = answer
            }
        }

        return bestMatch
    }

    func generateAnswerBank(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        qualityMode: ResponseQualityMode,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws {
        isGenerating = true
        defer { isGenerating = false }

        let prompt = PromptBuilder.buildPreGenerationPrompt(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            qualityMode: qualityMode
        )

        let body: [String: Any] = [
            "model": APIConfig.prepModel,
            "max_tokens": 4000,
            "temperature": APIConfig.answerBankTemperature,
            "frequency_penalty": APIConfig.responseFrequencyPenalty,
            "messages": [
                ["role": "system", "content": "You are an expert engineering interview coach who writes candidate-ready answers that sound specific, credible, and natural out loud."],
                ["role": "user", "content": prompt]
            ]
        ]

        let json: [String: Any]
        do {
            json = try await AIClient.shared.chat(body: body)
        } catch let error as AIClientError {
            switch error {
            case .server(let statusCode, let message):
                throw APIError.httpError(statusCode: statusCode, message: message)
            default:
                throw APIError.invalidResponse(error.localizedDescription)
            }
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw APIError.invalidResponse("Could not parse choices from chat response")
        }

        let parsed = parseQAPairs(from: content)
        self.answers = parsed

        onProgress(parsed.count, parsed.count)
    }

    private func parseQAPairs(from content: String) -> [PreComputedAnswer] {
        var jsonString = content
        if let startRange = content.range(of: "["),
           let endRange = content.range(of: "]", options: .backwards) {
            jsonString = String(content[startRange.lowerBound...endRange.upperBound])
        }

        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return array.compactMap { item in
            guard let question = item["question"] as? String,
                  let answer = item["answer"] as? String else { return nil }

            let typeString = (item["type"] as? String) ?? "unknown"
            let type = QuestionType(rawValue: typeString) ?? .unknown

            return PreComputedAnswer(question: question, response: answer, type: type)
        }
    }
}
