import SwiftData
import SwiftUI

struct SessionHistoryView: View {
    @State private var viewModel: SessionHistoryViewModel
    @Namespace private var reviewTransition
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private let loadOnTask: Bool

    init(viewModel: SessionHistoryViewModel = SessionHistoryViewModel(), loadOnTask: Bool = true) {
        _viewModel = State(initialValue: viewModel)
        self.loadOnTask = loadOnTask
    }

    var body: some View {
        ZStack {
            IAAppBackground()

            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        topUtilityBar
                        historyHeader
                        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(IATheme.accent)

                                Text("Loading session history...")
                                    .font(IATypography.bodyMedium)
                                    .foregroundStyle(IATheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            } else if viewModel.sessions.isEmpty {
                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        topUtilityBar
                        historyHeader
                        IAEmptyState(
                            title: "No sessions yet",
                            subtitle: "Run a live interview or voice prep session and your report will appear here with duration, latency, and exchange details.",
                            symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                        )
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: IATheme.spacing20) {
                        topUtilityBar
                        historyHeader
                        historySummaryPanel

                        if let error = viewModel.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.sessions) { session in
                                NavigationLink {
                                    SessionReviewLoaderView(item: session)
                                        .navigationTransition(.zoom(sourceID: session.id, in: reviewTransition))
                                } label: {
                                    sessionCard(session)
                                }
                                .matchedTransitionSource(id: session.id, in: reviewTransition)
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteSession(session)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
                .refreshable {
                    await viewModel.loadSessions()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard loadOnTask else { return }
            viewModel.configure(with: modelContext)
            await viewModel.loadSessions()
        }
    }

    private var topUtilityBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                IABrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Ace AI")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("History")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            if !viewModel.sessions.isEmpty {
                summaryPill("\(viewModel.sessions.count) sessions", symbol: "clock.arrow.circlepath")
            }
        }
    }

    private var historyHeader: some View {
        IAPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Interview History")
                    .font(IATypography.displayMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                Text("Review previous interviews, reopen reports, and compare speed and question coverage from one timeline.")
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var historySummaryPanel: some View {
        IAPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            HStack(spacing: 12) {
                historySummaryTile(
                    title: "Latest",
                    value: viewModel.formatDate(viewModel.sessions.first?.startedAt ?? .now),
                    symbol: "calendar"
                )
                historySummaryTile(
                    title: "Total Sessions",
                    value: "\(viewModel.sessions.count)",
                    symbol: "waveform.and.mic"
                )
                historySummaryTile(
                    title: "Reports",
                    value: "Ready",
                    symbol: "chart.xyaxis.line"
                )
            }
        }
    }

    private func sessionCard(_ session: SessionHistoryItem) -> some View {
        IAPanel(tone: .secondary, padding: 18, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(IATheme.accent.opacity(0.10))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: sessionIcon(for: session))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(IATheme.accent)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.displayTitle)
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        HStack(spacing: 8) {
                            interviewTypeChip(session.reviewInterviewType)

                            if session.sessionMode == .voicePrep {
                                practiceModeBadge
                            }

                            Text(viewModel.formatDate(session.startedAt))
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(IATheme.textTertiary)

                        if let score = session.overallScore {
                            scoreBadge(score)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    historyMetricTile(viewModel.formatDuration(session.duration), symbol: "clock.fill")
                    historyMetricTile("\(session.exchangeCount) prompts", symbol: "questionmark.bubble.fill")
                    historyMetricTile("\(session.totalTokensUsed) tokens", symbol: "sparkles")
                }

                if let summary = session.effectiveTelemetrySummary {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("First token \(viewModel.formatLatency(summary.averageLiveTimeToFirstTokenMs ?? summary.averageTimeToFirstTokenMs ?? summary.averageTotalLatencyMs)) avg")
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)

                        Text("\(Int(summary.cacheHitRate.rounded()))% cache hit rate")
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }

                if session.estimatedCost > 0 {
                    Text(String(format: "Estimated cost $%.2f", session.estimatedCost))
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }

                NavigationLink {
                    PracticeInterviewLaunchView(from: session)
                } label: {
                    Label("Practice Again", systemImage: "person.wave.2.fill")
                        .font(IATypography.labelMedium)
                        .foregroundStyle(IATheme.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(IATheme.tertiary.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var practiceModeBadge: some View {
        Text("Practice")
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(IATheme.tertiary.opacity(0.12), in: Capsule())
    }

    private func interviewTypeChip(_ type: InterviewType) -> some View {
        Text(type.displayName)
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(IATheme.accent.opacity(0.10), in: Capsule())
    }

    private func scoreBadge(_ score: Int) -> some View {
        let color = scoreColor(for: score)
        return Text("\(score)/100")
            .font(IATypography.labelSmall)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func scoreColor(for score: Int) -> Color {
        if score >= 80 { return IATheme.success }
        if score >= 60 { return IATheme.accent }
        return IATheme.warning
    }

    private func historySummaryTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(IATheme.accent)

            Text(title)
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textSecondary)

            Text(value)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .iaInsetSurface(cornerRadius: 22)
    }

    private func historyMetricTile(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(IATheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
            }
    }

    private func summaryPill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(IATheme.accent.opacity(0.10), in: Capsule())
    }

    private func metricPill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(IATheme.surfaceSecondary, in: Capsule())
    }

    private func sessionIcon(for session: SessionHistoryItem) -> String {
        switch session.reviewInterviewType {
        case .behavioral:
            return "person.2.fill"
        case .technical:
            return "terminal.fill"
        case .systemDesign:
            return "server.rack"
        case .caseStudy:
            return "doc.text.magnifyingglass"
        case .hrScreen:
            return "person.text.rectangle.fill"
        case .general:
            return "waveform.and.mic"
        }
    }
}

#Preview("History Empty") {
    NavigationStack {
        SessionHistoryView(viewModel: previewHistoryViewModel(populated: false), loadOnTask: false)
    }
}

#Preview("History Loading") {
    NavigationStack {
        SessionHistoryView(viewModel: previewHistoryLoadingViewModel(), loadOnTask: false)
    }
}

#Preview("History Error") {
    NavigationStack {
        SessionHistoryView(viewModel: previewHistoryErrorViewModel(), loadOnTask: false)
    }
}

#Preview("History Populated") {
    NavigationStack {
        SessionHistoryView(viewModel: previewHistoryViewModel(populated: true), loadOnTask: false)
    }
}

private func previewHistoryViewModel(populated: Bool) -> SessionHistoryViewModel {
    let viewModel = SessionHistoryViewModel()
    if populated {
        viewModel.sessions = [
            SessionHistoryItem(
                id: UUID().uuidString,
                serverId: nil,
                clientId: UUID(),
                source: .local,
                sessionMode: .liveInterview,
                startedAt: .now.addingTimeInterval(-3600),
                endedAt: .now.addingTimeInterval(-3300),
                interviewType: InterviewType.behavioral.rawValue,
                responseFormat: ResponseFormat.hybrid.rawValue,
                modelUsed: "gpt-5",
                totalTokensUsed: 1430,
                estimatedCost: 1.82,
                exchangeCount: 6,
                exchanges: [
                    Exchange(question: "Tell me about a challenge.", response: "Sample response", type: .behavioral, latencyMs: 780, cached: false),
                ],
                telemetrySummary: nil,
                jobDescription: "ROLE TITLE: Senior iOS Engineer\nJOB CATEGORY: Software Engineering\nSTRUCTURED JOB REQUIREMENTS:\nCompany: Stripe\nLevel: Senior",
                overallScore: 78,
                jobListingUrl: nil,
                profileId: nil
            ),
        ]
    }
    return viewModel
}

private func previewHistoryLoadingViewModel() -> SessionHistoryViewModel {
    let viewModel = SessionHistoryViewModel()
    viewModel.isLoading = true
    return viewModel
}

private func previewHistoryErrorViewModel() -> SessionHistoryViewModel {
    let viewModel = previewHistoryViewModel(populated: true)
    viewModel.errorMessage = "Sync failed, showing local sessions only."
    return viewModel
}
