import SwiftUI

struct SessionReviewView: View {
    @State var viewModel: SessionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        topUtilityBar
                        reportHeader
                        insightSection
                        PerformanceView(exchanges: viewModel.exchanges, summary: viewModel.telemetrySummary)

                        if !viewModel.questionTypeBreakdown.isEmpty {
                            questionTypeSection
                        }

                        exchangesSection
                            .id("exchanges-anchor")

                        actionPanel(proxy: proxy)
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                    .padding(.bottom, 40)
                }
                .ipScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var topUtilityBar: some View {
        HStack {
            HStack(spacing: 12) {
                IPBrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Job Hopper")
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Session Report")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(IPSecondaryButtonStyle())
        }
    }

    private var reportHeader: some View {
        IPPanel(tone: .secondary, padding: 24, cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Session Report")
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("Review support quality, response speed, and the key exchanges from the live interview.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    IPScoreRing(
                        progress: performanceProgress,
                        title: "Support\nScore",
                        value: performanceGrade,
                        size: 146
                    )
                    Spacer()
                }

                HStack(spacing: 12) {
                    statCard(title: "Duration", value: viewModel.formattedDuration)
                    statCard(title: "Questions", value: "\(viewModel.exchanges.count)")
                    statCard(title: "First Token", value: viewModel.averageFirstTokenLatency.map { "\($0)ms" } ?? "n/a")
                }
            }
        }
    }

    private func actionPanel(proxy: ScrollViewProxy) -> some View {
        IPPanel(tone: .secondary, padding: 18, cornerRadius: 28) {
            HStack(spacing: 10) {
                Button("Back to History") {
                    dismiss()
                }
                .buttonStyle(IPSecondaryButtonStyle())

                Button("Jump to Exchanges") {
                    withAnimation(IPAnimations.standard) {
                        proxy.scrollTo("exchanges-anchor", anchor: .top)
                    }
                }
                .buttonStyle(IPPrimaryButtonStyle())
            }
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            IPPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Strengths")
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.textPrimary)

                    ForEach(strengths, id: \.self) { item in
                        bulletRow(item, tint: IPTheme.success)
                    }
                }
            }

            IPPanel(tone: .primary, padding: 18, cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Improvements")
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.textPrimary)

                    ForEach(improvements, id: \.self) { item in
                        bulletRow(item, tint: IPTheme.accent)
                    }
                }
            }
        }
    }

    private var questionTypeSection: some View {
        IPPanel(tone: .primary, padding: 20, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Question mix")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                FlowLayout(spacing: 10) {
                    ForEach(viewModel.questionTypeBreakdown, id: \.0) { type, count in
                        HStack(spacing: 8) {
                            Text(type.displayName)
                            Text("\(count)")
                        }
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.questionTypeColor(type))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(IPTheme.questionTypeColor(type).opacity(0.10), in: Capsule())
                    }
                }
            }
        }
    }

    private var exchangesSection: some View {
        IPPanel(tone: .primary, padding: 20, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Exchange timeline")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                ForEach(Array(viewModel.exchanges.enumerated()), id: \.element.id) { index, exchange in
                    VStack(spacing: 10) {
                        IPTimelineRow(
                            time: exchange.timestamp.formatted(date: .omitted, time: .shortened),
                            title: "Prompt \(index + 1)",
                            detail: exchange.questionTranscript
                        )
                        ExchangeDetailView(exchange: exchange)
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IPTypography.labelSmall)
                .foregroundStyle(IPTheme.textSecondary)

            Text(value)
                .font(IPTypography.headlineSmall)
                .foregroundStyle(IPTheme.textPrimary)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .ipInsetSurface(cornerRadius: 22)
    }

    private func bulletRow(_ text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            Text(text)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textSecondary)
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

    private var strengths: [String] {
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

    private var improvements: [String] {
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
