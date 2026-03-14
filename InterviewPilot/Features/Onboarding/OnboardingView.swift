import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme
    var onComplete: () -> Void

    private let pages: [(icon: String, title: String, description: String, accent: Color)] = [
        (
            "waveform.and.mic",
            "Separate the room from your answer",
            "Live mode keeps the interviewer transcript and your on-screen answer in separate lanes so prompts stay visible while you speak.",
            IPTheme.accent
        ),
        (
            "briefcase.fill",
            "Anchor the session to the role",
            "Paste the full job posting so the app can surface tighter answers, stronger terminology, and more accurate framing during the interview.",
            IPTheme.accent
        ),
        (
            "bolt.badge.checkmark.fill",
            "Prepare likely answers before the call",
            "Upload your resume and job description to generate likely questions and keep fast answers ready for the live interview.",
            IPTheme.accent
        ),
        (
            "lock.shield.fill",
            "Stay private and in control",
            "Authentication is handled securely, and appearance can now follow system, light, or dark mode based on your interview setup.",
            IPTheme.accent
        )
    ]

    var body: some View {
        ZStack {
            IPAppBackground()

            VStack(spacing: 0) {
                HStack {
                    IPStatusPill(title: "Guided setup", symbol: "sparkles")
                    Spacer()
                    Button("Skip", action: onComplete)
                        .buttonStyle(IPSecondaryButtonStyle())
                        .opacity(currentPage == pages.count - 1 ? 0 : 1)
                        .allowsHitTesting(currentPage < pages.count - 1)
                }
                .padding(.horizontal, IPTheme.spacing20)
                .padding(.top, IPTheme.spacing16)

                Spacer(minLength: 16)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        IPPanel(tone: .accent(page.accent), padding: IPTheme.spacing24) {
                            VStack(alignment: .leading, spacing: 24) {
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(Color.clear)
                                    .frame(height: 180)
                                    .ipInsetSurface(cornerRadius: 30)
                                    .overlay {
                                        ZStack(alignment: .bottomTrailing) {
                                            IPBrandLogo(size: 104, cornerRadius: 30)

                                            ZStack {
                                                Circle()
                                                    .fill(IPTheme.accent.opacity(0.12))
                                                    .frame(width: 56, height: 56)

                                                Image(systemName: page.icon)
                                                    .font(.system(size: 24, weight: .semibold))
                                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                            }
                                            .offset(x: 34, y: 22)
                                        }
                                    }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text(page.title)
                                        .font(IPTypography.headlineLarge)
                                        .foregroundStyle(IPTheme.textPrimary)

                                    Text(page.description)
                                        .font(IPTypography.bodyLarge)
                                        .foregroundStyle(IPTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                HStack(spacing: 10) {
                                    ForEach(0..<pages.count, id: \.self) { dotIndex in
                                        Capsule()
                                            .fill(dotIndex == currentPage ? page.accent : Color.white.opacity(0.18))
                                            .frame(width: dotIndex == currentPage ? 34 : 10, height: 10)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .tag(index)
                        .padding(.horizontal, IPTheme.spacing20)
                        .padding(.bottom, IPTheme.spacing12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    Button(action: advance) {
                        HStack(spacing: 10) {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                            Image(systemName: currentPage == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .symbolEffect(.bounce, value: currentPage)
                        }
                    }
                    .buttonStyle(IPPrimaryButtonStyle())

                    Text(currentPage == pages.count - 1 ? "You can change appearance and app settings later." : "Swipe horizontally or continue through the guided setup.")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, IPTheme.spacing20)
                .padding(.bottom, IPTheme.spacing24)
            }
        }
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation(IPAnimations.hero) {
                currentPage += 1
            }
        } else {
            onComplete()
        }
    }
}
