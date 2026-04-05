import SwiftUI

struct SessionReviewView: View {
    @State var viewModel: SessionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        topUtilityBar
                        reportHeader
                        aiAnalysisSection
                        PerformanceView(exchanges: viewModel.exchanges, summary: viewModel.telemetrySummary)

                        if !viewModel.questionTypeBreakdown.isEmpty {
                            questionTypeSection
                        }

                        exchangesSection
                            .id("exchanges-anchor")

                        actionPanel(proxy: proxy)
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                    .padding(.bottom, 40)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.serverId == nil {
                    await viewModel.resolveServerIdFromRemote()
                }
                if viewModel.serverId != nil, !viewModel.hasAnalysis {
                    await viewModel.fetchAnalysis()
                }
            }
        }
    }

    private var topUtilityBar: some View {
        HStack {
            HStack(spacing: 12) {
                IABrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Ace AI")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Session Report")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(IASecondaryButtonStyle())
        }
    }

    private var reportHeader: some View {
        IAPanel(tone: .secondary, padding: 24, cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Session Report")
                    .font(IATypography.displayMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("Review support quality, response speed, and the key exchanges from the live interview.")
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    if let analysis = viewModel.analysis {
                        IAScoreRing(
                            progress: Double(analysis.overallScore) / 100.0,
                            title: "Overall\nScore",
                            value: "\(analysis.overallScore)",
                            size: 146
                        )
                    } else {
                        IAScoreRing(
                            progress: performanceProgress,
                            title: "Support\nScore",
                            value: performanceGrade,
                            size: 146
                        )
                    }
                    Spacer()
                }

                if let analysis = viewModel.analysis {
                    HStack(spacing: 12) {
                        statCard(title: "Technical", value: "\(Int(analysis.technicalAccuracyScore))")
                        statCard(title: "Communication", value: "\(Int(analysis.communicationScore))")
                        statCard(title: "Confidence", value: "\(Int(analysis.confidenceScore))")
                    }
                } else {
                    HStack(spacing: 12) {
                        statCard(title: "Duration", value: viewModel.formattedDuration)
                        statCard(title: "Questions", value: "\(viewModel.exchanges.count)")
                        statCard(title: "First Token", value: viewModel.averageFirstTokenLatency.map { "\($0)ms" } ?? "n/a")
                    }
                }
            }
        }
    }

    private func actionPanel(proxy: ScrollViewProxy) -> some View {
        IAPanel(tone: .secondary, padding: 18, cornerRadius: 28) {
            HStack(spacing: 10) {
                Button("Back to History") {
                    dismiss()
                }
                .buttonStyle(IASecondaryButtonStyle())

                Button("Jump to Exchanges") {
                    withAnimation(IAAnimations.standard) {
                        proxy.scrollTo("exchanges-anchor", anchor: .top)
                    }
                }
                .buttonStyle(IAPrimaryButtonStyle())
            }
        }
    }

    private var aiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isAnalyzing {
                IAPanel(tone: .secondary, padding: 22, cornerRadius: 28) {
                    HStack(spacing: 14) {
                        ProgressView()
                            .tint(IATheme.accent)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analyzing interview")
                                .font(IATypography.headlineSmall)
                                .foregroundStyle(IATheme.textPrimary)

                            Text("AI is evaluating your responses for technical accuracy, communication quality, and confidence.")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                    }
                }
            } else if let error = viewModel.analysisError {
                IAPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Analysis unavailable")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        Text(error)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)

                        Button("Retry") {
                            Task { await viewModel.fetchAnalysis() }
                        }
                        .buttonStyle(IASecondaryButtonStyle())
                    }
                }
            } else if let analysis = viewModel.analysis {
                IAPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Strengths")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        ForEach(analysis.aiStrengths, id: \.self) { item in
                            bulletRow(item, tint: IATheme.success)
                        }
                    }
                }

                IAPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Areas to Improve")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        ForEach(analysis.aiImprovements, id: \.self) { item in
                            bulletRow(item, tint: IATheme.warning)
                        }
                    }
                }
            } else {
                IAPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Strengths")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        ForEach(fallbackStrengths, id: \.self) { item in
                            bulletRow(item, tint: IATheme.success)
                        }
                    }
                }

                IAPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Improvements")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        ForEach(fallbackImprovements, id: \.self) { item in
                            bulletRow(item, tint: IATheme.warning)
                        }
                    }
                }
            }
        }
    }

    private var questionTypeSection: some View {
        IAPanel(tone: .primary, padding: 20, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Question mix")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                FlowLayout(spacing: 10) {
                    ForEach(viewModel.questionTypeBreakdown, id: \.0) { type, count in
                        HStack(spacing: 8) {
                            Text(type.displayName)
                            Text("\(count)")
                        }
                        .font(IATypography.labelSmall)
                        .foregroundStyle(IATheme.questionTypeColor(type))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(IATheme.questionTypeColor(type).opacity(0.10), in: Capsule())
                    }
                }
            }
        }
    }

    private var exchangesSection: some View {
        IAPanel(tone: .primary, padding: 20, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Exchange timeline")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                ForEach(Array(viewModel.exchanges.enumerated()), id: \.element.id) { index, exchange in
                    VStack(spacing: 10) {
                        IATimelineRow(
                            time: exchange.timestamp.formatted(date: .omitted, time: .shortened),
                            title: "Prompt \(index + 1)",
                            detail: exchange.questionTranscript
                        )
                        ExchangeDetailView(exchange: exchange, feedback: viewModel.feedbackForExchange(at: index))
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textSecondary)

            Text(value)
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .iaInsetSurface(cornerRadius: 22)
    }

    private func bulletRow(_ text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            Text(text)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var performanceProgress: Double {
        let firstTokenScore: Double = {
            guard let latency = viewModel.averageFirstTokenLatency else { return 0.55 }
            if latency <= 800 { return 0.96 }
            if latency <= 1200 { return 0.84 }
            if latency <= 1700 { return 0.72 }
            return 0.58
        }()

        let cacheScore = min(max(viewModel.cacheHitRate / 100, 0), 1)
        let predictiveScore = min(max(viewModel.predictiveFireRate / 100, 0), 1)
        let mixScore = min(Double(viewModel.questionTypeBreakdown.count) / 4, 1)

        return (firstTokenScore * 0.40) + (cacheScore * 0.20) + (predictiveScore * 0.20) + (mixScore * 0.20)
    }

    private var performanceGrade: String {
        switch performanceProgress {
        case 0.92...:
            return "A"
        case 0.84..<0.92:
            return "A-"
        case 0.76..<0.84:
            return "B+"
        case 0.68..<0.76:
            return "B"
        case 0.58..<0.68:
            return "B-"
        default:
            return "C"
        }
    }

    private var fallbackStrengths: [String] {
        var items: [String] = []

        if let latency = viewModel.averageFirstTokenLatency, latency < 1200 {
            items.append("Fast first-token delivery kept the answer lane responsive.")
        }

        if viewModel.cacheHitRate > 35 {
            items.append("Prepared-answer reuse improved consistency on repeated question patterns.")
        }

        if viewModel.questionTypeBreakdown.count >= 3 {
            items.append("The session covered a broad mix of interview question types.")
        }

        if items.isEmpty {
            items.append("The session report captured the full exchange history cleanly.")
        }

        return items
    }

    private var fallbackImprovements: [String] {
        var items: [String] = []

        if let latency = viewModel.averageFirstTokenLatency, latency >= 1200 {
            items.append("Lower first-token latency so live answers appear sooner during active questioning.")
        }

        if viewModel.cacheHitRate < 25 {
            items.append("Expand prep-bank coverage to increase answer reuse on common prompts.")
        }

        if viewModel.predictiveFireRate < 30 {
            items.append("Improve predictive fire confidence to reduce waiting after long interviewer prompts.")
        }

        if items.isEmpty {
            items.append("No major gaps detected from this session’s telemetry summary.")
        }

        return items
    }
}

#Preview("Session Review") {
    SessionReviewView(
        viewModel: SessionReviewViewModel(
            exchanges: [
                Exchange(question: "Tell me about a difficult team situation.", response: "I aligned the team around shared outcomes and documented the decision path.", type: .behavioral, latencyMs: 780, cached: false),
                Exchange(question: "How would you design offline sync?", response: "I would define conflict policy first, then model durable queues and replay behavior.", type: .systemDesign, latencyMs: 1180, cached: true),
            ],
            transcript: [],
            duration: 980,
            interviewType: .behavioral
        )
    )
}
