import SwiftUI

struct SessionReviewView: View {
    @State var viewModel: SessionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(IPTheme.backgroundTop).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        // Stats overview
                        statsSection

                        // Question type breakdown
                        if !viewModel.questionTypeBreakdown.isEmpty {
                            questionTypeSection
                        }

                        // Exchanges list
                        exchangesSection
                    }
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.vertical, IPTheme.spacing16)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Session Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.brandLight)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: IPTheme.spacing12) {
            statCard(title: "Duration", value: viewModel.formattedDuration, icon: "clock.fill")
            statCard(title: "Questions", value: "\(viewModel.exchanges.count)", icon: "questionmark.bubble.fill")
            statCard(title: "Avg Latency", value: "\(viewModel.averageLatency)ms", icon: "bolt.fill")
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: IPTheme.spacing4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(IPTheme.brandLight)

            Text(value)
                .font(IPTypography.headlineMedium)
                .foregroundStyle(.white)

            Text(title)
                .font(IPTypography.labelSmall)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(IPTheme.spacing12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
    }

    // MARK: - Question Types

    private var questionTypeSection: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing8) {
            Text("Question Types")
                .font(IPTypography.headlineSmall)
                .foregroundStyle(.white)

            ForEach(viewModel.questionTypeBreakdown, id: \.0) { type, count in
                HStack {
                    Text(type.displayName)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(count)")
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(IPTheme.questionTypeColor(type).opacity(0.3), in: Capsule())
                }
                .padding(.vertical, 4)
            }
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusLarge))
    }

    // MARK: - Exchanges

    private var exchangesSection: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            Text("Interview Exchanges")
                .font(IPTypography.headlineSmall)
                .foregroundStyle(.white)

            ForEach(viewModel.exchanges) { exchange in
                ExchangeDetailView(exchange: exchange)
            }
        }
    }
}
