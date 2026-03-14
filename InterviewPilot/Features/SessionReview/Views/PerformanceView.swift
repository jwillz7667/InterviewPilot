import SwiftUI

struct PerformanceView: View {
    let exchanges: [Exchange]
    let summary: SessionTelemetrySummary?

    var body: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: IPTheme.spacing16) {
                Text("Performance metrics")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                if let firstToken = summary?.averageLiveTimeToFirstTokenMs ?? summary?.averageTimeToFirstTokenMs {
                    metricRow(
                        title: "Average first token",
                        value: formatLatency(firstToken),
                        icon: "timer",
                        color: latencyColor(firstToken, successThreshold: 900, warningThreshold: 1500)
                    )
                }

                metricRow(
                    title: "Average full completion",
                    value: formatLatency(summary?.averageLiveGenerationDurationMs ?? summary?.averageGenerationDurationMs ?? averageLatency),
                    icon: "bolt.fill",
                    color: latencyColor(
                        summary?.averageLiveGenerationDurationMs ?? summary?.averageGenerationDurationMs ?? averageLatency,
                        successThreshold: 1800,
                        warningThreshold: 3200
                    )
                )

                if let p95Live = summary?.p95LiveGenerationDurationMs {
                    metricRow(
                        title: "P95 live completion",
                        value: formatLatency(p95Live),
                        icon: "waveform.path.ecg",
                        color: latencyColor(p95Live, successThreshold: 2400, warningThreshold: 4000)
                    )
                }

                metricRow(
                    title: "Cache hit rate",
                    value: String(format: "%.0f%%", summary?.cacheHitRate ?? cacheHitRate),
                    icon: "arrow.triangle.2.circlepath",
                    color: (summary?.cacheHitRate ?? cacheHitRate) > 50 ? IPTheme.success : IPTheme.accent
                )

                if let predictiveFireRate = summary?.predictiveFireRate {
                    metricRow(
                        title: "Predictive fire rate",
                        value: String(format: "%.0f%%", predictiveFireRate),
                        icon: "bolt.badge.clock.fill",
                        color: predictiveFireRate > 40 ? IPTheme.success : IPTheme.accentForeground
                    )
                }

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

    private func formatLatency(_ latencyMs: Int) -> String {
        if latencyMs < 1000 {
            return "\(latencyMs)ms"
        }

        return String(format: "%.1fs", Double(latencyMs) / 1000)
    }

    private func latencyColor(
        _ latencyMs: Int,
        successThreshold: Int,
        warningThreshold: Int
    ) -> Color {
        if latencyMs <= successThreshold {
            return IPTheme.success
        }

        if latencyMs <= warningThreshold {
            return IPTheme.accent
        }

        return IPTheme.warning
    }
}
