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
                        heroSection

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        if isTrialActive {
                            trialBanner
                        }

                        billingToggle
                        tierCards
                        featureComparisonGrid
                        restoreSection
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

                    Text("Upgrade")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(IASecondaryButtonStyle())
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        IAPanel(tone: .secondary, padding: 24, cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock Your\nFull Potential")
                            .font(IATypography.displayMedium)
                            .foregroundStyle(IATheme.textPrimary)
                            .lineSpacing(-2)

                        Text(heroSubtitle)
                            .font(IATypography.bodyLarge)
                            .foregroundStyle(IATheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)
                    IAStarburst(size: 36)
                        .padding(.top, 10)
                }

                HStack(spacing: 10) {
                    planPill(currentPlanTitle, symbol: "creditcard.fill")
                    if currentEntitlement?.sandboxFullAccess == true {
                        planPill("All Features", symbol: "checkmark.seal.fill", tint: IATheme.success)
                    }
                }
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

    // MARK: - Billing Toggle

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

    // MARK: - Tier Cards

    private var tierCards: some View {
        VStack(spacing: 14) {
            if isLoading && filteredProducts.isEmpty {
                IAPanel(tone: .secondary, padding: 18, cornerRadius: 24) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(IATheme.accent)
                        Text("Loading subscription options...")
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }
            } else {
                ForEach(filteredProducts) { product in
                    tierCard(product)
                }
            }
        }
    }

    private func tierCard(_ product: SubscriptionStoreProduct) -> some View {
        let isPro = product.tier == "pro" || product.tier.contains("pro")
        let features = isPro ? proFeatures : plusFeatures

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isPro ? "Pro" : "Plus")
                            .font(IATypography.headlineMedium)
                            .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))

                        if isPro {
                            IAStatusPill(title: "Most Popular", symbol: "star.fill", tint: IATheme.accent)
                        }
                    }

                    Text(product.displayPrice)
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.insetSurfaceSecondaryText(for: .light))
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(IATheme.success)

                        Text(feature)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))
                    }
                }
            }

            Button(action: { purchase(product) }) {
                Text(isPro ? "Choose Pro" : "Choose Plus")
                    .frame(maxWidth: .infinity)
            }
            .modifier(PaywallButtonModifier(isFeatured: isPro, isEnabled: !subscriptionService.isPurchasing))
            .disabled(subscriptionService.isPurchasing)
        }
        .padding(18)
        .iaInsetSurface(selected: isPro, cornerRadius: 24)
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

                // Column headers
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

    // MARK: - Restore Section

    private var restoreSection: some View {
        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Already subscribed?")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Restore purchases to refresh your App Store entitlements on this device.")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)

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

    private var filteredProducts: [SubscriptionStoreProduct] {
        let period = billingPeriod == .yearly ? "yearly" : "monthly"
        let filtered = currentProducts.filter { product in
            product.productId.contains(period)
                || product.billingLabel.lowercased().contains(billingPeriod == .yearly ? "/yr" : "/mo")
        }
        // If no products match the period filter (e.g., products don't encode period in ID),
        // fall back to showing all products so the paywall is never empty.
        return filtered.isEmpty ? currentProducts : filtered
    }

    private var isLoading: Bool {
        previewState?.isLoading ?? subscriptionService.isLoading
    }

    private var errorMessage: String? {
        previewState?.errorMessage ?? subscriptionService.errorMessage
    }

    private var currentPlanTitle: String {
        currentEntitlement?.planTitle ?? "Interview Ace AI"
    }

    private var heroSubtitle: String {
        if let entitlement = currentEntitlement {
            if isTrialActive {
                let days = trialDaysRemaining
                return "You have \(days) day\(days == 1 ? "" : "s") left in your free trial. Subscribe to keep full access."
            }

            if entitlement.hasActiveSubscription {
                return "You're on the \(entitlement.planTitle) plan. Manage or upgrade your subscription."
            }

            return entitlement.statusDetail
        }

        return "Upgrade to unlock unlimited interviews, premium AI models, and more."
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

    private func planPill(_ title: String, symbol: String, tint: Color = IATheme.accent) -> some View {
        Label(title, systemImage: symbol)
            .font(IATypography.labelSmall)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.10), in: Capsule())
    }

    private func purchase(_ product: SubscriptionStoreProduct) {
        guard previewState == nil else { return }
        Task {
            do {
                try await subscriptionService.purchase(productId: product.productId)
                dismiss()
            } catch {
                subscriptionService.errorMessage = error.localizedDescription
            }
        }
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

#Preview("Paywall Loading") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: nil,
            products: [],
            isLoading: true,
            errorMessage: nil
        )
    )
}

#Preview("Paywall Products") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "free"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("Paywall Trial") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "trial"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

#Preview("Paywall Subscribed") {
    SubscriptionPaywallView(
        previewState: .init(
            entitlement: previewEntitlement(tier: "plus"),
            products: previewProducts(),
            isLoading: false,
            errorMessage: nil
        )
    )
}

private func previewEntitlement(tier: String) -> BillingEntitlement {
    BillingEntitlement(
        tier: tier,
        status: "active",
        accessSource: "preview",
        product: tier,
        productId: tier,
        features: ["live_interview", "session_history"],
        featureFlags: [
            "live_interview": true,
            "voice_prep": tier == "pro",
            "priority_models": tier == "pro",
        ],
        sandboxFullAccess: false,
        trialInterviewLimit: 5,
        trialInterviewsUsed: 2,
        interviewsRemaining: 3,
        hasActiveSubscription: tier == "plus" || tier == "pro",
        paywallRequired: tier == "free",
        appAccountToken: UUID().uuidString,
        currentPeriodEndsAt: ISO8601DateFormatter().string(from: .now.addingTimeInterval(60 * 60 * 24 * 30)),
        gracePeriodEndsAt: nil,
        trialDaysRemaining: tier == "trial" ? 5 : nil,
        responseQuality: tier == "pro" ? "premium" : (tier == "plus" ? "enhanced" : "standard"),
        monthlyInterviewsUsed: 2,
        monthlyInterviewLimit: tier == "free" ? 3 : 999,
        monthlyInterviewsRemaining: tier == "free" ? 1 : 997,
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
            displayPrice: "$19.99/mo",
            billingLabel: "$19.99/mo",
            features: ["live_interview", "session_history", "resume_personalization", "response_formats"],
            description: "Unlimited live interviews with history and personalized response guidance."
        ),
        SubscriptionStoreProduct(
            id: "pro_monthly",
            productId: "pro_monthly",
            tier: "pro",
            displayName: "Interview Ace AI Pro",
            displayPrice: "$39.99/mo",
            billingLabel: "$39.99/mo",
            features: ["live_interview", "session_history", "resume_personalization", "response_formats", "voice_prep", "priority_models"],
            description: "Adds voice prep, Top Tier answer mode, and the full premium interview workflow."
        ),
    ]
}
