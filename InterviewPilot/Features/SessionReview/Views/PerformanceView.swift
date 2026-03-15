import SwiftUI

struct PerformanceView: View {
    let exchanges: [Exchange]
    let summary: SessionTelemetrySummary?

    var body: some View {
        IPPanel(tone: .primary, padding: 20, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: IPTheme.spacing16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Metrics")
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Key speed and reliability signals from the interview session.")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricTile(
                        title: "Average first token",
                        value: averageFirstToken.map(formatLatency) ?? "n/a",
                        icon: "timer",
                        color: latencyColor(averageFirstToken ?? 0, successThreshold: 900, warningThreshold: 1500)
                    )

                    metricTile(
                        title: "Average completion",
                        value: formatLatency(summary?.averageLiveGenerationDurationMs ?? summary?.averageGenerationDurationMs ?? averageLatency),
                        icon: "bolt.fill",
                        color: latencyColor(summary?.averageLiveGenerationDurationMs ?? summary?.averageGenerationDurationMs ?? averageLatency, successThreshold: 1800, warningThreshold: 3200)
                    )

                    metricTile(
                        title: "Cache hit rate",
                        value: String(format: "%.0f%%", summary?.cacheHitRate ?? cacheHitRate),
                        icon: "arrow.triangle.2.circlepath",
                        color: (summary?.cacheHitRate ?? cacheHitRate) > 50 ? IPTheme.success : IPTheme.accent
                    )

                    metricTile(
                        title: "Questions answered",
                        value: "\(exchanges.count)",
                        icon: "checkmark.circle.fill",
                        color: IPTheme.success
                    )
                }

                if let p95Live = summary?.p95LiveGenerationDurationMs {
                    infoRow(
                        title: "P95 live completion",
                        value: formatLatency(p95Live),
                        icon: "waveform.path.ecg",
                        color: latencyColor(p95Live, successThreshold: 2400, warningThreshold: 4000)
                    )
                }

                if let predictiveFireRate = summary?.predictiveFireRate {
                    infoRow(
                        title: "Predictive fire rate",
                        value: String(format: "%.0f%%", predictiveFireRate),
                        icon: "bolt.badge.clock.fill",
                        color: predictiveFireRate > 40 ? IPTheme.success : IPTheme.accent
                    )
                }
            }
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(IPTypography.headlineSmall)
                .foregroundStyle(IPTheme.textPrimary)

            Text(title)
                .font(IPTypography.bodySmall)
                .foregroundStyle(IPTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ipInsetSurface(cornerRadius: 22)
    }

    private func infoRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
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

    private var averageFirstToken: Int? {
        summary?.averageLiveTimeToFirstTokenMs ?? summary?.averageTimeToFirstTokenMs
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

    private func latencyColor(_ latencyMs: Int, successThreshold: Int, warningThreshold: Int) -> Color {
        if latencyMs <= successThreshold {
            return IPTheme.success
        }

        if latencyMs <= warningThreshold {
            return IPTheme.accent
        }

        return IPTheme.warning
    }
}
