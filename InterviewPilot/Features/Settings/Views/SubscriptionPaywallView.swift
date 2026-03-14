import SwiftUI

struct SubscriptionPaywallView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        heroPanel

                        if let message = subscriptionService.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        productPanel
                        restorePanel
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.accentForeground)
                }
            }
            .task {
                await subscriptionService.refresh(forceStoreKitSync: true)
            }
        }
    }

    private var heroPanel: some View {
        IPPanel(tone: .accent(IPTheme.accent)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    IPStatusPill(title: currentPlanTitle, symbol: "creditcard.fill")
                    Spacer()
                    if let entitlement = subscriptionService.entitlement, entitlement.sandboxFullAccess {
                        IPStatusPill(title: "All Features", symbol: "checkmark.seal.fill", tint: IPTheme.success)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    IPBrandLogo(size: 56, cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unlock unlimited interview practice")
                            .font(IPTypography.headlineLarge)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text(heroSubtitle)
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var productPanel: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Plans",
                    title: "Subscription tiers",
                    subtitle: "Plus unlocks unlimited live interviews. Pro adds the full voice-prep workflow and premium AI modes.",
                    symbol: "sparkles.rectangle.stack"
                )

                if subscriptionService.isLoading && subscriptionService.products.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 12) {
                        ForEach(subscriptionService.products) { product in
                            productCard(product)
                        }
                    }
                }
            }
        }
    }

    private var restorePanel: some View {
        IPPanel {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                    Text(product.displayPrice)
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                }

                Spacer()

                IPStatusPill(
                    title: product.tier == "pro" ? "Pro" : "Plus",
                    symbol: product.tier == "pro" ? "person.wave.2.fill" : "waveform.and.mic",
                    tint: IPTheme.insetSurfacePrimaryText(for: colorScheme)
                )
            }

            Text(product.description)
                .font(IPTypography.bodySmall)
                .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))

            FlowLayout(spacing: 8) {
                ForEach(product.features, id: \.self) { feature in
                    Text(featureLabel(feature))
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(IPTheme.insetSurfaceBorder(for: colorScheme, selected: false), lineWidth: 1)
                        }
                }
            }

            Button(action: { purchase(product) }) {
                Text("Choose \(product.tier == "pro" ? "Pro" : "Plus")")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IPPrimaryButtonStyle(isEnabled: !subscriptionService.isPurchasing))
            .disabled(subscriptionService.isPurchasing)
        }
        .padding(16)
        .ipInsetSurface(selected: product.tier == "pro", cornerRadius: 20)
    }

    private var currentPlanTitle: String {
        subscriptionService.entitlement?.planTitle ?? "Job Hopper"
    }

    private var heroSubtitle: String {
        if let entitlement = subscriptionService.entitlement {
            return entitlement.statusDetail
        }

        return "New accounts include 5 free live interview sessions before a subscription is required."
    }

    private func purchase(_ product: SubscriptionStoreProduct) {
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
            return "Priority AI"
        default:
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
