import SwiftUI
import UniformTypeIdentifiers

@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case setGoal = 1
        case connectLinkedIn = 2
        case uploadResume = 3
        case profileReview = 4
    }

    var currentStep: Step = .setGoal
    var selectedGoal: UserGoal?
    var linkedInURL = ""
    var resumeText = ""
    var resumeDocumentName: String?
    var displayName = ""
    var currentRole = ""
    var currentCompany = ""
    var skills: [SkillEntry] = []
    var newSkillText = ""
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private let profileService = ProfileService.shared

    var canAdvance: Bool {
        switch currentStep {
        case .setGoal:
            return selectedGoal != nil
        case .connectLinkedIn:
            return true
        case .uploadResume:
            return true
        case .profileReview:
            return true
        }
    }

    var isFirstStep: Bool {
        currentStep == .setGoal
    }

    var isLastStep: Bool {
        currentStep == .profileReview
    }

    func advance() {
        guard let nextRaw = Step(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(IAAnimations.standard) {
            currentStep = nextRaw
        }
    }

    func goBack() {
        guard let prevRaw = Step(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(IAAnimations.standard) {
            currentStep = prevRaw
        }
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

    func addSkill() {
        let trimmed = newSkillText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !skills.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            newSkillText = ""
            return
        }
        skills.append(SkillEntry(name: trimmed))
        newSkillText = ""
    }

    func removeSkill(_ skill: SkillEntry) {
        skills.removeAll { $0.id == skill.id }
    }

    func completeOnboarding() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        // Best-effort server save — always complete locally so onboarding
        // is never shown again, even if the network request fails.
        do {
            let updates = ProfileUpdate(
                displayName: displayName.isEmpty ? nil : displayName,
                linkedinUrl: linkedInURL.isEmpty ? nil : linkedInURL,
                primaryGoal: selectedGoal?.rawValue,
                resumeText: resumeText.isEmpty ? nil : resumeText,
                currentRole: currentRole.isEmpty ? nil : currentRole,
                currentCompany: currentCompany.isEmpty ? nil : currentCompany,
                onboardingCompleted: true
            )
            try await profileService.updateProfile(updates)

            if !skills.isEmpty {
                try await profileService.updateSkills(skills)
            }
        } catch {
            // Server save failed — still mark onboarding complete locally.
            // Profile data will sync on next successful server call.
        }

        return true
    }
}
