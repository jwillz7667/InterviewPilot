import SwiftUI
import UniformTypeIdentifiers

@Observable
final class SessionSetupViewModel {
    var resumeText: String = ""
    var jobDescription: String = ""
    var interviewType: InterviewType = .general
    var responseFormat: ResponseFormat = .hybrid
    var shouldPreGenerate: Bool = true
    var showResumeInput: Bool = false

    var preComputedAnswers: [PreComputedAnswer] = []
    var isPreGenerating: Bool = false
    var preGenProgress: (current: Int, total: Int) = (0, 0)
    var errorMessage: String?

    var hasResume: Bool { !resumeText.isEmpty }
    var hasJobDescription: Bool { !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isReady: Bool { hasResume && hasJobDescription }

    func handleResumeFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let text = ResumeParserService.extractText(from: url) {
                resumeText = text
            }
        case .failure(let error):
            errorMessage = "Failed to load resume: \(error.localizedDescription)"
        }
    }

    func prepareSession() async {
        guard isReady else { return }

        if shouldPreGenerate {
            guard let apiKey = KeychainService.load(key: .openAIAPIKey) else {
                errorMessage = "OpenAI API key not configured"
                return
            }

            isPreGenerating = true
            do {
                let bank = AnswerBankService()
                try await bank.generateAnswerBank(
                    resume: resumeText,
                    jobDescription: jobDescription,
                    interviewType: interviewType,
                    apiKey: apiKey
                ) { [weak self] current, total in
                    self?.preGenProgress = (current, total)
                }
                preComputedAnswers = bank.answers
            } catch {
                errorMessage = "Failed to pre-generate answers: \(error.localizedDescription)"
            }
            isPreGenerating = false
        }
    }

    func createLiveViewModel() -> LiveSessionViewModel {
        let deepgramKey = KeychainService.load(key: .deepgramAPIKey) ?? ""
        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""

        return LiveSessionViewModel(
            resume: resumeText,
            jobDescription: jobDescription,
            interviewType: interviewType,
            responseFormat: responseFormat,
            preComputedAnswers: preComputedAnswers,
            deepgramKey: deepgramKey,
            openAIKey: openAIKey
        )
    }
}
