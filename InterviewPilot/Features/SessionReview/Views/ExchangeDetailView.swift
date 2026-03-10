import SwiftUI

struct ExchangeDetailView: View {
    let exchange: Exchange
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing8) {
            // Question
            Button(action: {
                withAnimation(IPAnimations.standard) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .top, spacing: IPTheme.spacing8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(IPTheme.brandLight)
                        .font(.system(size: 16))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exchange.questionTranscript)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: IPTheme.spacing8) {
                            let type = QuestionType(rawValue: exchange.questionType) ?? .unknown
                            Text(type.displayName)
                                .font(IPTypography.labelSmall)
                                .foregroundStyle(IPTheme.questionTypeColor(type))

                            Text("\(exchange.responseLatencyMs)ms")
                                .font(IPTypography.labelSmall)
                                .foregroundStyle(.white.opacity(0.3))

                            if exchange.wasPreComputed {
                                Label("Cached", systemImage: "bolt.fill")
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(.yellow.opacity(0.7))
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }

            // Response (expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generated Response")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.4))

                    Text(exchange.generatedResponse)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(3)
                }
                .padding(.leading, 24)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(IPTheme.spacing12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
    }
}
