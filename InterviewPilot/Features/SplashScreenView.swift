import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("BrandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .accessibilityLabel("Interview Ace AI logo")

                VStack(spacing: 8) {
                    Text("InterviewAce")
                        .font(IATypography.displayMedium)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Land your dream job")
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.textSecondary)
                }
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
