import SwiftUI

struct ResponseView: View {
    let text: String
    let isGenerating: Bool

    var body: some View {
        IAPanel(tone: .secondary, padding: 18, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Suggested Answer")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)
                    Spacer()
                    IABrandLogo(size: 30, showShadow: false, variant: .surface)
                }

                ScrollView {
                    if text.isEmpty && !isGenerating {
                        Text("The response will appear here after the app has enough of the question to answer.")
                            .font(IATypography.responseText)
                            .foregroundStyle(IATheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if text.isEmpty && isGenerating {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(IATheme.accent.opacity(0.12))
                                    .frame(height: 16)
                                    .frame(maxWidth: index == 2 ? 220 : .infinity)
                                    .shimmer()
                            }
                        }
                        .transition(.opacity)
                    } else {
                        Text(text)
                            .font(IATypography.responseText)
                            .foregroundStyle(IATheme.textPrimary)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .defaultScrollAnchor(.top)
                .iaScrollablePage()
            }
        }
    }
}
