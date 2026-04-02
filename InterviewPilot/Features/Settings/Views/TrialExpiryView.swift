import SwiftUI

struct TrialExpiryView: View {
    @Environment(\.dismiss) private var dismiss
    let onUpgrade: () -> Void

    var body: some View {
        ZStack {
            IAAppBackground()
            ScrollView {
                VStack(spacing: IATheme.spacing24) {
                    topSection
                    whatYouKeepSection
                    whatYouLoseSection
                    ctaSection
                }
                .padding(.horizontal, IATheme.spacing20)
                .padding(.vertical, 40)
            }
            .iaScrollablePage()
        }
    }

    // MARK: - Top Section

    private var topSection: some View {
        VStack(spacing: 20) {
            IABrandLogo(size: 64, showShadow: true, variant: .filled)

            VStack(spacing: IATheme.spacing12) {
                Text("Your free trial has ended")
                    .font(IATypography.displayMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("You've been downgraded to the Free plan. Here's what changed:")
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - What You Keep

    private var whatYouKeepSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: "Free Plan",
                title: "What you keep",
                subtitle: nil,
                symbol: "checkmark.circle.fill",
                tint: IATheme.success
            )

            IAPanel(tone: .secondary) {
                VStack(alignment: .leading, spacing: IATheme.spacing16) {
                    featureRow("3 interviews per month", symbol: "checkmark.circle.fill", tint: IATheme.success)
                    featureRow("Standard AI responses", symbol: "checkmark.circle.fill", tint: IATheme.success)
                    featureRow("Recent session history", symbol: "checkmark.circle.fill", tint: IATheme.success)
                }
            }
        }
    }

    // MARK: - What You Lose

    private var whatYouLoseSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: "Upgrade Required",
                title: "What you're missing",
                subtitle: nil,
                symbol: "lock.fill",
                tint: IATheme.error
            )

            IAPanel(tone: .secondary) {
                VStack(alignment: .leading, spacing: IATheme.spacing16) {
                    featureRow("Unlimited interviews", symbol: "xmark.circle.fill", tint: IATheme.error)
                    featureRow("Premium AI models (GPT-4.1)", symbol: "xmark.circle.fill", tint: IATheme.error)
                    featureRow("Resume-personalized responses", symbol: "xmark.circle.fill", tint: IATheme.error)
                    featureRow("All response formats", symbol: "xmark.circle.fill", tint: IATheme.error)
                    featureRow("Voice prep sessions", symbol: "xmark.circle.fill", tint: IATheme.error)
                }
            }
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: IATheme.spacing16) {
            Button {
                onUpgrade()
                dismiss()
            } label: {
                Text("Upgrade Now")
            }
            .buttonStyle(IAPrimaryButtonStyle())

            Button {
                dismiss()
            } label: {
                Text("Continue with Free")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, IATheme.spacing8)
    }

    // MARK: - Feature Row Helper

    private func featureRow(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(tint)
            Text(text)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
            Spacer()
        }
    }
}

#Preview("Trial Expiry") {
    TrialExpiryView(onUpgrade: {})
}
