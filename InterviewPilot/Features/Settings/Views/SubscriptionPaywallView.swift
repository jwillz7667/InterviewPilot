import SwiftUI

struct SubscriptionPaywallView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var isPurchasing = false

    /// Why the paywall is being shown. Drives hero copy and which card is
    /// emphasized so the user lands on the upgrade that resolves their trigger.
    let reason: PaywallReason

    init(reason: PaywallReason = .upgradeBrowse) {
        self.reason = reason
    }

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }

    enum PaywallReason: Equatable {
        /// User tapped Upgrade with no specific exhausted-state trigger.
        case upgradeBrowse
        /// Standard quota for the period is gone; Pro restores it.
        case standardExhausted
        /// Premium quota for the period is gone; Premium tier removes the cap.
        case premiumExhausted
        /// A specific feature (voice prep, post-session analysis, etc.) requires
        /// a higher tier; `feature` is the backend feature flag that gated the
        /// request and is shown in the hero subtitle.
        case featureGated(feature: String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        headerBar
                        heroSection
                        if let error = subscriptionService.errorMessage {
                            errorBanner(error)
                        }
                        if isTrialActive { trialBanner }
                        billingToggle
                        tierCardsSection
                        comparisonSection
                        actionsSection
                        legalSection
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                    .padding(.bottom, 40)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await subscriptionService.refresh(forceStoreKitSync: true)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 12) {
                Image("BrandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 38, height: 38)

                Text("InterviewAce")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.accent)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        IAPanel(tone: .secondary, padding: 24, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose Your Plan")
                            .font(IATypography.displayMedium)
                            .foregroundStyle(IATheme.textPrimary)

                        Text(heroSubtitle)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)
                    IAStarburst(size: 34)
                        .padding(.top, 6)
                }

                HStack(spacing: 8) {
                    IAStatusPill(
                        title: currentEntitlement?.planTitle ?? "Free",
                        symbol: tierIcon,
                        tint: tierTint
                    )

                    if currentEntitlement?.hasActiveSubscription == true {
                        IAStatusPill(title: "Active", symbol: "checkmark.seal.fill", tint: IATheme.success)
                    }
                }
            }
        }
    }

    private var heroSubtitle: String {
        switch reason {
        case .standardExhausted:
            return "You've used all your standard interviews this month. Upgrade to Pro for 25 standard + 10 premium per month."
        case .premiumExhausted:
            return "You've used your premium interviews this month. Premium gives you unlimited GPT-4.1 sessions."
        case .featureGated(let feature):
            return "\(featureLabel(feature)) is a Premium feature. Upgrade to unlock it now."
        case .upgradeBrowse:
            break
        }

        guard let ent = currentEntitlement else {
            return "Start with 3 free interviews per month, or upgrade for unlimited access with premium AI."
        }
        if ent.isInTrial, let days = ent.trialDaysRemaining {
            return "\(days) day\(days == 1 ? "" : "s") left in your free trial. Subscribe to keep full access."
        }
        if ent.hasActiveSubscription {
            return "You're on the \(ent.planTitle) plan. Upgrade anytime for more features."
        }
        return "Start with 3 free interviews per month, or upgrade for unlimited access with premium AI."
    }

    private func featureLabel(_ feature: String) -> String {
        switch feature {
        case "voice_prep": return "Voice prep"
        case "post_session_analysis": return "Post-session AI analysis"
        case "priority_models": return "Priority models"
        case "live_interview": return "Live interview assist"
        default:
            return feature
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    /// Which tier card should the highlight ring + scroll position favor.
    private var emphasizedTier: SubscriptionTier {
        switch reason {
        case .standardExhausted: return .pro
        case .premiumExhausted, .featureGated: return .premium
        case .upgradeBrowse:
            // Default emphasis: nudge users toward Premium unless they're already there.
            return currentTier == .premium || currentTier == .sandbox ? .pro : .premium
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        GradientHeroCard(cornerRadius: IATheme.radiusLarge) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trialDaysRemaining) day\(trialDaysRemaining == 1 ? "" : "s") left")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(.white)
                    Text("Subscribe now to keep premium access")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 50, height: 50)
                    VStack(spacing: 0) {
                        Text("\(trialDaysRemaining)")
                            .font(IATypography.headlineMedium)
                            .foregroundStyle(.white)
                        Text("days")
                            .font(IATypography.labelSmall)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 10) {
            Picker("Billing", selection: $billingPeriod) {
                ForEach(BillingPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(billingPeriod == .yearly ? "Save 33%" : "Save 33%")
                .font(IATypography.labelSmall)
                .foregroundStyle(billingPeriod == .yearly ? .white : IATheme.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(billingPeriod == .yearly ? IATheme.success : IATheme.success.opacity(0.12), in: Capsule())
        }
        .padding(14)
        .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    // MARK: - Tier Cards

    private var tierCardsSection: some View {
        VStack(spacing: 12) {
            freeTierCard
            proTierCard
            premiumTierCard
        }
    }

    // FREE

    private var freeTierCard: some View {
        let isCurrent = currentTier == .free

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Free")
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(IATheme.textPrimary)
                Spacer()
                Text("$0")
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                freeFeatureRow("3 standard interviews / month", included: true)
                freeFeatureRow("1 premium interview / month", included: true)
                freeFeatureRow("Standard AI (GPT-4.1 Mini)", included: true)
                freeFeatureRow("Recent session history", included: true)
                freeFeatureRow("Premium AI models (GPT-4.1)", included: false)
                freeFeatureRow("Coding AI (o4-mini)", included: false)
                freeFeatureRow("Voice prep sessions", included: false)
            }

            if isCurrent {
                currentPlanLabel
            }
        }
        .padding(18)
        .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isCurrent ? IATheme.accent : IATheme.outlineVariant, lineWidth: isCurrent ? 2 : 1)
        }
    }

    // PRO

    private var proTierCard: some View {
        let isCurrent = currentTier == .pro
        let isRecommended = emphasizedTier == .pro && !isCurrent

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Pro")
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)

                    if isRecommended {
                        Text("RECOMMENDED")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(IATheme.tertiary, in: Capsule())
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(proPrice)
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)
                    if billingPeriod == .yearly {
                        Text(proMonthlyEquivalent)
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                tierFeatureRow("25 standard interviews / month")
                tierFeatureRow("10 premium interviews / month")
                tierFeatureRow("Premium AI on demand (GPT-4.1)")
                tierFeatureRow("Resume personalization")
                tierFeatureRow("All response formats")
                tierFeatureRow("Full session history")
            }

            if isCurrent {
                currentPlanLabel
            } else {
                Button(action: { purchasePlan(tier: .pro) }) {
                    HStack(spacing: 8) {
                        if isPurchasing { ProgressView().tint(.white) }
                        Text("Get Pro")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(isPurchasing)
            }
        }
        .padding(18)
        .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isCurrent || isRecommended ? IATheme.tertiary : IATheme.outlineVariant,
                    lineWidth: isCurrent || isRecommended ? 2 : 1
                )
        }
    }

    // PREMIUM

    private var premiumTierCard: some View {
        let isCurrent = currentTier == .premium || currentTier == .sandbox

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Premium")
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("BEST VALUE")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(IATheme.accent, in: Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(premiumPrice)
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)
                    if billingPeriod == .yearly {
                        Text(premiumMonthlyEquivalent)
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                tierFeatureRow("Unlimited standard + premium")
                tierFeatureRow("Coding AI (o4-mini)")
                tierFeatureRow("Voice prep sessions")
                tierFeatureRow("Post-session AI analysis")
                tierFeatureRow("50-question prep banks")
                tierFeatureRow("Priority + dedicated capacity")
            }

            if isCurrent {
                currentPlanLabel
            } else {
                Button(action: { purchasePlan(tier: .premium) }) {
                    HStack(spacing: 8) {
                        if isPurchasing { ProgressView().tint(.white) }
                        Text("Get Premium")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IAPrimaryButtonStyle(isEnabled: !isPurchasing))
                .disabled(isPurchasing)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(IATheme.surfaceWhite)
                .shadow(color: IATheme.accent.opacity(0.12), radius: 12, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(colors: [IATheme.accent, IATheme.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 2
                )
        }
    }

    // MARK: - Feature Rows

    private func tierFeatureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(IATheme.success)
            Text(text)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textPrimary)
        }
    }

    private func freeFeatureRow(_ text: String, included: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(included ? IATheme.success : IATheme.textTertiary.opacity(0.4))
            Text(text)
                .font(IATypography.bodySmall)
                .foregroundStyle(included ? IATheme.textPrimary : IATheme.textTertiary)
        }
    }

    private var currentPlanLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .medium))
            Text("Current Plan")
                .font(IATypography.labelLarge)
        }
        .foregroundStyle(IATheme.success)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(IATheme.success.opacity(0.08), in: Capsule())
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        IAPanel(tone: .secondary, padding: 20, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Feature Comparison")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                // Headers
                HStack(spacing: 0) {
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Free").font(IATypography.labelMedium).foregroundStyle(IATheme.textSecondary).frame(width: 56, alignment: .center)
                    Text("Pro").font(IATypography.labelMedium).foregroundStyle(IATheme.tertiary).frame(width: 56, alignment: .center)
                    Text("Premium").font(IATypography.labelMedium).foregroundStyle(IATheme.accent).frame(width: 70, alignment: .center)
                }

                Divider()

                compareRow("Standard / mo", free: "3", pro: "25", premium: "\u{221E}")
                compareRow("Premium / mo", free: "1", pro: "10", premium: "\u{221E}")
                compareRow("Live AI", free: "Mini", pro: "Mini", premium: "GPT-4.1")
                compareRow("Coding AI", free: "Mini", pro: "Mini", premium: "o4-mini")
                compareRow("Live tokens", free: "320", pro: "320", premium: "600")
                compareCheck("Voice prep", free: false, pro: false, premium: true)
                compareCheck("Post-session AI analysis", free: false, pro: false, premium: true)
                compareCheck("50-question banks", free: false, pro: false, premium: true)
                compareCheck("Multi-profile (5)", free: false, pro: false, premium: true)
            }
        }
    }

    private func compareRow(_ label: String, free: String, pro: String, premium: String) -> some View {
        HStack(spacing: 0) {
            Text(label).font(IATypography.bodySmall).foregroundStyle(IATheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            Text(free).font(IATypography.labelSmall).foregroundStyle(IATheme.textTertiary).frame(width: 56, alignment: .center)
            Text(pro).font(IATypography.labelSmall).foregroundStyle(IATheme.tertiary).frame(width: 56, alignment: .center)
            Text(premium).font(IATypography.labelSmall).foregroundStyle(IATheme.accent).frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 4)
    }

    private func compareCheck(_ label: String, free: Bool, pro: Bool, premium: Bool) -> some View {
        HStack(spacing: 0) {
            Text(label).font(IATypography.bodySmall).foregroundStyle(IATheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            checkIcon(free).frame(width: 56, alignment: .center)
            checkIcon(pro).frame(width: 56, alignment: .center)
            checkIcon(premium).frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 4)
    }

    private func checkIcon(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark" : "minus")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(on ? IATheme.success : IATheme.textTertiary.opacity(0.35))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if currentEntitlement?.hasActiveSubscription == true {
                Button(action: {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Manage Subscription", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IASecondaryButtonStyle())
            }

            Button(action: restorePurchases) {
                Label("Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IASecondaryButtonStyle())
            .disabled(subscriptionService.isPurchasing)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Link("Terms of Use", destination: URL(string: "https://interviewace.app/terms")!)
                    .accessibilityHint("Opens the Terms of Use in Safari")
                Text("\u{2022}")
                    .accessibilityHidden(true)
                Link("Privacy Policy", destination: URL(string: "https://interviewace.app/privacy")!)
                    .accessibilityHint("Opens the Privacy Policy in Safari")
            }
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.accent)
        }
        .padding(.top, 4)
    }

    // MARK: - Data

    private var currentEntitlement: BillingEntitlement? { subscriptionService.currentEntitlement }
    private var currentProducts: [SubscriptionStoreProduct] { subscriptionService.products }
    /// The user's tier in canonical post-migration form (legacy `.plus` → `.pro`,
    /// `.trial` → `.free`) so paywall comparisons line up with the displayed cards.
    private var currentTier: SubscriptionTier {
        (currentEntitlement?.tier ?? .free).canonicalDisplayTier
    }

    private var isTrialActive: Bool {
        guard let ent = currentEntitlement else { return false }
        return ent.isInTrial && (ent.trialDaysRemaining ?? 0) > 0
    }

    private var trialDaysRemaining: Int { currentEntitlement?.trialDaysRemaining ?? 0 }
    private var tierIcon: String {
        switch currentTier {
        case .premium: return "sparkles"
        case .pro: return "bolt.fill"
        case .sandbox: return "hammer.fill"
        case .trial: return "clock.fill"
        case .plus: return "bolt.fill"
        case .free: return "person.fill"
        }
    }
    private var tierTint: Color {
        switch currentTier {
        case .premium: return IATheme.accent
        case .pro: return IATheme.tertiary
        case .sandbox: return IATheme.warning
        case .trial: return IATheme.primaryContainer
        case .plus: return IATheme.tertiary
        case .free: return IATheme.textSecondary
        }
    }

    // MARK: - Pricing

    private var proPrice: String {
        resolvePrice(tier: .pro, fallbackMonthly: "$9.99/mo", fallbackYearly: "$79.99/yr")
    }
    private var premiumPrice: String {
        resolvePrice(tier: .premium, fallbackMonthly: "$19.99/mo", fallbackYearly: "$149.99/yr")
    }
    private var proMonthlyEquivalent: String { "$6.67/mo" }
    private var premiumMonthlyEquivalent: String { "$12.50/mo" }

    /// Match a store product against a target tier, allowing the legacy
    /// `.plus` SKU (still vended by App Store Connect under the old product
    /// ID) to satisfy the new `.pro` slot. Premium needs a true `.premium`
    /// SKU before it can be purchased.
    private func productMatches(_ product: SubscriptionStoreProduct, target: SubscriptionTier) -> Bool {
        switch target {
        case .pro: return product.tier == .pro || product.tier == .plus
        case .premium: return product.tier == .premium
        default: return product.tier == target
        }
    }

    private func resolvePrice(tier: SubscriptionTier, fallbackMonthly: String, fallbackYearly: String) -> String {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        // Match by tier + period, rejecting empty `displayPrice` (which signals
        // StoreKit has not yet returned a localized price for the SKU) so we
        // fall through to the human-readable fallback rather than showing a
        // blank or non-price label.
        let candidates = currentProducts.filter { productMatches($0, target: tier) }
        if let p = candidates.first(where: { $0.productId.contains(period) && !$0.displayPrice.isEmpty }) {
            return p.displayPrice
        }
        if let p = candidates.first(where: { !$0.displayPrice.isEmpty }) {
            return p.displayPrice
        }
        return billingPeriod == .yearly ? fallbackYearly : fallbackMonthly
    }

    private func storeProductId(for tier: SubscriptionTier) -> String? {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        return currentProducts.first(where: { productMatches($0, target: tier) && $0.productId.contains(period) })?.productId
            ?? currentProducts.first(where: { productMatches($0, target: tier) })?.productId
    }

    // MARK: - Actions

    private func purchasePlan(tier: SubscriptionTier) {
        guard let productId = storeProductId(for: tier) else {
            subscriptionService.errorMessage = "Subscription products are not available. Please try again later."
            return
        }
        isPurchasing = true
        Task {
            do {
                try await subscriptionService.purchase(productId: productId)
                dismiss()
            } catch {
                subscriptionService.errorMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    private func restorePurchases() {
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

#Preview("Free") {
    SubscriptionPaywallView()
}
