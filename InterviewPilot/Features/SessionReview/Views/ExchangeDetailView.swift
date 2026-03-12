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
                                    .foregroundStyle(IPTheme.accent)
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
}
