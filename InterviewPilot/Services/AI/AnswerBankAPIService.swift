import Foundation

struct PreparedAnswerBank: Sendable {
    let id: String
    let name: String
    let fromCache: Bool
    let answers: [PreComputedAnswer]
}

final class AnswerBankAPIService {
    static let shared = AnswerBankAPIService()

    private let apiClient: AuthenticatedAPIClient

    init(apiClient: AuthenticatedAPIClient = .shared) {
        self.apiClient = apiClient
    }

    func generateOrReuseAnswerBank(
        name: String? = nil,
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        qualityMode: ResponseQualityMode
    ) async throws -> PreparedAnswerBank {
        let response: GenerateAnswerBankEnvelope = try await apiClient.post(
            "/api/v1/answer-banks/generate",
            body: GenerateAnswerBankRequest(
                name: name,
                resumeText: resume,
                jobDescription: jobDescription,
                interviewType: interviewType.rawValue,
                responseQualityMode: qualityMode.rawValue
            ),
            expectedStatusCodes: [200, 201]
        )

        return PreparedAnswerBank(
            id: response.bank.id,
            name: response.bank.name,
            fromCache: response.fromCache,
            answers: response.bank.answers.map { answer in
                PreComputedAnswer(
                    question: answer.question,
                    response: answer.response,
                    type: QuestionType(rawValue: answer.questionType) ?? .unknown
                )
            }
        )
    }
}

private struct GenerateAnswerBankRequest: Encodable {
    let name: String?
    let resumeText: String
    let jobDescription: String
    let interviewType: String
    let responseQualityMode: String
}

private struct GenerateAnswerBankEnvelope: Decodable {
    let bank: RemoteAnswerBank
    let fromCache: Bool
}

private struct RemoteAnswerBank: Decodable {
    let id: String
    let name: String
    let answers: [RemotePreparedAnswer]
}

private struct RemotePreparedAnswer: Decodable {
    let question: String
    let response: String
    let questionType: String
}
