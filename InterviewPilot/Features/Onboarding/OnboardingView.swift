import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [(icon: String, title: String, description: String)] = [
        (
            "waveform.and.mic",
            "See the room and your answer separately",
            "Live mode keeps the interviewer transcript and your on-screen guidance in distinct lanes so the answer stays readable while you speak."
        ),
        (
            "briefcase.fill",
            "Anchor every session to the role",
            "Paste the job listing URL and Job Hopper infers category, level, and the framing that should guide your answers."
        ),
        (
            "sparkles.rectangle.stack",
            "Prepare likely answers before the call",
            "Upload your resume, build a prep bank, and reuse fast-response scaffolds during the interview."
        ),
        (
            "moon.stars.fill",
            "Stay polished in any environment",
            "The interface is tuned for both bright rooms and darker setups, with the same branded hierarchy in each appearance."
        ),
    ]

    var body: some View {
        ZStack {
            IPAppBackground()

            VStack(spacing: 0) {
                header
                introHeader
                cards
                footer
            }
        }
    }

    private var header: some View {
        HStack {
            IPBrandLogo(size: 44, showShadow: false, variant: .filled)

            Spacer()

            Button("Skip", action: onComplete)
                .buttonStyle(IPSecondaryButtonStyle())
                .opacity(currentPage == pages.count - 1 ? 0 : 1)
                .allowsHitTesting(currentPage < pages.count - 1)
        }
        .padding(.horizontal, IPTheme.spacing20)
        .padding(.top, IPTheme.spacing16)
    }

    private var introHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Interview prep that feels\nnative on iPhone")
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)
                    .lineSpacing(-4)

                Text("A quick walkthrough of how Job Hopper organizes prep, live guidance, and review.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            IPStarburst(size: 34)
                .padding(.top, 8)
        }
        .padding(.horizontal, IPTheme.spacing20)
        .padding(.top, 18)
    }

    private var cards: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                IPPanel(tone: .secondary, padding: 24, cornerRadius: 36) {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top) {
                            IPBrandLogo(size: 96, variant: .surface)

                            Spacer()

                            VStack(spacing: 10) {
                                IPStarburst(size: 34)

                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(IPTheme.accent.opacity(0.10))
                                    .frame(width: 54, height: 54)
                                    .overlay {
                                        Image(systemName: page.icon)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(IPTheme.accent)
                                    }
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
                                    .fill(dotIndex == currentPage ? IPTheme.accent : IPTheme.divider)
                                    .frame(width: dotIndex == currentPage ? 34 : 10, height: 10)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, IPTheme.spacing20)
                .padding(.vertical, 18)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: advance) {
                HStack(spacing: 10) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    Image(systemName: currentPage == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                }
            }
            .buttonStyle(IPPrimaryButtonStyle())

            Text(currentPage == pages.count - 1 ? "You can change theme and prep defaults later in settings." : "Swipe through the overview or continue step by step.")
                .font(IPTypography.bodySmall)
                .foregroundStyle(IPTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, IPTheme.spacing20)
        .padding(.bottom, IPTheme.spacing24)
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

#Preview("Onboarding") {
    OnboardingView {}
}
