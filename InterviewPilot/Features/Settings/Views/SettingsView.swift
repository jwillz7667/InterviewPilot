import SwiftUI

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var viewModel: SettingsViewModel
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showPaywall = false
    @State private var showProfile = false
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
                        topUtilityBar
                        headerSection
                        accountSummaryPanel

                        if let error = viewModel.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        subscriptionSection
                        appearanceSection
                        aboutSection
                        accountDangerSection
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                    .padding(.bottom, 120)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                signOutDock
                    .padding(.horizontal, IATheme.spacing16)
                    .padding(.bottom, IATheme.spacing8)
            }
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

    private var topUtilityBar: some View {
        HStack {
            HStack(spacing: 12) {
                IABrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Ace AI")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Settings")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            IAUtilityCircleButton(symbol: "xmark") { dismiss() }
        }
    }

    private var headerSection: some View {
        IAPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Settings")
                    .font(IATypography.displayMedium)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Control appearance, prep defaults, and subscription details from a cleaner account surface.")
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accountSummaryPanel: some View {
        IAPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            HStack(spacing: 16) {
                IABrandLogo(size: 54, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentUser?.displayName ?? "Interview Ace AI User")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)

                    if let email = currentUser?.email {
                        Text(email)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                    }

                    if let entitlement = currentEntitlement {
                        Text(entitlement.statusDetail)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
        }
    }

    private var subscriptionSection: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Subscription")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                infoRow(
                    icon: "creditcard.fill",
                    title: currentEntitlement?.planTitle ?? "Trial",
                    detail: currentEntitlement?.statusDetail ?? "5 free live interviews are included for new accounts."
                )

                Button(action: { showPaywall = true }) {
                    Label(
                        currentEntitlement?.hasActiveSubscription == true ? "Manage Subscription" : "Upgrade to Continue",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IASecondaryButtonStyle())
            }
        }
    }

    private var appearanceSection: some View {
        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Appearance")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                ForEach(AppAppearance.allCases) { appearance in
                    Button(action: { appearanceRawValue = appearance.rawValue }) {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(currentAppearance == appearance ? IATheme.accentSelected : IATheme.surfaceTertiary)
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: appearance.symbol)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(
                                            currentAppearance == appearance
                                                ? Color.white
                                                : IATheme.insetSurfaceSecondaryText(for: colorScheme)
                                        )
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appearance.title)
                                    .font(IATypography.bodyLarge)
                                    .foregroundStyle(currentAppearance == appearance ? Color.white : IATheme.insetSurfacePrimaryText(for: colorScheme))
                                Text(appearance.subtitle)
                                    .font(IATypography.bodySmall)
                                    .foregroundStyle(currentAppearance == appearance ? Color.white : IATheme.insetSurfaceSecondaryText(for: colorScheme))
                            }

                            Spacer()

                            Image(systemName: currentAppearance == appearance ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    currentAppearance == appearance
                                        ? Color.white
                                        : IATheme.insetSurfaceTertiaryText(for: colorScheme)
                                )
                        }
                        .padding(16)
                        .iaInsetSurface(selected: currentAppearance == appearance, cornerRadius: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var currentAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var aboutSection: some View {
        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("About & Support")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Button(action: { showProfile = true }) {
                    infoRow(icon: "person.crop.circle.fill", title: "Profile", detail: "Display name, resume, and LinkedIn settings.")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HelpView()
                } label: {
                    infoRow(icon: "questionmark.circle.fill", title: "Help & FAQ", detail: "Common questions about live sessions and prep.")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LegalWebView(url: URL(string: "https://interviewpilot-production.up.railway.app/privacy")!, title: "Privacy Policy")
                } label: {
                    infoRow(icon: "hand.raised.fill", title: "Privacy Policy", detail: "How your data is handled.")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LegalWebView(url: URL(string: "https://interviewpilot-production.up.railway.app/terms")!, title: "Terms of Service")
                } label: {
                    infoRow(icon: "doc.text.fill", title: "Terms of Service", detail: "Usage agreement and conditions.")
                }
                .buttonStyle(.plain)

                infoRow(icon: "lock.shield.fill", title: "Security", detail: "Authentication tokens are stored in the iOS Keychain.")
            }
        }
    }

    private var accountDangerSection: some View {
        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Account")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Button(action: { showDeleteAccountConfirm = true }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(IATheme.error.opacity(0.10))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(IATheme.error)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account")
                                .font(IATypography.bodyLarge)
                                .foregroundStyle(IATheme.error)
                            Text("Permanently remove your account and all data.")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signOutDock: some View {
        IABottomDock {
            Button(action: { showSignOutConfirm = true }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: true))
        }
    }

    private var currentUser: AuthUser? {
        previewUser ?? authService.currentUser
    }

    private var currentEntitlement: BillingEntitlement? {
        previewEntitlement ?? subscriptionService.currentEntitlement
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(IATheme.accent.opacity(0.10))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textPrimary)
                Text(detail)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }

            Spacer()
        }
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
        previewEntitlement: settingsPreviewEntitlement(tier: "pro")
    )
}

private func settingsPreviewEntitlement(tier: String) -> BillingEntitlement {
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
