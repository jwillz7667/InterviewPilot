import Foundation

enum DependencyContainer {
    static func createLiveSessionViewModel(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobCategory: JobCategory = .generalBusiness,
        positionLevel: PositionLevel = .midLevel,
        responseFormat: ResponseFormat,
        responseBehavior: ResponseBehavior = .analytical,
        responseTone: ResponseTone = .natural,
        responseEmphasis: ResponseEmphasis = .technicalDepth,
        responseQualityMode: ResponseQualityMode = .standard,
        preComputedAnswers: [PreComputedAnswer]
    ) -> LiveSessionViewModel {
        return LiveSessionViewModel(
            sessionId: UUID(),
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobCategory: jobCategory,
            positionLevel: positionLevel,
            responseFormat: responseFormat,
            responseBehavior: responseBehavior,
            responseTone: responseTone,
            responseEmphasis: responseEmphasis,
            responseQualityMode: responseQualityMode,
            preComputedAnswers: preComputedAnswers,
            modelConfig: SubscriptionService.shared.currentEntitlement?.modelConfig
        )
    }
}
