import SwiftUI

struct SubscriptionPaywallView: View {
    struct PreviewState {
        let entitlement: BillingEntitlement?
        let products: [SubscriptionStoreProduct]
        let isLoading: Bool
        let errorMessage: String?
    }

    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var billingPeriod: BillingPeriod = .monthly
    private let previewState: PreviewState?

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }

    init(previewState: PreviewState? = nil) {
        self.previewState = previewState
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        topUtilityBar
                        currentPlanCard

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        if isTrialActive {
                            trialBanner
                        }

                        if !isProTier {
                            plansSection
                            featureComparisonGrid
                        }

                        actionsSection
                        legalFooter
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                    .padding(.bottom, 30)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard previewState == nil else { return }
                await subscriptionService.refresh(forceStoreKitSync: true)
            }
        }
    }

    // MARK: - Top Utility Bar

    private var topUtilityBar: some View {
        HStack {
            HStack(spacing: 12) {
                IABrandLogo(size: 42, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Ace AI")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Subscription & Billing")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(IASecondaryButtonStyle())
        }
    }

    // MARK: - Current Plan Card

    private var currentPlanCard: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
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

                    if currentEntitlement?.sandboxFullAccess == true {
                        IAStatusPill(
                            title: "All Features",
                            symbol: "checkmark.seal.fill",
                            tint: IATheme.success
                        )
                    }
                }

                Text(planDisplayName)
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(IATheme.textPrimary)

                Text(planStatusDetail)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)

                if showUsageBar {
                    usageBar
                }
            }
        }
    }

    private var planDisplayName: String {
        guard let entitlement = currentEntitlement else { return "Free Plan" }
        switch entitlement.tier {
        case "pro": return "Interview Ace AI Pro"
        case "plus": return "Interview Ace AI Plus"
        case "sandbox": return "Sandbox (Developer)"
        case "trial": return "Free Trial"
        default: return "Free Plan"
        }
    }

    private var planStatusDetail: String {
        guard let entitlement = currentEntitlement else {
            return "3 interviews per month \u{2022} Standard AI responses"
        }

        switch entitlement.tier {
        case "free":
            return "3 interviews per month \u{2022} Standard AI responses"
        case "trial":
            let days = trialDaysRemaining
            return "\(days) day\(days == 1 ? "" : "s") remaining \u{2022} Full premium access"
        case "plus":
            let renewal = formattedRenewalDate ?? "active"
            return "Renews \(renewal) \u{2022} Enhanced AI responses"
        case "pro":
            let renewal = formattedRenewalDate ?? "active"
            return "Renews \(renewal) \u{2022} Premium AI responses"
        case "sandbox":
            return "Full feature access for sandbox testing"
        default:
            return entitlement.statusDetail
        }
    }

    private var showUsageBar: Bool {
        guard let entitlement = currentEntitlement else { return true }
        return !entitlement.hasActiveSubscription && !entitlement.sandboxFullAccess
    }

    private var usageBar: some View {
        Group {
            if let entitlement = currentEntitlement {
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
            } else {
                IAProgressBar(
                    progress: 0,
                    label: "Interviews used",
                    tint: IATheme.accent
                )

                Text("0 of 3 interviews used this month")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        GradientHeroCard(cornerRadius: IATheme.radiusLarge) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text(trialCountdownText)
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(.white)
                    }

                    Text("Subscribe now to keep your premium access")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer(minLength: 0)

                trialDaysCircle
            }
        }
    }

    private var trialDaysCircle: some View {
        let days = trialDaysRemaining
        return ZStack {
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 56, height: 56)
            VStack(spacing: 1) {
                Text("\(days)")
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(.white)
                Text("days")
                    .font(IATypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Plans Section

    private var plansSection: some View {
        VStack(spacing: 14) {
            IASectionHeader(
                eyebrow: nil,
                title: "Choose Your Plan",
                subtitle: nil,
                symbol: "sparkles"
            )

            billingToggle
            plusCard
            proCard
        }
    }

    private var billingToggle: some View {
        IAPanel(tone: .secondary, padding: 16, cornerRadius: 24) {
            HStack(spacing: 10) {
                Picker("Billing", selection: $billingPeriod) {
                    ForEach(BillingPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                if billingPeriod == .yearly {
                    Text("Save 33%")
                        .font(IATypography.labelSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(IATheme.success, in: Capsule())
                } else {
                    Text("Save 33%")
                        .font(IATypography.labelSmall)
                        .foregroundStyle(IATheme.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(IATheme.success.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private var plusCard: some View {
        let isCurrentPlan = currentTier == "plus"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plus")
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))

                    Text(plusPrice)
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.insetSurfaceSecondaryText(for: .light))
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plusFeatures, id: \.self) { feature in
                    featureRow(feature)
                }
            }

            if isCurrentPlan {
                currentPlanButton
            } else {
                Button(action: { purchasePlan(tier: "plus") }) {
                    Text("Choose Plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(subscriptionService.isPurchasing)
            }
        }
        .padding(18)
        .iaInsetSurface(selected: false, cornerRadius: 24)
    }

    private var proCard: some View {
        let isCurrentPlan = currentTier == "pro"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Pro")
                            .font(IATypography.headlineMedium)
                            .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))

                        IAStatusPill(title: "Most Popular", symbol: "star.fill", tint: IATheme.accent)
                    }

                    Text(proPrice)
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.insetSurfaceSecondaryText(for: .light))
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(proFeatures, id: \.self) { feature in
                    featureRow(feature)
                }
            }

            if isCurrentPlan {
                currentPlanButton
            } else {
                Button(action: { purchasePlan(tier: "pro") }) {
                    Text("Choose Pro")
                        .frame(maxWidth: .infinity)
                }
                .modifier(PaywallButtonModifier(isFeatured: true, isEnabled: !subscriptionService.isPurchasing))
                .disabled(subscriptionService.isPurchasing)
            }
        }
        .padding(18)
        .iaInsetSurface(selected: true, cornerRadius: 24)
    }

    private func featureRow(_ feature: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(IATheme.success)

            Text(feature)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))
        }
    }

    private var currentPlanButton: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(IATheme.success)

            Text("Current Plan")
                .font(IATypography.bodyLarge)
                .foregroundStyle(IATheme.success)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(IATheme.success.opacity(0.10), in: Capsule())
    }

    // MARK: - Feature Comparison Grid

    private var featureComparisonGrid: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                IASectionHeader(
                    eyebrow: "Comparison",
                    title: "Compare Plans",
                    subtitle: nil,
                    symbol: "list.bullet.rectangle.portrait"
                )

                HStack(spacing: 0) {
                    Text("Feature")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Plus")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textSecondary)
                        .frame(width: 64, alignment: .center)

                    Text("Pro")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.accent)
                        .frame(width: 64, alignment: .center)
                }
                .padding(.bottom, 4)

                Divider()

                comparisonRow("Interviews/month", plus: "Unlimited", pro: "Unlimited")
                comparisonRow("AI Model", plus: "GPT-4.1", pro: "GPT-4.1")
                comparisonRow("Max Tokens", plus: "400", pro: "480")
                comparisonRow("Resume Personalization", plusBool: true, proBool: true)
                comparisonRow("Response Formats", plusBool: true, proBool: true)
                comparisonRow("Voice Prep", plusBool: false, proBool: true)
                comparisonRow("Priority Models", plusBool: false, proBool: true)
                comparisonRow("Coding AI (o4-mini)", plusBool: false, proBool: true)
                comparisonRow("Session History", plusBool: true, proBool: true)
            }
        }
    }

    private func comparisonRow(_ feature: String, plus: String, pro: String) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(plus)
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textSecondary)
                .frame(width: 64, alignment: .center)

            Text(pro)
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.accent)
                .frame(width: 64, alignment: .center)
        }
        .padding(.vertical, 6)
    }

    private func comparisonRow(_ feature: String, plusBool: Bool, proBool: Bool) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            comparisonCheckmark(plusBool)
                .frame(width: 64, alignment: .center)

            comparisonCheckmark(proBool)
                .frame(width: 64, alignment: .center)
        }
        .padding(.vertical, 6)
    }

    private func comparisonCheckmark(_ available: Bool) -> some View {
        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(available ? IATheme.success : IATheme.textTertiary.opacity(0.5))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
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

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Text("Terms of Use")
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textSecondary)

                Text("Privacy Policy")
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Data Helpers

    private var currentEntitlement: BillingEntitlement? {
        previewState?.entitlement ?? subscriptionService.currentEntitlement
    }

    private var currentProducts: [SubscriptionStoreProduct] {
        previewState?.products ?? subscriptionService.products
    }

    private var isLoading: Bool {
        previewState?.isLoading ?? subscriptionService.isLoading
    }

    private var errorMessage: String? {
        previewState?.errorMessage ?? subscriptionService.errorMessage
    }

    private var currentTier: String {
        currentEntitlement?.tier ?? "free"
    }

    private var isProTier: Bool {
        currentTier == "pro" || currentTier == "sandbox"
    }

    private var isTrialActive: Bool {
        guard let entitlement = currentEntitlement else { return false }
        if let trialDays = entitlement.trialDaysRemaining, trialDays > 0 {
            return true
        }
        return entitlement.isInTrial && entitlement.trialInterviewsRemaining > 0
    }

    private var trialDaysRemaining: Int {
        if let days = currentEntitlement?.trialDaysRemaining {
            return max(days, 0)
        }
        return currentEntitlement?.trialInterviewsRemaining ?? 0
    }

    private var trialCountdownText: String {
        let days = trialDaysRemaining
        return "\(days) day\(days == 1 ? "" : "s") remaining in your free trial"
    }

    private var tierBadgeTitle: String {
        currentEntitlement?.planTitle ?? "Free"
    }

    private var tierBadgeSymbol: String {
        switch currentTier {
        case "pro": return "star.fill"
        case "plus": return "bolt.fill"
        case "sandbox": return "hammer.fill"
        case "trial": return "clock.fill"
        default: return "person.fill"
        }
    }

    private var tierBadgeTint: Color {
        switch currentTier {
        case "pro": return IATheme.accent
        case "plus": return IATheme.tertiary
        case "sandbox": return IATheme.warning
        case "trial": return IATheme.primaryContainer
        default: return IATheme.textSecondary
        }
    }

    private var formattedRenewalDate: String? {
        guard let iso = currentEntitlement?.currentPeriodEndsAt,
              let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Pricing Helpers

    private var plusPrice: String {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        if let product = currentProducts.first(where: {
            $0.tier == "plus" && $0.productId.contains(period)
        }) {
            return product.displayPrice
        }
        // Fall back: try any plus product
        if let product = currentProducts.first(where: { $0.tier == "plus" }) {
            return product.displayPrice
        }
        return billingPeriod == .yearly ? "$79.99/yr" : "$9.99/mo"
    }

    private var proPrice: String {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        if let product = currentProducts.first(where: {
            $0.tier == "pro" && $0.productId.contains(period)
        }) {
            return product.displayPrice
        }
        if let product = currentProducts.first(where: { $0.tier == "pro" }) {
            return product.displayPrice
        }
        return billingPeriod == .yearly ? "$149.99/yr" : "$19.99/mo"
    }

    private func storeProductId(for tier: String) -> String? {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        if let product = currentProducts.first(where: {
            $0.tier == tier && $0.productId.contains(period)
        }) {
            return product.productId
        }
        return currentProducts.first(where: { $0.tier == tier })?.productId
    }

    private let plusFeatures = [
        "Unlimited interviews",
        "Enhanced AI (GPT-4.1)",
        "400 token responses",
        "Resume personalization",
        "All response formats",
        "Full session history",
    ]

    private let proFeatures = [
        "Unlimited interviews",
        "Enhanced AI (GPT-4.1)",
        "480 token responses",
        "Resume personalization",
        "All response formats",
        "Full session history",
        "Coding AI (o4-mini)",
        "Voice prep sessions",
        "Priority models",
    ]

    // MARK: - Actions

    private func purchasePlan(tier: String) {
        guard previewState == nil else { return }
        guard let productId = storeProductId(for: tier) else {
            subscriptionService.errorMessage = "Subscription products are not available on this device. Configure them in App Store Connect."
            return
        }
        Task {
            do {
                try await subscriptionService.purchase(productId: productId)
                dismiss()
            } catch {
                subscriptionService.errorMessage = error.localizedDescription
            }
        }
    }

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

// MARK: - Button Modifier

private struct PaywallButtonModifier: ViewModifier {
    let isFeatured: Bool
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isFeatured {
            content.buttonStyle(IAPrimaryButtonStyle(isEnabled: isEnabled))
        } else {
            content.buttonStyle(IASecondaryButtonStyle())
        }
    }
}

// MARK: - Previews

#Preview("Free User") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "free"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("Trial User") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "trial"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("Plus Subscriber") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "plus"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("Pro Subscriber") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "pro"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("No Products (StoreKit unavailable)") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "free"),
            products: [],
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("Sandbox") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: BillingEntitlement(
                tier: "sandbox",
                status: "active",
                accessSource: "developer_override",
                product: "developer_override",
                productId: nil,
                features: ["live_interview", "voice_prep", "priority_models"],
                featureFlags: ["live_interview": true, "voice_prep": true, "priority_models": true],
                sandboxFullAccess: true,
                trialInterviewLimit: 0,
                trialInterviewsUsed: 0,
                interviewsRemaining: 9999,
                hasActiveSubscription: true,
                paywallRequired: false,
                appAccountToken: UUID().uuidString,
                currentPeriodEndsAt: nil,
                gracePeriodEndsAt: nil,
                trialDaysRemaining: nil,
                responseQuality: "premium",
                monthlyInterviewsUsed: 3,
                monthlyInterviewLimit: 999,
                monthlyInterviewsRemaining: 996,
                catalog: []
            ),
            products: [],
            isLoading: false,
            errorMessage: nil
        )
    )
}

private func previewEntitlement(tier: String) -> BillingEntitlement {
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

private func previewProducts() -> [SubscriptionStoreProduct] {
    [
        SubscriptionStoreProduct(
            id: "plus_monthly",
            productId: "plus_monthly",
            tier: "plus",
            displayName: "Interview Ace AI Plus",
            displayPrice: "$9.99/mo",
            billingLabel: "$9.99/mo",
            features: ["live_interview", "session_history", "resume_personalization", "response_formats"],
            description: "Unlimited live interviews with history and personalized response guidance."
        ),
        SubscriptionStoreProduct(
            id: "plus_yearly",
            productId: "plus_yearly",
            tier: "plus",
            displayName: "Interview Ace AI Plus (Yearly)",
            displayPrice: "$79.99/yr",
            billingLabel: "$79.99/yr",
            features: ["live_interview", "session_history", "resume_personalization", "response_formats"],
            description: "Unlimited live interviews with history and personalized response guidance."
        ),
        SubscriptionStoreProduct(
            id: "pro_monthly",
            productId: "pro_monthly",
            tier: "pro",
            displayName: "Interview Ace AI Pro",
            displayPrice: "$19.99/mo",
            billingLabel: "$19.99/mo",
            features: ["live_interview", "session_history", "resume_personalization", "response_formats", "voice_prep", "priority_models"],
            description: "Adds voice prep, Top Tier answer mode, and the full premium interview workflow."
        ),
        SubscriptionStoreProduct(
            id: "pro_yearly",
            productId: "pro_yearly",
            tier: "pro",
            displayName: "Interview Ace AI Pro (Yearly)",
            displayPrice: "$149.99/yr",
            billingLabel: "$149.99/yr",
            features: ["live_interview", "session_history", "resume_personalization", "response_formats", "voice_prep", "priority_models"],
            description: "Adds voice prep, Top Tier answer mode, and the full premium interview workflow."
        ),
    ]
}
