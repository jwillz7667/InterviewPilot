import SwiftUI

struct ExchangeDetailView: View {
    let exchange: Exchange
    @State private var isExpanded = false

    var body: some View {
        IPPanel(tone: .primary, padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusMedium) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    withAnimation(IPAnimations.standard) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(alignment: .top, spacing: IPTheme.spacing12) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(IPTheme.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(IPTheme.accentForeground)
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(exchange.questionTranscript)
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(IPTheme.textPrimary)
                                .lineLimit(isExpanded ? nil : 2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 8) {
                                let type = QuestionType(rawValue: exchange.questionType) ?? .unknown
                                Text(type.displayName)
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(IPTheme.questionTypeColor(type))

                                Text("\(exchange.responseLatencyMs)ms")
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(IPTheme.textSecondary)

                                if exchange.wasPreComputed {
                                    Label("Cached", systemImage: "bolt.fill")
                                        .font(IPTypography.labelSmall)
                                        .foregroundStyle(IPTheme.accentWarm)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(IPTheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        if let telemetry = exchange.telemetry {
                            telemetryGrid(telemetry)
                                .padding(.bottom, 4)
                        }

                        Text("Generated response")
                            .font(IPTypography.labelSmall)
                            .tracking(0.8)
                            .foregroundStyle(IPTheme.textSecondary)

                        Text(exchange.generatedResponse)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textPrimary)
                            .lineSpacing(4)
                    }
                    .padding(.leading, 52)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func telemetryGrid(_ telemetry: ExchangeTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Latency breakdown")
                .font(IPTypography.labelSmall)
                .tracking(0.8)
                .foregroundStyle(IPTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                telemetryChip(title: "First token", value: formattedLatency(telemetry.timeToFirstTokenMs))
                telemetryChip(title: "Completion", value: formattedLatency(telemetry.generationDurationMs))
                telemetryChip(title: "Question capture", value: formattedLatency(telemetry.questionDurationMs))
                telemetryChip(title: "Turn detect", value: formattedLatency(telemetry.speechEndToFireMs))
            }

            if telemetry.usedPredictiveFire {
                Label("Predictive fire used", systemImage: "bolt.badge.clock.fill")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.accentForeground)
            }
        }
    }

    private func telemetryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(IPTypography.labelSmall)
                .foregroundStyle(IPTheme.textSecondary)
            Text(value)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formattedLatency(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        if value < 1000 {
            return "\(value)ms"
        }

        return String(format: "%.1fs", Double(value) / 1000)
    }
}
