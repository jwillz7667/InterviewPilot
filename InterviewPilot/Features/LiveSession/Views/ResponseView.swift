import SwiftUI

struct ResponseView: View {
    let text: String
    let isGenerating: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if text.isEmpty && !isGenerating {
                    Text("Response will appear here...")
                        .font(IPTypography.responseText)
                        .foregroundStyle(IPTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IPTheme.spacing20)
                } else if text.isEmpty && isGenerating {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 16)
                                .frame(maxWidth: index == 2 ? 220 : .infinity)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .transition(.opacity)
                } else {
                    Text(text)
                        .font(IPTypography.responseText)
                        .foregroundStyle(IPTheme.textPrimary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IPTheme.spacing20)
                        .id("response-end")
                }
            }
            .ipScrollablePage()
            .onChange(of: text) {
                withAnimation(IPAnimations.gentle) {
                    proxy.scrollTo("response-end", anchor: .bottom)
                }
            }
        }
    }
}
