import SwiftUI

struct ExchangeDetailView: View {
    let exchange: Exchange
    @State private var isExpanded = false

    var body: some View {
        IAPanel(tone: .primary, padding: 18, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    withAnimation(IAAnimations.standard) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(IATheme.accent.opacity(0.10))
                            .frame(width: 38, height: 38)
                            .overlay {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(IATheme.accent)
                            }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(exchange.questionTranscript)
                                .font(IATypography.bodyLarge)
                                .foregroundStyle(IATheme.textPrimary)
                                .lineLimit(isExpanded ? nil : 2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 8) {
                                let type = QuestionType(rawValue: exchange.questionType) ?? .unknown
                                labelChip(type.displayName, color: IATheme.questionTypeColor(type))
                                labelChip("\(exchange.responseLatencyMs)ms", color: IATheme.textSecondary)

                                if exchange.wasPreComputed {
                                    labelChip("Cached", color: IATheme.accent)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(IATheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        if let telemetry = exchange.telemetry {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                telemetryChip(title: "First token", value: formattedLatency(telemetry.timeToFirstTokenMs))
                                telemetryChip(title: "Completion", value: formattedLatency(telemetry.generationDurationMs))
                                telemetryChip(title: "Question capture", value: formattedLatency(telemetry.questionDurationMs))
                                telemetryChip(title: "Turn detect", value: formattedLatency(telemetry.speechEndToFireMs))
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Generated response")
                                .font(IATypography.labelSmall)
                                .tracking(0.8)
                                .foregroundStyle(IATheme.textSecondary)

                            Text(exchange.generatedResponse)
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textPrimary)
                                .lineSpacing(4)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func labelChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(IATypography.labelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func telemetryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textSecondary)
            Text(value)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .iaInsetSurface(cornerRadius: 18)
    }

    private func formattedLatency(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        if value < 1000 {
            return "\(value)ms"
        }

        return String(format: "%.1fs", Double(value) / 1000)
    }
}
