import SwiftUI
import UniformTypeIdentifiers

@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case setGoal = 1
        case connectLinkedIn = 2
        case uploadResume = 3
    }

    var currentStep: Step = .setGoal
    var selectedGoal: UserGoal?
    var linkedInURL = ""
    var resumeText = ""
    var resumeDocumentName: String?
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private let profileService = ProfileService.shared

    var canAdvance: Bool {
        switch currentStep {
        case .setGoal:
            return selectedGoal != nil
        case .connectLinkedIn, .uploadResume:
            return true
        }
    }

    var isFirstStep: Bool {
        currentStep == .setGoal
    }

    var isLastStep: Bool {
        currentStep == .uploadResume
    }

    func advance() {
        guard let nextRaw = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextRaw
    }

    func goBack() {
        guard let prevRaw = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevRaw
    }

    func handleResumeFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            resumeDocumentName = url.lastPathComponent
            if let data = try? Data(contentsOf: url),
               let text = ResumeParserService.extractText(from: data) {
                resumeText = text
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func completeOnboarding() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let updates = ProfileUpdate(
                linkedinUrl: linkedInURL.isEmpty ? nil : linkedInURL,
                primaryGoal: selectedGoal?.rawValue,
                resumeText: resumeText.isEmpty ? nil : resumeText,
                onboardingCompleted: true
            )
            try await profileService.updateProfile(updates)
        } catch {
            // Server save failed — still complete locally
        }

        return true
    }
}
