import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @State private var viewModel = SessionHistoryViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color(IPTheme.backgroundTop).ignoresSafeArea()

            if viewModel.sessions.isEmpty {
                VStack(spacing: IPTheme.spacing16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.2))

                    Text("No Sessions Yet")
                        .font(IPTypography.headlineMedium)
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Complete an interview session to see it here")
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.3))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: IPTheme.spacing12) {
                        ForEach(viewModel.sessions) { session in
                            sessionCard(session)
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.vertical, IPTheme.spacing12)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.configure(with: modelContext)
        }
    }

    private func sessionCard(_ session: InterviewSession) -> some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(InterviewType(rawValue: session.interviewType)?.displayName ?? "Interview")
                        .font(IPTypography.bodyLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(viewModel.formatDate(session.startedAt))
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.formatDuration(session.duration))
                        .font(IPTypography.timer)
                        .foregroundStyle(.white.opacity(0.6))

                    Text("\(session.exchanges.count) Q&As")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            HStack(spacing: IPTheme.spacing8) {
                Label("\(session.totalTokensUsed) tokens", systemImage: "cpu")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.3))

                Spacer()

                if session.estimatedCost > 0 {
                    Text(String(format: "$%.2f", session.estimatedCost))
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusLarge))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteSession(session)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
