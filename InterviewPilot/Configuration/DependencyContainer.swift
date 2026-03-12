import Foundation

enum DependencyContainer {
    static func createLiveSessionViewModel(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        responseFormat: ResponseFormat,
        preComputedAnswers: [PreComputedAnswer]
    ) -> LiveSessionViewModel {
        let deepgramKey = KeychainService.load(key: .deepgramAPIKey) ?? ""
        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""

        return LiveSessionViewModel(
            sessionId: UUID(),
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            responseFormat: responseFormat,
            preComputedAnswers: preComputedAnswers,
            deepgramKey: deepgramKey,
            openAIKey: openAIKey
        )
    }
}
