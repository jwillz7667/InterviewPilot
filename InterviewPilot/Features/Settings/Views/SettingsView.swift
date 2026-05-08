import SwiftUI

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var viewModel: SettingsViewModel
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showPaywall = false
    @State private var showProfile = false
    @State private var showProfiles = false
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let loadOnTask: Bool
    private let previewUser: AuthUser?
    private let previewEntitlement: BillingEntitlement?

    init(
        viewModel: SettingsViewModel = SettingsViewModel(),
        loadOnTask: Bool = true,
        previewUser: AuthUser? = nil,
        previewEntitlement: BillingEntitlement? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.loadOnTask = loadOnTask
        self.previewUser = previewUser
        self.previewEntitlement = previewEntitlement
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        profilePreviewSection
                        quotaSummarySection
                        accountSettingsSection
                        supportSection
                        logoutSection
                        versionFooter
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                    .padding(.bottom, 40)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { await authService.logout() }
                }
            } message: {
                Text("You will need to sign in again to use the app.")
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileEditorView()
            }
            .sheet(isPresented: $showProfiles) {
                ProfileListView()
            }
            .sheet(isPresented: $showDeleteAccountConfirm) {
                DeleteAccountView()
            }
            .task {
                guard loadOnTask else { return }
                await viewModel.loadIfNeeded()
                await subscriptionService.refresh(forceStoreKitSync: true)
            }
        }
    }

    // MARK: - Profile Preview

    private var profilePreviewSection: some View {
        Button(action: { showProfile = true }) {
            HStack(spacing: 14) {
                IABrandLogo(size: 56, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentUser?.displayName ?? "Interview Ace User")
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)

                    if let email = currentUser?.email {
                        Text(email)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                    }

                    if let entitlement = currentEntitlement {
                        IAStatusPill(
                            title: entitlement.planTitle,
                            symbol: entitlement.sandboxFullAccess ? "checkmark.seal.fill" : "creditcard.fill",
                            tint: entitlement.sandboxFullAccess ? IATheme.success : IATheme.accent
                        )
                        .padding(.top, 4)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IATheme.textTertiary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .fill(IATheme.surfaceWhite)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quota Summary

    @ViewBuilder
    private var quotaSummarySection: some View {
        if let entitlement = currentEntitlement, !entitlement.sandboxFullAccess {
            VStack(alignment: .leading, spacing: 6) {
                Text("This Month")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                    .padding(.leading, 4)

                HStack(spacing: 10) {
                    quotaTile(
                        title: "Standard",
                        symbol: "bolt.fill",
                        tint: IATheme.accent,
                        window: entitlement.quotas.standard
                    )
                    quotaTile(
                        title: "Premium",
                        symbol: "sparkles",
                        tint: IATheme.tertiary,
                        window: entitlement.quotas.premium
                    )
                }

                Button(action: { showPaywall = true }) {
                    Text("Manage subscription")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.accent)
                }
                .padding(.top, 4)
                .padding(.leading, 4)
            }
        }
    }

    private func quotaTile(title: String, symbol: String, tint: Color, window: QuotaWindow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(IATypography.labelMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            if window.isUnlimited {
                Text("Unlimited")
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(IATheme.textPrimary)
            } else {
                Text("\(window.remaining)/\(window.limit)")
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(window.remaining <= 0 ? IATheme.error : IATheme.textPrimary)
            }

            Text(window.isUnlimited
                 ? "No cap on this engine"
                 : (window.remaining <= 0 ? "Used all available" : "left this period"))
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    // MARK: - Account Settings

    private var accountSettingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account Settings")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                IASettingsRow(icon: "creditcard.fill", iconColor: IATheme.tertiary, title: "Subscription & Billing") {
                    showPaywall = true
                }

                Divider().padding(.leading, 54)

                IASettingsRow(icon: "person.text.rectangle.fill", iconColor: IATheme.accent, title: "Edit Profile") {
                    showProfile = true
                }

                Divider().padding(.leading, 54)

                IASettingsRow(icon: "person.2.fill", iconColor: IATheme.tertiary, title: "Interview Profiles") {
                    showProfiles = true
                }

                Divider().padding(.leading, 54)

                NavigationLink(destination: ActiveSessionsView()) {
                    IASettingsRowLabel(icon: "lock.shield.fill", iconColor: IATheme.accent, title: "Active Sessions")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .fill(IATheme.surfaceWhite)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Support")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: HelpView()) {
                    IASettingsRowLabel(icon: "questionmark.circle.fill", iconColor: IATheme.accent, title: "Help & Support")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 54)

                NavigationLink(destination: LegalWebView(url: URL(string: "https://interviewpilot-production.up.railway.app/privacy")!, title: "Privacy Policy")) {
                    IASettingsRowLabel(icon: "hand.raised.fill", iconColor: IATheme.secondary, title: "Privacy Policy")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 54)

                NavigationLink(destination: LegalWebView(url: URL(string: "https://interviewpilot-production.up.railway.app/terms")!, title: "Terms of Service")) {
                    IASettingsRowLabel(icon: "doc.text.fill", iconColor: IATheme.secondary, title: "Terms of Service")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .fill(IATheme.surfaceWhite)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
    }

    // MARK: - Logout

    private var logoutSection: some View {
        VStack(spacing: 12) {
            Button(action: { showSignOutConfirm = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log Out")
                        .font(IATypography.bodyLarge)
                }
                .foregroundStyle(IATheme.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                        .fill(IATheme.error.opacity(0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                        .stroke(IATheme.error.opacity(0.2), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button(action: { showDeleteAccountConfirm = true }) {
                Text("Delete Account")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.error.opacity(0.7))
            }
        }
    }

    // MARK: - Version Footer

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Interview Ace AI")
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textTertiary)

            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, IATheme.spacing16)
    }

    private var currentUser: AuthUser? {
        previewUser ?? authService.currentUser
    }

    private var currentEntitlement: BillingEntitlement? {
        previewEntitlement ?? subscriptionService.currentEntitlement
    }
}

#Preview("Settings") {
    SettingsView(
        loadOnTask: false,
        previewUser: AuthUser(
            id: "1",
            email: "designer@example.com",
            displayName: "Jordan",
            appAccountToken: UUID().uuidString
        ),
        previewEntitlement: settingsPreviewEntitlement(tier: .pro)
    )
}

private func settingsPreviewEntitlement(tier: SubscriptionTier) -> BillingEntitlement {
    let isPremium = tier.canonicalDisplayTier == .premium
    let stdWindow = QuotaWindow(
        used: isPremium ? 0 : 5,
        limit: tier.defaultStandardQuota,
        remaining: tier.defaultStandardQuota < 0 ? 9_999 : max(tier.defaultStandardQuota - 5, 0),
        isUnlimited: tier.defaultStandardQuota < 0,
        resetsAt: nil
    )
    let premWindow = QuotaWindow(
        used: 0,
        limit: tier.defaultPremiumQuota,
        remaining: tier.defaultPremiumQuota < 0 ? 9_999 : tier.defaultPremiumQuota,
        isUnlimited: tier.defaultPremiumQuota < 0,
        resetsAt: nil
    )

    return BillingEntitlement(
        tier: tier,
        status: "active",
        accessSource: "preview",
        product: tier.rawValue,
        productId: tier.rawValue,
        features: ["live_interview", "session_history"],
        featureFlags: [
            "live_interview": true,
            "voice_prep": isPremium,
            "priority_models": tier.rank >= SubscriptionTier.pro.rank,
            "post_session_analysis": isPremium,
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
        trialDaysRemaining: nil,
        responseQuality: isPremium ? "premium" : "enhanced",
        monthlyInterviewsUsed: stdWindow.used,
        monthlyInterviewLimit: stdWindow.limit,
        monthlyInterviewsRemaining: stdWindow.remaining,
        quotas: QuotaSummary(
            standard: stdWindow,
            premium: premWindow,
            periodStartedAt: ISO8601DateFormatter().string(from: .now),
            periodEndsAt: nil
        ),
        catalog: []
    )
}
