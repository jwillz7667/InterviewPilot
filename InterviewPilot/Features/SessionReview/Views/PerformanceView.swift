import SwiftUI

struct PerformanceView: View {
    let exchanges: [Exchange]

    var body: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            Text("Performance Metrics")
                .font(IPTypography.headlineSmall)
                .foregroundStyle(.white)

            // Average latency
            metricRow(
                title: "Avg Response Time",
                value: "\(averageLatency)ms",
                icon: "bolt.fill",
                color: averageLatency < 2000 ? IPTheme.success : IPTheme.warning
            )

            // Cache hit rate
            metricRow(
                title: "Cache Hit Rate",
                value: String(format: "%.0f%%", cacheHitRate),
                icon: "arrow.triangle.2.circlepath",
                color: cacheHitRate > 50 ? IPTheme.success : IPTheme.brandLight
            )

            // Questions answered
            metricRow(
                title: "Questions Answered",
                value: "\(exchanges.count)",
                icon: "checkmark.circle.fill",
                color: IPTheme.success
            )
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusLarge))
    }

    private func metricRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: IPTheme.spacing12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 16))
                .frame(width: 24)

            Text(title)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(IPTypography.bodyLarge)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }

    private var averageLatency: Int {
        guard !exchanges.isEmpty else { return 0 }
        return exchanges.map(\.responseLatencyMs).reduce(0, +) / exchanges.count
    }

    private var cacheHitRate: Double {
        guard !exchanges.isEmpty else { return 0 }
        let cached = exchanges.filter(\.wasPreComputed).count
        return Double(cached) / Double(exchanges.count) * 100
    }
}
