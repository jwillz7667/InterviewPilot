import SwiftUI
import SwiftData

struct InterviewInsightsView: View {
    @State private var viewModel = InsightsViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            IAAppBackground()

            ScrollView {
                VStack(spacing: IATheme.spacing20) {
                    headerSection

                    if viewModel.hasData {
                        heroScoreCard
                        keyMetricsSection
                        aiInsightsSection
                        recommendedPracticeSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, IATheme.spacing20)
                .padding(.top, IATheme.spacing16)
                .padding(.bottom, 100)
            }
            .iaScrollablePage()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.loadData(modelContext: modelContext)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(IATheme.accent)

                Text("Interview Insights")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)
            }

            Spacer()
        }
    }

    // MARK: - Hero Score Card

    private var heroScoreCard: some View {
        GradientHeroCard(cornerRadius: IATheme.radiusLarge) {
            VStack(spacing: 16) {
                Text(viewModel.performanceLabel)
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(.white)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: Double(viewModel.insights.overallScore ?? 0) / 100.0)
                        .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text(viewModel.overallScoreLabel)
                            .font(IATypography.displayLarge)
                            .foregroundStyle(.white)

                        Text("/ 100")
                            .font(IATypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 120, height: 120)

                if let date = viewModel.latestSessionDate {
                    Text("Based on your latest session \u{2022} \(date.formatted(.relative(presentation: .named)))")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            HStack(spacing: 12) {
                metricCard(
                    title: "Technical\nAccuracy",
                    score: viewModel.insights.technicalAccuracyScore,
                    tint: IATheme.accent
                )
                metricCard(
                    title: "Communication",
                    score: viewModel.insights.communicationScore,
                    tint: IATheme.tertiary
                )
                metricCard(
                    title: "Confidence",
                    score: viewModel.insights.confidenceScore,
                    tint: IATheme.warning
                )
            }
        }
    }

    private func metricCard(title: String, score: Double?, tint: Color) -> some View {
        VStack(spacing: 10) {
            IAScoreRing(
                progress: (score ?? 0) / 100.0,
                title: "",
                value: score.map { "\(Int($0))" } ?? "--",
                size: 70,
                tint: tint
            )

            Text(title)
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    // MARK: - AI Insights

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            if !viewModel.insights.aiStrengths.isEmpty {
                insightGroup(title: "Strengths", items: viewModel.insights.aiStrengths, borderColor: IATheme.success)
            }

            if !viewModel.insights.aiImprovements.isEmpty {
                insightGroup(title: "Areas to Improve", items: viewModel.insights.aiImprovements, borderColor: IATheme.error)
            }
        }
    }

    private func insightGroup(title: String, items: [String], borderColor: Color) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(borderColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)

                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(borderColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(item)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
    }

    // MARK: - Recommended Practice

    private var recommendedPracticeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Practice")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            VStack(spacing: 12) {
                NavigationLink(destination: SessionSetupView()) {
                    practiceActionRow(
                        icon: "mic.fill",
                        title: "Start Practice Session",
                        detail: "Focus on your weaker areas"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(IATheme.inverseSurface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        }
    }

    private func practiceActionRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(.white)

                Text(detail)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        IAEmptyState(
            title: "No insights yet",
            subtitle: "Complete your first interview session to see performance insights and AI feedback.",
            symbol: "chart.bar.xaxis"
        )
    }
}
