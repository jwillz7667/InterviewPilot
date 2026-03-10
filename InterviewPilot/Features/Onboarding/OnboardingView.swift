import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [(icon: String, title: String, description: String)] = [
        ("mic.fill", "Real-Time Transcription",
         "Place your phone face-up on your desk. The mic captures the interviewer's voice and transcribes in real-time."),
        ("sparkles", "AI-Powered Responses",
         "Get intelligent response suggestions streamed to your screen before the interviewer finishes asking."),
        ("bolt.fill", "Pre-Computed Answers",
         "Upload your resume and job description to pre-generate likely Q&A pairs for instant cache hits."),
        ("lock.shield.fill", "Secure & Private",
         "Your data is encrypted and protected. Sign in once and you're set.")
    ]

    var body: some View {
        ZStack {
            Color(IPTheme.backgroundTop).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: IPTheme.spacing24) {
                            Image(systemName: page.icon)
                                .font(.system(size: 64))
                                .foregroundStyle(IPTheme.brand.gradient)
                                .symbolEffect(.bounce, value: currentPage == index)

                            Text(page.title)
                                .font(IPTypography.headlineLarge)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(page.description)
                                .font(IPTypography.bodyLarge)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, IPTheme.spacing24)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Spacer()

                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation(IPAnimations.standard) {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(IPTheme.brand.gradient, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
                }
                .padding(.horizontal, IPTheme.spacing24)
                .padding(.bottom, IPTheme.spacing24)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        onComplete()
                    }
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, IPTheme.spacing16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
