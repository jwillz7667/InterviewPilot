import SwiftUI

struct SessionReviewView: View {
    @State var viewModel: SessionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        headerSection
                        statsSection
                        PerformanceView(exchanges: viewModel.exchanges)

                        if !viewModel.questionTypeBreakdown.isEmpty {
                            questionTypeSection
                        }

                        exchangesSection
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
            .navigationTitle("Session Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.accent)
                }
            }
        }
    }

    private var headerSection: some View {
        IPPanel(tone: .accent(IPTheme.accent)) {
            VStack(alignment: .leading, spacing: 16) {
                IPSectionHeader(
                    eyebrow: "Summary",
                    title: viewModel.interviewType.displayName,
                    subtitle: "A polished recap of the interview session with timing, question mix, and answer output.",
                    symbol: "chart.xyaxis.line"
                )

                HStack(spacing: 10) {
                    IPStatusPill(title: viewModel.formattedDuration, symbol: "clock.fill")
                    IPStatusPill(title: "\(viewModel.exchanges.count) exchanges", symbol: "text.bubble.fill")
                    IPStatusPill(title: "\(viewModel.averageLatency) ms avg", symbol: "bolt.fill", tint: IPTheme.accentWarm)
                }
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(title: "Duration", value: viewModel.formattedDuration, icon: "clock.fill")
            statCard(title: "Questions", value: "\(viewModel.exchanges.count)", icon: "questionmark.bubble.fill")
            statCard(title: "Avg Latency", value: "\(viewModel.averageLatency)ms", icon: "bolt.fill")
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        IPPanel(tone: .secondary, padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusMedium) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(IPTheme.accent)

                Text(value)
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)
                    .minimumScaleFactor(0.8)

                Text(title)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var questionTypeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Question types")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                ForEach(viewModel.questionTypeBreakdown, id: \.0) { type, count in
                    HStack {
                        Text(type.displayName)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textPrimary)

                        Spacer()

                        Text("\(count)")
                            .font(IPTypography.labelMedium)
                            .foregroundStyle(IPTheme.questionTypeColor(type))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(IPTheme.questionTypeColor(type).opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    private var exchangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interview exchanges")
                .font(IPTypography.headlineSmall)
                .foregroundStyle(IPTheme.textPrimary)

            ForEach(viewModel.exchanges) { exchange in
                ExchangeDetailView(exchange: exchange)
            }
        }
    }
}
