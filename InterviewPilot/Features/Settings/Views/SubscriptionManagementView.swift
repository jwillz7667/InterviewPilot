import SwiftUI

struct SubscriptionManagementView: View {
    struct PreviewState {
        let entitlement: BillingEntitlement?
        let isLoading: Bool
    }

    @State private var subscriptionService = SubscriptionService.shared
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss
    private let previewState: PreviewState?

    init(previewState: PreviewState? = nil) {
        self.previewState = previewState
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        topBar
                        currentPlanSection
                        usageSection
                        actionsSection

                        if !isProTier {
                            upgradeSection
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                    .padding(.bottom, 30)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
            }
            .task {
                guard previewState == nil else { return }
                await subscriptionService.refresh(forceStoreKitSync: false)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 12) {
                IABrandLogo(size: 42, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Ace AI")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Subscription")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(IASecondaryButtonStyle())
        }
    }

    // MARK: - Current Plan Section

    private var currentPlanSection: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                IASectionHeader(
                    eyebrow: "Current Plan",
                    title: planDisplayName,
                    subtitle: nil,
                    symbol: "creditcard.fill"
                )

                HStack(spacing: 10) {
                    IAStatusPill(
                        title: tierBadgeTitle,
                        symbol: tierBadgeSymbol,
                        tint: tierBadgeTint
                    )

                    if let entitlement = currentEntitlement, entitlement.hasActiveSubscription {
                        IAStatusPill(
                            title: "Active",
                            symbol: "checkmark.seal.fill",
                            tint: IATheme.success
                        )
                    }
                }

                if let entitlement = currentEntitlement {
                    if entitlement.hasActiveSubscription {
                        VStack(alignment: .leading, spacing: 8) {
                            if let priceLabel = planPriceLabel {
                                detailRow(icon: "tag.fill", label: "Price", value: priceLabel)
                            }

                            if let renewalDate = formattedRenewalDate {
                                detailRow(icon: "calendar", label: "Renews", value: renewalDate)
                            }

                            detailRow(
                                icon: "sparkles",
                                label: "Response quality",
                                value: entitlement.responseQuality.capitalized
                            )
                        }
                    } else if currentTier == "free" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You're on the Free plan with limited interviews per month.")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)

                            Button(action: { showPaywall = true }) {
                                Text("Upgrade Now")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(IAPrimaryButtonStyle())
                        }
                    } else {
                        Text(entitlement.statusDetail)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(IATheme.textTertiary)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)

            Spacer()

            Text(value)
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                IASectionHeader(
                    eyebrow: "Usage",
                    title: "This Month",
                    subtitle: nil,
                    symbol: "chart.bar.fill"
                )

                if let entitlement = currentEntitlement {
                    if entitlement.hasActiveSubscription || entitlement.sandboxFullAccess {
                        // Subscribed users: unlimited interviews
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "infinity")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(IATheme.accent)

                                Text("Unlimited interviews")
                                    .font(IATypography.bodyLarge)
                                    .foregroundStyle(IATheme.textPrimary)
                            }

                            if entitlement.monthlyInterviewsUsed > 0 {
                                let used = entitlement.monthlyInterviewsUsed
                                Text("\(used) interview\(used == 1 ? "" : "s") completed this month")
                                    .font(IATypography.bodySmall)
                                    .foregroundStyle(IATheme.textSecondary)
                            }
                        }
                    } else {
                        // Free/trial users: limited interviews
                        let used = entitlement.monthlyInterviewsUsed
                        let limit = entitlement.monthlyInterviewLimit
                        let remaining = entitlement.monthlyInterviewsRemaining

                        VStack(alignment: .leading, spacing: 12) {
                            IAProgressBar(
                                progress: limit > 0 ? Double(used) / Double(limit) : 0,
                                label: "Interviews used",
                                tint: remaining > 0 ? IATheme.accent : IATheme.warning
                            )

                            Text("\(used) of \(limit) interviews used this month")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)

                            if remaining <= 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(IATheme.warning)

                                    Text("No interviews remaining. Upgrade for unlimited access.")
                                        .font(IATypography.bodySmall)
                                        .foregroundStyle(IATheme.warning)
                                }
                            }
                        }
                    }

                    if let renewalDate = formattedRenewalDate {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(IATheme.textTertiary)

                            Text("Next billing cycle: \(renewalDate)")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("Sign in to view your usage.")
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                IASectionHeader(
                    eyebrow: nil,
                    title: "Manage",
                    subtitle: nil,
                    symbol: "gearshape.fill"
                )

                if currentEntitlement?.hasActiveSubscription == true {
                    Button(action: openSubscriptionManagement) {
                        Label("Manage Subscription", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IAPrimaryButtonStyle())
                }

                Button(action: restorePurchases) {
                    Label("Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(subscriptionService.isPurchasing)
            }
        }
    }

    // MARK: - Upgrade Section

    private var upgradeSection: some View {
        GradientHeroCard(cornerRadius: IATheme.radiusLarge) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Upgrade to Pro")
                            .font(IATypography.headlineMedium)
                            .foregroundStyle(.white)

                        Text("Unlock coding AI, voice prep, priority models, and 480 token responses.")
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer(minLength: 12)

                    IAStarburst(size: 32, tint: .white.opacity(0.3))
                }

                Button(action: { showPaywall = true }) {
                    Text("View Plans")
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data Helpers

    private var currentEntitlement: BillingEntitlement? {
        previewState?.entitlement ?? subscriptionService.currentEntitlement
    }

    private var currentTier: String {
        currentEntitlement?.tier ?? "free"
    }

    private var isProTier: Bool {
        currentTier == "pro" || currentTier == "sandbox"
    }

    private var planDisplayName: String {
        guard let entitlement = currentEntitlement else { return "No Plan" }
        switch entitlement.tier {
        case "pro":
            return "Interview Ace AI Pro"
        case "plus":
            return "Interview Ace AI Plus"
        case "sandbox":
            return "Sandbox (Developer)"
        case "trial":
            return "Free Trial"
        default:
            return "Free Plan"
        }
    }

    private var tierBadgeTitle: String {
        currentEntitlement?.planTitle ?? "Free"
    }

    private var tierBadgeSymbol: String {
        switch currentTier {
        case "pro":
            return "star.fill"
        case "plus":
            return "bolt.fill"
        case "sandbox":
            return "hammer.fill"
        case "trial":
            return "clock.fill"
        default:
            return "person.fill"
        }
    }

    private var tierBadgeTint: Color {
        switch currentTier {
        case "pro":
            return IATheme.accent
        case "plus":
            return IATheme.tertiary
        case "sandbox":
            return IATheme.warning
        case "trial":
            return IATheme.primaryContainer
        default:
            return IATheme.textSecondary
        }
    }

    private var planPriceLabel: String? {
        // Try to find the matching product from SubscriptionService
        guard let entitlement = currentEntitlement,
              let productId = entitlement.productId else { return nil }
        let products = subscriptionService.products
        return products.first(where: { $0.productId == productId })?.displayPrice
    }

    private var formattedRenewalDate: String? {
        guard let iso = currentEntitlement?.currentPeriodEndsAt,
              let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Actions

    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    private func restorePurchases() {
        guard previewState == nil else { return }
        Task {
            do {
                try await subscriptionService.restorePurchases()
            } catch {
                subscriptionService.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Previews

#Preview("Management - Pro") {
    SubscriptionManagementView(
        previewState: .init(
            entitlement: managementPreviewEntitlement(tier: "pro"),
            isLoading: false
        )
    )
}

#Preview("Management - Plus") {
    SubscriptionManagementView(
        previewState: .init(
            entitlement: managementPreviewEntitlement(tier: "plus"),
            isLoading: false
        )
    )
}

#Preview("Management - Free") {
    SubscriptionManagementView(
        previewState: .init(
            entitlement: managementPreviewEntitlement(tier: "free"),
            isLoading: false
        )
    )
}

#Preview("Management - Trial") {
    SubscriptionManagementView(
        previewState: .init(
            entitlement: managementPreviewEntitlement(tier: "trial"),
            isLoading: false
        )
    )
}

private func managementPreviewEntitlement(tier: String) -> BillingEntitlement {
    let isSubscribed = tier == "plus" || tier == "pro"
    return BillingEntitlement(
        tier: tier,
        status: "active",
        accessSource: "preview",
        product: tier,
        productId: isSubscribed ? "\(tier)_monthly" : nil,
        features: ["live_interview", "session_history"],
        featureFlags: [
            "live_interview": true,
            "voice_prep": tier == "pro",
            "priority_models": tier == "pro",
        ],
        sandboxFullAccess: false,
        trialInterviewLimit: 5,
        trialInterviewsUsed: tier == "trial" ? 2 : 0,
        interviewsRemaining: tier == "trial" ? 3 : (isSubscribed ? 9999 : 1),
        hasActiveSubscription: isSubscribed,
        paywallRequired: !isSubscribed && tier != "trial",
        appAccountToken: UUID().uuidString,
        currentPeriodEndsAt: isSubscribed
            ? ISO8601DateFormatter().string(from: .now.addingTimeInterval(60 * 60 * 24 * 22))
            : nil,
        gracePeriodEndsAt: nil,
        trialDaysRemaining: tier == "trial" ? 5 : nil,
        responseQuality: tier == "pro" ? "premium" : (tier == "plus" ? "enhanced" : "standard"),
        monthlyInterviewsUsed: isSubscribed ? 12 : 2,
        monthlyInterviewLimit: isSubscribed ? 999 : 3,
        monthlyInterviewsRemaining: isSubscribed ? 987 : 1,
        catalog: []
    )
}
