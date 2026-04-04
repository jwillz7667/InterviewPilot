import SwiftUI

struct SubscriptionPaywallView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var isPurchasing = false

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
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
            plusTierCard
            proTierCard
        }
    }

    // FREE

    private var freeTierCard: some View {
        let isCurrent = currentTier == "free" || currentTier == "trial"

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
                freeFeatureRow("3 interviews per month", included: true)
                freeFeatureRow("Standard AI (GPT-4.1 Mini)", included: true)
                freeFeatureRow("Recent session history", included: true)
                freeFeatureRow("Resume personalization", included: false)
                freeFeatureRow("Unlimited interviews", included: false)
                freeFeatureRow("Premium AI models", included: false)
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

    // PLUS

    private var plusTierCard: some View {
        let isCurrent = currentTier == "plus"

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plus")
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(IATheme.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plusPrice)
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)
                    if billingPeriod == .yearly {
                        Text(plusMonthlyEquivalent)
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                tierFeatureRow("Unlimited interviews")
                tierFeatureRow("Enhanced AI (GPT-4.1)")
                tierFeatureRow("400 token responses")
                tierFeatureRow("Resume personalization")
                tierFeatureRow("All response formats")
                tierFeatureRow("Full session history")
            }

            if isCurrent {
                currentPlanLabel
            } else {
                Button(action: { purchasePlan(tier: "plus") }) {
                    HStack(spacing: 8) {
                        if isPurchasing { ProgressView().tint(.white) }
                        Text("Get Plus")
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
                .stroke(isCurrent ? IATheme.tertiary : IATheme.outlineVariant, lineWidth: isCurrent ? 2 : 1)
        }
    }

    // PRO

    private var proTierCard: some View {
        let isCurrent = currentTier == "pro"

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("Pro")
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
                tierFeatureRow("Everything in Plus")
                tierFeatureRow("Coding AI (o4-mini)")
                tierFeatureRow("480 token responses")
                tierFeatureRow("Voice prep sessions")
                tierFeatureRow("Priority models")
            }

            if isCurrent {
                currentPlanLabel
            } else {
                Button(action: { purchasePlan(tier: "pro") }) {
                    HStack(spacing: 8) {
                        if isPurchasing { ProgressView().tint(.white) }
                        Text("Get Pro")
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
                    Text("Free").font(IATypography.labelMedium).foregroundStyle(IATheme.textSecondary).frame(width: 50, alignment: .center)
                    Text("Plus").font(IATypography.labelMedium).foregroundStyle(IATheme.tertiary).frame(width: 50, alignment: .center)
                    Text("Pro").font(IATypography.labelMedium).foregroundStyle(IATheme.accent).frame(width: 50, alignment: .center)
                }

                Divider()

                compareRow("Interviews", free: "3/mo", plus: "\u{221E}", pro: "\u{221E}")
                compareRow("AI Model", free: "Mini", plus: "4.1", pro: "4.1")
                compareRow("Tokens", free: "320", plus: "400", pro: "480")
                compareCheck("Resume AI", free: false, plus: true, pro: true)
                compareCheck("Formats", free: false, plus: true, pro: true)
                compareCheck("Coding AI", free: false, plus: false, pro: true)
                compareCheck("Voice Prep", free: false, plus: false, pro: true)
                compareCheck("Priority", free: false, plus: false, pro: true)
            }
        }
    }

    private func compareRow(_ label: String, free: String, plus: String, pro: String) -> some View {
        HStack(spacing: 0) {
            Text(label).font(IATypography.bodySmall).foregroundStyle(IATheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            Text(free).font(IATypography.labelSmall).foregroundStyle(IATheme.textTertiary).frame(width: 50, alignment: .center)
            Text(plus).font(IATypography.labelSmall).foregroundStyle(IATheme.tertiary).frame(width: 50, alignment: .center)
            Text(pro).font(IATypography.labelSmall).foregroundStyle(IATheme.accent).frame(width: 50, alignment: .center)
        }
        .padding(.vertical, 4)
    }

    private func compareCheck(_ label: String, free: Bool, plus: Bool, pro: Bool) -> some View {
        HStack(spacing: 0) {
            Text(label).font(IATypography.bodySmall).foregroundStyle(IATheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            checkIcon(free).frame(width: 50, alignment: .center)
            checkIcon(plus).frame(width: 50, alignment: .center)
            checkIcon(pro).frame(width: 50, alignment: .center)
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
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Text("Terms of Use")
                Text("\u{2022}")
                Text("Privacy Policy")
            }
            .font(IATypography.labelSmall)
            .foregroundStyle(IATheme.textSecondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Data

    private var currentEntitlement: BillingEntitlement? { subscriptionService.currentEntitlement }
    private var currentProducts: [SubscriptionStoreProduct] { subscriptionService.products }
    private var currentTier: String { currentEntitlement?.tier ?? "free" }

    private var isTrialActive: Bool {
        guard let ent = currentEntitlement else { return false }
        return ent.isInTrial && (ent.trialDaysRemaining ?? 0) > 0
    }

    private var trialDaysRemaining: Int { currentEntitlement?.trialDaysRemaining ?? 0 }
    private var tierIcon: String {
        switch currentTier {
        case "pro": return "star.fill"
        case "plus": return "bolt.fill"
        case "sandbox": return "hammer.fill"
        case "trial": return "clock.fill"
        default: return "person.fill"
        }
    }
    private var tierTint: Color {
        switch currentTier {
        case "pro": return IATheme.accent
        case "plus": return IATheme.tertiary
        case "sandbox": return IATheme.warning
        case "trial": return IATheme.primaryContainer
        default: return IATheme.textSecondary
        }
    }

    // MARK: - Pricing

    private var plusPrice: String {
        resolvePrice(tier: "plus", fallbackMonthly: "$9.99/mo", fallbackYearly: "$79.99/yr")
    }
    private var proPrice: String {
        resolvePrice(tier: "pro", fallbackMonthly: "$19.99/mo", fallbackYearly: "$149.99/yr")
    }
    private var plusMonthlyEquivalent: String { "$6.67/mo" }
    private var proMonthlyEquivalent: String { "$12.50/mo" }

    private func resolvePrice(tier: String, fallbackMonthly: String, fallbackYearly: String) -> String {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        if let p = currentProducts.first(where: { $0.tier == tier && $0.productId.contains(period) }) {
            return p.displayPrice
        }
        if let p = currentProducts.first(where: { $0.tier == tier }) {
            return p.displayPrice
        }
        return billingPeriod == .yearly ? fallbackYearly : fallbackMonthly
    }

    private func storeProductId(for tier: String) -> String? {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        return currentProducts.first(where: { $0.tier == tier && $0.productId.contains(period) })?.productId
            ?? currentProducts.first(where: { $0.tier == tier })?.productId
    }

    // MARK: - Actions

    private func purchasePlan(tier: String) {
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
