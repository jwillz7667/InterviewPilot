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
                    .id(viewModel.currentStep)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.top)
            .scrollDismissesKeyboard(.immediately)

            footerButtons
                .padding(.horizontal, IATheme.spacing20)
                .padding(.top, 24)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: IATheme.surfaceWhite.opacity(0), location: 0),
                            .init(color: IATheme.surfaceWhite.opacity(0.85), location: 0.15),
                            .init(color: IATheme.surfaceWhite, location: 0.35),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
        }
        .background(IATheme.surfaceWhite.ignoresSafeArea())
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep == .microphoneAccess {
                viewModel.refreshMicrophoneStatus()
            }
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
                Text("Skip")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
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
        case .microphoneAccess:
            MicrophonePermissionView(
                status: $viewModel.microphoneStatus,
                onRequest: {
                    Task { await viewModel.requestMicrophonePermission() }
                }
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
