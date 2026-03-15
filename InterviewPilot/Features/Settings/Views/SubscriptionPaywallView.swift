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
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        topUtilityBar
                        heroPanel

                        if let message = errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        plansPanel
                        restorePanel
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                    .padding(.bottom, 30)
                }
                .ipScrollablePage()
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
                IPBrandLogo(size: 42, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Job Hopper")
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Upgrade")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(IPSecondaryButtonStyle())
        }
    }

    private var heroPanel: some View {
        IPPanel(tone: .secondary, padding: 24, cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock unlimited\ninterview practice")
                            .font(IPTypography.displayMedium)
                            .foregroundStyle(IPTheme.textPrimary)
                            .lineSpacing(-2)

                        Text(heroSubtitle)
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)
                    IPStarburst(size: 36)
                        .padding(.top, 10)
                }

                HStack(spacing: 10) {
                    planPill(currentPlanTitle, symbol: "creditcard.fill")
                    if currentEntitlement?.sandboxFullAccess == true {
                        planPill("All Features", symbol: "checkmark.seal.fill", tint: IPTheme.success)
                    }
                }
            }
        }
    }

    private var plansPanel: some View {
        IPPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Plans",
                    title: "Choose your tier",
                    subtitle: "Plus unlocks unlimited live interviews. Pro adds voice prep and Top Tier answer mode.",
                    symbol: "sparkles.rectangle.stack"
                )

                if isLoading && currentProducts.isEmpty {
                    IPPanel(tone: .secondary, padding: 18, cornerRadius: 24) {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(IPTheme.accent)
                            Text("Loading subscription options...")
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(IPTheme.textSecondary)
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
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Already subscribed?")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                Text("Restore purchases to refresh your App Store entitlements on this device.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)

                Button(action: restorePurchases) {
                    Label("Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IPSecondaryButtonStyle())
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
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: .light))

                    Text(product.displayPrice)
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: .light))
                }

                Spacer()

                planPill(product.tier == "pro" ? "Pro" : "Plus", symbol: product.tier == "pro" ? "person.wave.2.fill" : "waveform.and.mic", tint: isFeatured ? IPTheme.accent : IPTheme.textSecondary)
            }

            Text(product.description)
                .font(IPTypography.bodySmall)
                .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: .light))

            FlowLayout(spacing: 8) {
                ForEach(product.features, id: \.self) { feature in
                    Text(featureLabel(feature))
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(isFeatured ? IPTheme.accent : IPTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background((isFeatured ? IPTheme.accent.opacity(0.10) : IPTheme.surfaceSecondary), in: Capsule())
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
        .ipInsetSurface(selected: isFeatured, cornerRadius: 24)
    }

    private var currentPlanTitle: String {
        currentEntitlement?.planTitle ?? "Job Hopper"
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

    private func planPill(_ title: String, symbol: String, tint: Color = IPTheme.accent) -> some View {
        Label(title, systemImage: symbol)
            .font(IPTypography.labelSmall)
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
                    displayName: "Job Hopper Plus",
                    displayPrice: "$19.99/mo",
                    billingLabel: "$19.99/mo",
                    features: ["live_interview", "session_history", "resume_personalization", "response_formats"],
                    description: "Unlimited live interviews with history and personalized response guidance."
                ),
                SubscriptionStoreProduct(
                    id: "pro",
                    productId: "pro",
                    tier: "pro",
                    displayName: "Job Hopper Pro",
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
            content.buttonStyle(IPPrimaryButtonStyle(isEnabled: isEnabled))
        } else {
            content.buttonStyle(IPSecondaryButtonStyle())
        }
    }
}
