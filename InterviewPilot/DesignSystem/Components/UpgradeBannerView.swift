import SwiftUI

struct UpgradeBannerView: View {
    @State private var subscriptionService = SubscriptionService.shared
    let onUpgradeTapped: () -> Void

    var body: some View {
        if let entitlement = subscriptionService.currentEntitlement,
           !entitlement.hasActiveSubscription,
           !entitlement.sandboxFullAccess {
            bannerContent(entitlement)
        }
    }

    @ViewBuilder
    private func bannerContent(_ entitlement: BillingEntitlement) -> some View {
        if entitlement.tier == "trial" {
            trialBanner(entitlement)
        } else {
            freeBanner(entitlement)
        }
    }

    // MARK: - Trial Banner

    private func trialBanner(_ entitlement: BillingEntitlement) -> some View {
        let daysLeft = entitlement.trialDaysRemaining ?? 7

        return HStack(spacing: IATheme.spacing16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") left in your trial")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(.white)

                Text("Subscribe to keep premium access")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            Button(action: onUpgradeTapped) {
                Text("Upgrade")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(IATheme.spacing20)
        .background(
            LinearGradient(
                colors: [IATheme.primaryContainer, IATheme.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
        )
    }

    // MARK: - Free Banner

    private func freeBanner(_ entitlement: BillingEntitlement) -> some View {
        let remaining = entitlement.monthlyInterviewsRemaining

        return IAPanel(tone: .secondary) {
            HStack(spacing: IATheme.spacing12) {
                Circle()
                    .fill(IATheme.accent.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(IATheme.accent)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock unlimited interviews")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("\(remaining) of 3 free interviews remaining this month")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }

                Spacer()

                Button("Upgrade", action: onUpgradeTapped)
                    .buttonStyle(IASecondaryButtonStyle())
            }
        }
    }
}

#Preview("Trial Banner") {
    VStack {
        UpgradeBannerView(onUpgradeTapped: {})
    }
    .padding()
}

#Preview("Free Banner") {
    VStack {
        UpgradeBannerView(onUpgradeTapped: {})
    }
    .padding()
}
