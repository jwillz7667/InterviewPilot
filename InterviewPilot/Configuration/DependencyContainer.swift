import Foundation

enum DependencyContainer {
    static func createLiveSessionViewModel(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        responseFormat: ResponseFormat,
        responseBehavior: ResponseBehavior = .analytical,
        responseTone: ResponseTone = .natural,
        responseEmphasis: ResponseEmphasis = .technicalDepth,
        responseQualityMode: ResponseQualityMode = .standard,
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
            responseBehavior: responseBehavior,
            responseTone: responseTone,
            responseEmphasis: responseEmphasis,
            responseQualityMode: responseQualityMode,
            preComputedAnswers: preComputedAnswers,
            deepgramKey: deepgramKey,
            openAIKey: openAIKey
        )
    }
}
