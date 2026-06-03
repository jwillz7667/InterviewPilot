import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit

@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case uploadResume = 1
        case reviewProfile = 2
        case setGoal = 3
        case connectLinkedIn = 4
        case microphoneAccess = 5
    }

    enum AutofillState: Sendable, Equatable {
        case idle
        case readingFile
        case runningOCR
        case extractingProfile
        case completed(ResumeAutofillSummary)
        case failed(String)

        static func == (lhs: AutofillState, rhs: AutofillState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.readingFile, .readingFile),
                 (.runningOCR, .runningOCR), (.extractingProfile, .extractingProfile):
                return true
            case (.completed(let a), .completed(let b)):
                return a == b
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    struct ResumeAutofillSummary: Sendable, Equatable {
        let documentName: String
        let format: ResumeFileFormat
        let usedOCR: Bool
        let filledFields: [ResumeAutofillField]
        let addedSkills: Int
        let addedExperiences: Int
    }

    var currentStep: Step = .setGoal
    var selectedGoal: UserGoal?
    var linkedInURL = ""
    var resumeText = ""
    var resumeDocumentName: String?
    var displayName = ""
    var currentRole = ""
    var currentCompany = ""
    var yearsInRole = 0
    var skills: [SkillEntry] = []
    var workExperiences: [WorkExperienceEntry] = []
    var resumeSummary: String?
    var autofillState: AutofillState = .idle
    var isLoading = false
    var errorMessage: String?
    var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    @ObservationIgnored private let profileService = ProfileService.shared
    @ObservationIgnored private var autofillTask: Task<Void, Never>?

    var canAdvance: Bool {
        switch currentStep {
        case .setGoal:
            return selectedGoal != nil
        case .uploadResume:
            return !isAutofilling
        case .connectLinkedIn, .reviewProfile, .microphoneAccess:
            return true
        }
    }

    var isFirstStep: Bool { currentStep == .uploadResume }
    var isLastStep: Bool { currentStep == .microphoneAccess }

    var isAutofilling: Bool {
        switch autofillState {
        case .readingFile, .runningOCR, .extractingProfile: return true
        default: return false
        }
    }

    func requestMicrophonePermission() async {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        switch current {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = granted ? .authorized : .denied
        case .denied, .restricted:
            await MainActor.run {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .authorized:
            microphoneStatus = .authorized
        @unknown default:
            break
        }
    }

    func refreshMicrophoneStatus() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func advance() {
        guard let nextRaw = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextRaw
    }

    func goBack() {
        guard let prevRaw = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevRaw
    }

    /// Picked file → text extraction → LLM profile extraction → form merge.
    /// Cancellable: a second invocation supersedes any in-flight autofill.
    func handleResumeFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            startAutofill(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
            autofillState = .failed(error.localizedDescription)
        }
    }

    /// User pasted resume text directly. Trigger LLM extraction without the
    /// file-reading phase.
    func runAutofillFromPastedText() {
        let text = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        autofillTask?.cancel()
        autofillState = .extractingProfile
        errorMessage = nil

        let snapshot = currentInput()
        autofillTask = Task { [weak self] in
            guard let self else { return }
            do {
                let output = try await ResumeAutofillService.autofillFromText(
                    text,
                    documentName: self.resumeDocumentName ?? "Pasted resume",
                    existing: snapshot
                )
                await self.applyAutofillOutput(output)
            } catch is CancellationError {
                // Superseded — leave state for the new task to update.
            } catch {
                self.autofillState = .failed(error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func startAutofill(from url: URL) {
        autofillTask?.cancel()
        autofillState = .readingFile
        errorMessage = nil
        resumeDocumentName = url.lastPathComponent

        let snapshot = currentInput()
        autofillTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Extract text first so we can drive the UI through phases.
                let extracted = try await ResumeTextExtractor.extract(from: url)

                if Task.isCancelled { return }

                if extracted.usedOCR {
                    self.autofillState = .runningOCR
                }
                self.resumeText = extracted.text
                self.autofillState = .extractingProfile

                let output = try await ResumeAutofillService.autofillFromText(
                    extracted.text,
                    documentName: url.lastPathComponent,
                    existing: snapshot
                )

                if Task.isCancelled { return }

                await self.applyAutofillOutput(output)
            } catch is CancellationError {
                return
            } catch let failure as ResumeTextExtractor.Failure {
                self.autofillState = .failed(failure.localizedDescription)
                self.errorMessage = failure.localizedDescription
            } catch {
                self.autofillState = .failed(error.localizedDescription)
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func applyAutofillOutput(_ output: ResumeAutofillOutput) async {
        // Capture sizes BEFORE we overwrite the form, so the diagnostic
        // summary reports actual deltas instead of zero.
        let priorSkillCount = skills.count
        let priorExperienceCount = workExperiences.count

        resumeText = output.resumeText
        resumeDocumentName = output.documentName
        displayName = output.displayName
        currentRole = output.currentRole
        currentCompany = output.currentCompany
        yearsInRole = output.yearsInRole
        if !output.linkedInURL.isEmpty {
            linkedInURL = output.linkedInURL
        }
        skills = output.skills
        workExperiences = output.workExperiences
        resumeSummary = output.summary

        let summary = ResumeAutofillSummary(
            documentName: output.documentName,
            format: output.format,
            usedOCR: output.usedOCR,
            filledFields: ResumeAutofillField.allCases.filter { output.filledFields.contains($0) },
            addedSkills: max(0, output.skills.count - priorSkillCount),
            addedExperiences: max(0, output.workExperiences.count - priorExperienceCount)
        )
        autofillState = .completed(summary)
    }

    private func currentInput() -> ResumeAutofillInput {
        ResumeAutofillInput(
            displayName: displayName,
            currentRole: currentRole,
            currentCompany: currentCompany,
            yearsInRole: yearsInRole,
            linkedInURL: linkedInURL,
            skills: skills,
            workExperiences: workExperiences
        )
    }

    func cancelAutofill() {
        autofillTask?.cancel()
        autofillTask = nil
        if isAutofilling { autofillState = .idle }
    }

    func completeOnboarding() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRole = currentRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = currentCompany.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLinkedIn = linkedInURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResume = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)

        let updates = ProfileUpdate(
            displayName: trimmedName.isEmpty ? nil : trimmedName,
            linkedinUrl: trimmedLinkedIn.isEmpty ? nil : trimmedLinkedIn,
            primaryGoal: selectedGoal?.rawValue,
            resumeText: trimmedResume.isEmpty ? nil : trimmedResume,
            currentRole: trimmedRole.isEmpty ? nil : trimmedRole,
            currentCompany: trimmedCompany.isEmpty ? nil : trimmedCompany,
            yearsInRole: yearsInRole > 0 ? yearsInRole : nil,
            onboardingCompleted: true
        )

        // The core profile save is mandatory: if it fails, surface the error and
        // keep the user in onboarding so their answers aren't silently lost.
        do {
            try await profileService.updateProfile(updates)
        } catch {
            errorMessage = "Couldn't save your profile. \(error.localizedDescription)"
            return false
        }

        // Collections are best-effort — a failure here shouldn't block finishing
        // onboarding, but it should be reported so the user knows to re-enter them
        // later from the profile editor.
        var collectionFailed = false
        if !workExperiences.isEmpty {
            do { try await profileService.updateWorkExperience(workExperiences) }
            catch { collectionFailed = true }
        }
        if !skills.isEmpty {
            do { try await profileService.updateSkills(skills) }
            catch { collectionFailed = true }
        }
        if collectionFailed {
            errorMessage = "Your profile was saved, but some details (skills or work history) couldn't sync. You can re-add them from your profile."
        }

        return true
    }
}
