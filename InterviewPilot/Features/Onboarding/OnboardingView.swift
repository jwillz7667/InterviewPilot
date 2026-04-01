import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showFilePicker = false
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, IATheme.spacing20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.top)

            footerButtons
                .padding(.horizontal, IATheme.spacing20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
        }
        .background(IATheme.surfaceWhite.ignoresSafeArea())
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
                            Text(viewModel.isLastStep ? "Get Started" : "Continue")
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
