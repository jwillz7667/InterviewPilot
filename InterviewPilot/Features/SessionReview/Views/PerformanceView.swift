import SwiftUI

struct PerformanceView: View {
    let exchanges: [Exchange]

    var body: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: IPTheme.spacing16) {
                Text("Performance metrics")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                metricRow(
                    title: "Average response time",
                    value: "\(averageLatency)ms",
                    icon: "bolt.fill",
                    color: averageLatency < 2000 ? IPTheme.success : IPTheme.warning
                )

                metricRow(
                    title: "Cache hit rate",
                    value: String(format: "%.0f%%", cacheHitRate),
                    icon: "arrow.triangle.2.circlepath",
                    color: cacheHitRate > 50 ? IPTheme.success : IPTheme.accent
                )

                metricRow(
                    title: "Questions answered",
                    value: "\(exchanges.count)",
                    icon: "checkmark.circle.fill",
                    color: IPTheme.success
                )
            }
        }
    }

    private func metricRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(IPTheme.textPrimary)
                Text(value)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }

            Spacer()
        }
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
