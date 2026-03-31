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
                        topUtilityBar
                        heroPanel

                        if let message = errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        plansPanel
                        restorePanel
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

    private var heroPanel: some View {
        IAPanel(tone: .secondary, padding: 24, cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock unlimited\ninterview practice")
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

    private var plansPanel: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                IASectionHeader(
                    eyebrow: "Plans",
                    title: "Choose your tier",
                    subtitle: "Plus unlocks unlimited live interviews. Pro adds voice prep and Top Tier answer mode.",
                    symbol: "sparkles.rectangle.stack"
                )

                if isLoading && currentProducts.isEmpty {
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
                    VStack(spacing: 12) {
                        ForEach(currentProducts) { product in
                            productCard(product)
                        }
                    }
                }
            }
        }
    }

    private var restorePanel: some View {
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

    private func productCard(_ product: SubscriptionStoreProduct) -> some View {
        let isFeatured = product.tier == "pro"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))

                    Text(product.displayPrice)
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.insetSurfacePrimaryText(for: .light))
                }

                Spacer()

                planPill(product.tier == "pro" ? "Pro" : "Plus", symbol: product.tier == "pro" ? "person.wave.2.fill" : "waveform.and.mic", tint: isFeatured ? IATheme.accent : IATheme.textSecondary)
            }

            Text(product.description)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.insetSurfaceSecondaryText(for: .light))

            FlowLayout(spacing: 8) {
                ForEach(product.features, id: \.self) { feature in
                    Text(featureLabel(feature))
                        .font(IATypography.labelSmall)
                        .foregroundStyle(isFeatured ? IATheme.accent : IATheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((isFeatured ? IATheme.accent.opacity(0.10) : IATheme.surfaceSecondary), in: Capsule())
                }
            }

            Button(action: { purchase(product) }) {
                Text(isFeatured ? "Choose Pro" : "Choose Plus")
                    .frame(maxWidth: .infinity)
            }
            .modifier(PaywallButtonModifier(isFeatured: isFeatured, isEnabled: !subscriptionService.isPurchasing))
            .disabled(subscriptionService.isPurchasing)
        }
        .padding(18)
        .iaInsetSurface(selected: isFeatured, cornerRadius: 24)
    }

    private var currentPlanTitle: String {
        currentEntitlement?.planTitle ?? "Interview Ace AI"
    }

    private var heroSubtitle: String {
        if let entitlement = currentEntitlement {
            return entitlement.statusDetail
        }

        return "New accounts include 5 free live interview sessions before a subscription is required."
    }

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

    private func featureLabel(_ value: String) -> String {
        switch value {
        case "live_interview":
            return "Live interview"
        case "session_history":
            return "History"
        case "resume_personalization":
            return "Resume aware"
        case "response_formats":
            return "All formats"
        case "voice_prep":
            return "Voice Prep"
        case "priority_models":
            return "Top Tier mode"
        default:
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

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
            entitlement: previewEntitlement(tier: "plus"),
            products: [
                SubscriptionStoreProduct(
                    id: "plus",
                    productId: "plus",
                    tier: "plus",
                    displayName: "Interview Ace AI Plus",
                    displayPrice: "$19.99/mo",
                    billingLabel: "$19.99/mo",
                    features: ["live_interview", "session_history", "resume_personalization", "response_formats"],
                    description: "Unlimited live interviews with history and personalized response guidance."
                ),
                SubscriptionStoreProduct(
                    id: "pro",
                    productId: "pro",
                    tier: "pro",
                    displayName: "Interview Ace AI Pro",
                    displayPrice: "$39.99/mo",
                    billingLabel: "$39.99/mo",
                    features: ["live_interview", "session_history", "resume_personalization", "response_formats", "voice_prep", "priority_models"],
                    description: "Adds voice prep, Top Tier answer mode, and the full premium interview workflow."
                ),
            ],
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
        hasActiveSubscription: true,
        paywallRequired: false,
        appAccountToken: UUID().uuidString,
        currentPeriodEndsAt: ISO8601DateFormatter().string(from: .now.addingTimeInterval(60 * 60 * 24 * 30)),
        gracePeriodEndsAt: nil,
        catalog: []
    )
}

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
