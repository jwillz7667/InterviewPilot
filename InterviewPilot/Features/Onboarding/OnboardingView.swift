import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showFilePicker = false
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            IATheme.surfaceWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, IATheme.spacing16)

                ScrollView {
                    stepContent
                        .padding(.horizontal, IATheme.spacing20)
                        .padding(.top, IATheme.spacing20)
                        .padding(.bottom, IATheme.spacing24)
                }
                .iaScrollablePage()
            }
        }
        .safeAreaInset(edge: .bottom) {
            footerButtons
                .padding(.horizontal, IATheme.spacing20)
                .padding(.bottom, IATheme.spacing24)
                .background(.ultraThinMaterial)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.handleResumeFile(result: .success(url))
                }
            case .failure(let error):
                viewModel.handleResumeFile(result: .failure(error))
            }
        }
    }

    private var header: some View {
        HStack {
            IABrandLogo(size: 36, showShadow: false, variant: .outlined)

            Spacer()

            StepIndicator(
                currentStep: viewModel.currentStep.rawValue,
                totalSteps: OnboardingViewModel.Step.allCases.count
            )

            Spacer()

            if !viewModel.isLastStep {
                Button("Skip") {
                    viewModel.advance()
                }
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textSecondary)
            } else {
                Color.clear.frame(width: 40)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .setGoal:
            SetGoalView(selectedGoal: $viewModel.selectedGoal)
        case .connectLinkedIn:
            ConnectLinkedInView(linkedInURL: $viewModel.linkedInURL)
        case .uploadResume:
            UploadResumeView(
                resumeText: $viewModel.resumeText,
                resumeDocumentName: $viewModel.resumeDocumentName,
                onFilePick: { showFilePicker = true }
            )
        case .profileReview:
            ProfileReviewView(
                displayName: $viewModel.displayName,
                currentRole: $viewModel.currentRole,
                currentCompany: $viewModel.currentCompany,
                skills: $viewModel.skills,
                newSkillText: $viewModel.newSkillText,
                onAddSkill: { viewModel.addSkill() },
                onRemoveSkill: { viewModel.removeSkill($0) },
                resumeLoaded: !viewModel.resumeText.isEmpty,
                linkedInConnected: !viewModel.linkedInURL.isEmpty
            )
        }
    }

    private var footerButtons: some View {
        VStack(spacing: 12) {
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                if !viewModel.isFirstStep {
                    Button(action: { viewModel.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(IATheme.textPrimary)
                            .frame(width: 52, height: 52)
                            .background(IATheme.surface, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(IATheme.outlineVariant, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                Button(action: handleNext) {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(viewModel.isLastStep ? "Looks Good, Let's Start!" : "Continue")
                            if !viewModel.isLastStep {
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                }
                .buttonStyle(IAPrimaryButtonStyle(isEnabled: viewModel.canAdvance && !viewModel.isLoading))
                .disabled(!viewModel.canAdvance || viewModel.isLoading)
            }
        }
    }

    private func handleNext() {
        if viewModel.isLastStep {
            Task {
                let success = await viewModel.completeOnboarding()
                if success {
                    onComplete()
                }
            }
        } else {
            viewModel.advance()
        }
    }
}

#Preview("Onboarding") {
    OnboardingView {}
}
