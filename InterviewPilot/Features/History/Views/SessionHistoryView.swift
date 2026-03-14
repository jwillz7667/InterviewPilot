import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @State private var viewModel = SessionHistoryViewModel()
    @Namespace private var reviewTransition
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            IPAppBackground()

            if viewModel.sessions.isEmpty {
                VStack {
                    Spacer()
                    IPEmptyState(
                        title: "No sessions yet",
                        subtitle: "Run a live interview session and your recap will appear here with duration, latency, and question breakdowns.",
                        symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    )
                    .padding(.horizontal, IPTheme.spacing20)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: IPTheme.spacing20) {
                        IPPanel(tone: .secondary) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Session history")
                                    .font(IPTypography.headlineLarge)
                                    .foregroundStyle(IPTheme.textPrimary)

                                Text("Open any session to review response latency, question mix, and generated answers.")
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.textSecondary)
                            }
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.sessions) { session in
                                NavigationLink {
                                    SessionReviewView(
                                        viewModel: SessionReviewViewModel(
                                            exchanges: session.exchanges,
                                            transcript: [],
                                            duration: session.duration,
                                            interviewType: InterviewType(rawValue: session.interviewType) ?? .general
                                        )
                                    )
                                    .navigationTransition(.zoom(sourceID: session.id, in: reviewTransition))
                                } label: {
                                    sessionCard(session)
                                }
                                .matchedTransitionSource(id: session.id, in: reviewTransition)
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteSession(session)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
        }
        .onAppear {
            viewModel.configure(with: modelContext)
        }
    }

    private func sessionCard(_ session: InterviewSession) -> some View {
        IPPanel(tone: .primary) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(IPTheme.accent.opacity(0.12))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: sessionIcon(for: session))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(IPTheme.accentForeground)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(InterviewType(rawValue: session.interviewType)?.displayName ?? "Interview")
                            .font(IPTypography.headlineSmall)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text(viewModel.formatDate(session.startedAt))
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IPTheme.textTertiary)
                }

                HStack(spacing: 10) {
                    statPill(viewModel.formatDuration(session.duration), symbol: "clock.fill")
                    statPill("\(session.exchanges.count) prompts", symbol: "questionmark.bubble.fill")
                    statPill("\(session.totalTokensUsed) tokens", symbol: "sparkles")
                }

                if session.estimatedCost > 0 {
                    Text(String(format: "Estimated cost $%.2f", session.estimatedCost))
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }
        }
    }

    private func statPill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(IPTypography.labelSmall)
            .foregroundStyle(IPTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.10), in: Capsule())
    }

    private func sessionIcon(for session: InterviewSession) -> String {
        switch InterviewType(rawValue: session.interviewType) ?? .general {
        case .behavioral: return "person.2.fill"
        case .technical: return "terminal.fill"
        case .systemDesign: return "server.rack"
        case .caseStudy: return "doc.text.magnifyingglass"
        case .hrScreen: return "person.text.rectangle.fill"
        case .general: return "waveform.and.mic"
        }
    }
}
