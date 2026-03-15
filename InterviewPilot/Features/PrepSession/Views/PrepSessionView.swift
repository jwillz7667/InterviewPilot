import SwiftUI

struct PrepSessionView: View {
    @State var viewModel: PrepSessionViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            IPAppBackground()

            VStack(spacing: 0) {
                headerBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                        questionSection
                        answerSection
                    }
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .ipScrollablePage()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            controlDock
                .padding(.horizontal, IPTheme.spacing16)
                .padding(.bottom, IPTheme.spacing8)
        }
        .onAppear {
            Task { try? await viewModel.startSession() }
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("End Voice Prep?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                viewModel.stopSession()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the mock interview.")
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            IPUtilityCircleButton(symbol: "chevron.left") {
                showEndConfirmation = true
            }

            AnimatedStatusBadge(text: "Voice Prep", color: IPTheme.accent, isActive: true)
            IPStatusPill(title: viewModel.statusText, symbol: prepStateSymbol, tint: IPTheme.accent)

            Spacer()

            IPBrandLogo(size: 40, showShadow: false, variant: .surface)
        }
        .padding(.horizontal, IPTheme.spacing16)
        .padding(.top, 12)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Voice Prep Interview")
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)

                Spacer(minLength: 12)
                IPStarburst(size: 34)
                    .padding(.top, 10)
            }

            HStack(spacing: 10) {
                IPStatusPill(title: "\(viewModel.questionCount) questions", symbol: "text.bubble", tint: IPTheme.accent)
                IPStatusPill(title: formatTime(viewModel.elapsedTime), symbol: "clock", tint: IPTheme.textSecondary)
            }
        }
    }

    private var questionSection: some View {
        VStack(spacing: 12) {
            IPConversationBubble(
                role: .interviewer,
                title: "AI Interviewer",
                text: questionText,
                symbol: "person.wave.2.fill",
                trailingSymbol: "speaker.wave.2"
            )

            if viewModel.audioCapture.isCapturing &&
                (viewModel.sessionState == .listening || viewModel.sessionState == .userSpeaking) {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 34)
                    .padding(.vertical, 6)
            }
        }
    }

    private var answerSection: some View {
        IPPanel(tone: .accent(IPTheme.accent), padding: 18, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(IPTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(IPTheme.accent.opacity(0.10), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Spoken Answer")
                                .font(IPTypography.labelLarge)
                                .foregroundStyle(IPTheme.textPrimary)

                            Text(viewModel.currentAnswerDraft.isEmpty ? "Waiting for your response" : "Live transcription")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.textSecondary)
                        }
                    }

                    Spacer()

                    IPStatusPill(title: viewModel.interviewType.displayName, symbol: "target")
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(answerText)
                    .font(IPTypography.responseText)
                    .foregroundStyle(answerTextIsPlaceholder ? IPTheme.textSecondary : IPTheme.textPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var controlDock: some View {
        IPBottomDock {
            HStack(spacing: 12) {
                ControlButton(
                    icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
                    label: viewModel.audioCapture.isCapturing ? "Mute" : "Unmute",
                    isActive: viewModel.audioCapture.isCapturing,
                    tint: IPTheme.accent
                ) {
                    viewModel.toggleMicrophone()
                }

                ControlButton(
                    icon: "forward.fill",
                    label: "Next",
                    isActive: true,
                    tint: IPTheme.accent
                ) {
                    viewModel.requestNextQuestion()
                }

                Button(action: { showEndConfirmation = true }) {
                    Text("End Interview")
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(IPTheme.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(IPTheme.error.opacity(0.18), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var questionText: String {
        if !viewModel.currentQuestion.isEmpty {
            return viewModel.currentQuestion
        }

        return "The AI interviewer will greet you and ask the first question."
    }

    private var answerText: String {
        if !viewModel.currentAnswerDraft.isEmpty {
            return viewModel.currentAnswerDraft
        }

        if !viewModel.lastAnswer.isEmpty {
            return viewModel.lastAnswer
        }

        return "Your spoken answer will appear here."
    }

    private var answerTextIsPlaceholder: Bool {
        viewModel.currentAnswerDraft.isEmpty && viewModel.lastAnswer.isEmpty
    }

    private var prepStateSymbol: String {
        switch viewModel.sessionState {
        case .idle:
            return "pause.circle"
        case .connecting:
            return "link.circle"
        case .aiSpeaking:
            return "waveform"
        case .listening:
            return "ear"
        case .userSpeaking:
            return "mic.fill"
        case .thinking:
            return "sparkles"
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
