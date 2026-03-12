import SwiftUI

struct PrepSessionView: View {
    @State var viewModel: PrepSessionViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            IPAppBackground()

            VStack(spacing: 12) {
                topBar
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.top, IPTheme.spacing12)

                interviewerSection
                    .frame(maxHeight: .infinity)

                answerSection
                    .frame(maxHeight: .infinity)
            }
            .padding(.bottom, 96)
        }
        .safeAreaInset(edge: .bottom) {
            controlBar
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

    private var topBar: some View {
        IPPanel(tone: .secondary, padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusXL) {
            HStack(spacing: 12) {
                Button(action: { showEndConfirmation = true }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IPTheme.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                AnimatedStatusBadge(text: "Voice Prep", color: IPTheme.accent, isActive: true)
                IPStatusPill(title: viewModel.statusText, symbol: prepStateSymbol, tint: IPTheme.accent)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(viewModel.elapsedTime))
                        .font(IPTypography.timer)
                        .foregroundStyle(IPTheme.textPrimary)
                    Text("\(viewModel.questionCount) questions")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }
        }
    }

    private var interviewerSection: some View {
        IPPanel(tone: .primary) {
            VStack(alignment: .leading, spacing: 14) {
                laneHeader(
                    title: "AI interviewer",
                    subtitle: "Realtime spoken question",
                    symbol: "person.wave.2.fill",
                    tint: IPTheme.accent,
                    trailing: AnyView(IPStatusPill(title: viewModel.statusText, symbol: prepStateSymbol, tint: IPTheme.accent))
                )

                ScrollView {
                    Text(viewModel.currentQuestion.isEmpty
                         ? "The AI interviewer will greet you and ask the first question."
                         : viewModel.currentQuestion)
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(viewModel.currentQuestion.isEmpty ? IPTheme.textSecondary : IPTheme.textPrimary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .ipScrollablePage()

                if viewModel.audioCapture.isCapturing &&
                    (viewModel.sessionState == .listening || viewModel.sessionState == .userSpeaking) {
                    WaveformView(level: viewModel.audioCapture.audioLevel)
                        .frame(height: 34)
                }
            }
        }
        .padding(.horizontal, IPTheme.spacing16)
        .padding(.top, 4)
    }

    private var answerSection: some View {
        IPPanel(tone: .secondary) {
            VStack(alignment: .leading, spacing: 14) {
                laneHeader(
                    title: "Your spoken answer",
                    subtitle: viewModel.currentAnswerDraft.isEmpty ? "Waiting for your response" : "Live transcription",
                    symbol: "mic.fill",
                    tint: IPTheme.accent,
                    trailing: AnyView(IPStatusPill(title: viewModel.interviewType.displayName, symbol: "target", tint: IPTheme.accent))
                )

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                ScrollView {
                    Text(answerText)
                        .font(IPTypography.responseText)
                        .foregroundStyle(answerTextIsPlaceholder ? IPTheme.textSecondary : IPTheme.textPrimary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .ipScrollablePage()
            }
        }
        .padding(.horizontal, IPTheme.spacing16)
    }

    private var controlBar: some View {
        IPPanel(tone: .secondary, padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusXL) {
            HStack(spacing: 18) {
                ControlButton(
                    icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
                    label: viewModel.audioCapture.isCapturing ? "Mute" : "Unmute",
                    isActive: viewModel.audioCapture.isCapturing,
                    tint: IPTheme.accent
                ) {
                    viewModel.toggleMicrophone()
                }

                Spacer()

                Button(action: { showEndConfirmation = true }) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(IPTheme.error.gradient, in: Circle())
                        .shadow(color: IPTheme.error.opacity(0.24), radius: 16, y: 10)
                }
                .buttonStyle(.plain)

                Spacer()

                ControlButton(
                    icon: "forward.fill",
                    label: "Next",
                    isActive: true,
                    tint: IPTheme.accent
                ) {
                    viewModel.requestNextQuestion()
                }
            }
        }
    }

    private func laneHeader(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        trailing: AnyView
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textPrimary)
                Text(subtitle)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }

            Spacer()
            trailing
        }
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
        case .idle: return "pause.circle"
        case .connecting: return "link.circle"
        case .aiSpeaking: return "waveform"
        case .listening: return "ear"
        case .userSpeaking: return "mic.fill"
        case .thinking: return "sparkles"
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
