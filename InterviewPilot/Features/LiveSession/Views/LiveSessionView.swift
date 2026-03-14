import SwiftUI

struct LiveSessionView: View {
    @State var viewModel: LiveSessionViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            IPAppBackground()

            VStack(spacing: 12) {
                topBar
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.top, IPTheme.spacing12)

                transcriptSection
                    .frame(minHeight: 210, maxHeight: 260)

                responseSection
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
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                viewModel.stopSession()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the live interview session.")
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

                AnimatedStatusBadge(text: "Live", color: IPTheme.live, isActive: true)
                IPStatusPill(title: liveStateTitle, symbol: liveStateSymbol, tint: IPTheme.accentForeground)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(viewModel.elapsedTime))
                        .font(IPTypography.timer)
                        .foregroundStyle(IPTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("Interview mode")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }
        }
    }

    private var transcriptSection: some View {
        IPPanel(tone: .secondary) {
            VStack(alignment: .leading, spacing: 14) {
                laneHeader(
                    title: "Interviewer",
                    subtitle: "Live transcript",
                    symbol: "waveform.and.mic",
                    tint: IPTheme.accentForeground,
                    trailing: viewModel.sessionState == .interviewerSpeaking
                        ? AnyView(AnimatedStatusBadge(text: "Listening", color: IPTheme.accent, isActive: true))
                        : AnyView(IPStatusPill(title: "On standby", symbol: "ear", tint: IPTheme.textSecondary))
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(viewModel.interviewerTranscript.isEmpty ? "Place the phone so the interviewer is closest to the mic. The live transcript will build here." : viewModel.interviewerTranscript)
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(viewModel.interviewerTranscript.isEmpty ? IPTheme.textSecondary : IPTheme.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("transcript-bottom")
                    }
                    .ipScrollablePage()
                    .onChange(of: viewModel.interviewerTranscript) {
                        withAnimation(IPAnimations.gentle) {
                            proxy.scrollTo("transcript-bottom", anchor: .bottom)
                        }
                    }
                }

                if viewModel.audioCapture.isCapturing && viewModel.sessionState != .generating {
                    WaveformView(level: viewModel.audioCapture.audioLevel)
                        .frame(height: 34)
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.sessionState == .responseReady || viewModel.sessionState == .postResponseSpeech {
                    Text("Your answer stays pinned while you speak. The app only promotes new interviewer audio when it sees a real question signal.")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, IPTheme.spacing16)
        .padding(.top, 4)
    }

    private var responseSection: some View {
        IPPanel(tone: .primary) {
            VStack(alignment: .leading, spacing: 14) {
                laneHeader(
                    title: "Suggested answer",
                    subtitle: viewModel.isResponseFromCache ? "Instant answer bank hit" : "Generated response",
                    symbol: viewModel.isResponseFromCache ? "bolt.fill" : "sparkles",
                    tint: viewModel.isResponseFromCache ? IPTheme.accentWarm : IPTheme.accent,
                    trailing: AnyView(
                        HStack(spacing: 8) {
                            if let questionType = viewModel.questionType {
                                QuestionTypeBadge(classification: questionType)
                            }

                            if viewModel.responseGenerator.isGenerating {
                                ProgressView()
                                    .tint(IPTheme.accentForeground)
                            }
                        }
                    )
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
                    if viewModel.currentResponse.isEmpty && viewModel.sessionState != .generating {
                        Text("The response will appear here when the app has enough of the question to answer.")
                            .font(IPTypography.responseText)
                            .foregroundStyle(IPTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if viewModel.currentResponse.isEmpty && viewModel.sessionState == .generating {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.14))
                                    .frame(height: 16)
                                    .frame(maxWidth: index == 2 ? 220 : .infinity)
                                    .shimmer()
                            }
                        }
                    } else {
                        Text(viewModel.currentResponse)
                            .font(IPTypography.responseText)
                            .foregroundStyle(IPTheme.textPrimary)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .defaultScrollAnchor(.top)
                .id(viewModel.exchangeCount)
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
                    label: micButtonLabel,
                    isActive: viewModel.audioCapture.isCapturing,
                    tint: IPTheme.accent
                ) {
                    if viewModel.audioCapture.isCapturing {
                        viewModel.audioCapture.stopCapture()
                    } else {
                        try? viewModel.audioCapture.startCapture()
                    }
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
                    withAnimation(IPAnimations.standard) {
                        viewModel.resumeListeningForNextQuestion()
                    }
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

    private var micButtonLabel: String {
        viewModel.audioCapture.isCapturing ? "Mute" : "Unmute"
    }

    private var liveStateTitle: String {
        switch viewModel.sessionState {
        case .idle: return "Idle"
        case .listening: return "Ready"
        case .interviewerSpeaking: return "Hearing question"
        case .generating: return "Drafting"
        case .responseReady: return "Answer locked"
        case .postResponseSpeech: return "Waiting for next cue"
        }
    }

    private var liveStateSymbol: String {
        switch viewModel.sessionState {
        case .idle: return "pause.circle"
        case .listening: return "ear"
        case .interviewerSpeaking: return "waveform"
        case .generating: return "sparkles"
        case .responseReady: return "checkmark.circle.fill"
        case .postResponseSpeech: return "person.fill.wave.2"
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var tint: Color = IPTheme.accentForeground
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            isPressed.toggle()
            action()
        }) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isActive ? IPTheme.controlFill(for: colorScheme, isActive: true) : IPTheme.controlFill(for: colorScheme, isActive: false))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(IPTheme.controlForeground(for: colorScheme, isActive: isActive))
                            .symbolEffect(.bounce, value: isPressed)
                    }

                Text(label)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
    }
}
