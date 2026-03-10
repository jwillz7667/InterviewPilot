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
                        .foregroundStyle(.white.opacity(0.2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IPTheme.spacing20)
                } else if text.isEmpty && isGenerating {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.08))
                                .frame(height: 16)
                                .frame(maxWidth: i == 2 ? 200 : .infinity)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .transition(.opacity)
                } else {
                    Text(text)
                        .font(IPTypography.responseText)
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IPTheme.spacing20)
                        .id("response-end")
                }
            }
            .onChange(of: text) {
                withAnimation(IPAnimations.gentle) {
                    proxy.scrollTo("response-end", anchor: .bottom)
                }
            }
        }
    }
}
