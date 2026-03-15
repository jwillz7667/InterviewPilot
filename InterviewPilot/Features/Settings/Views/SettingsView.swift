import SwiftUI

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var viewModel: SettingsViewModel
    @State private var showSignOutConfirm = false
    @State private var showPaywall = false
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
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        topUtilityBar
                        headerSection
                        accountSummaryPanel

                        if let error = viewModel.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        subscriptionSection
                        preferencesSection
                        appearanceSection
                        aboutSection
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                    .padding(.bottom, 120)
                }
                .ipScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                signOutDock
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.bottom, IPTheme.spacing8)
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
                IPBrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Job Hopper")
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Settings")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }

            Spacer()

            IPUtilityCircleButton(symbol: "xmark") { dismiss() }
        }
    }

    private var headerSection: some View {
        IPPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Settings")
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)

                Text("Control appearance, prep defaults, and subscription details from a cleaner account surface.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accountSummaryPanel: some View {
        IPPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            HStack(spacing: 16) {
                IPBrandLogo(size: 54, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentUser?.displayName ?? "Job Hopper User")
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.textPrimary)

                    if let email = currentUser?.email {
                        Text(email)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textSecondary)
                    }

                    if let entitlement = currentEntitlement {
                        Text(entitlement.statusDetail)
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
        }
    }

    private var subscriptionSection: some View {
        IPPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Subscription")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

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
                .buttonStyle(IPSecondaryButtonStyle())
            }
        }
    }

    private var appearanceSection: some View {
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Appearance")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                ForEach(AppAppearance.allCases) { appearance in
                    Button(action: { appearanceRawValue = appearance.rawValue }) {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill((currentAppearance == appearance ? IPTheme.accent.opacity(0.12) : IPTheme.surfaceTertiary))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: appearance.symbol)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(
                                            currentAppearance == appearance
                                                ? IPTheme.accent
                                                : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                                        )
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appearance.title)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                Text(appearance.subtitle)
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                            }

                            Spacer()

                            Image(systemName: currentAppearance == appearance ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(
                                    currentAppearance == appearance
                                        ? IPTheme.accent
                                        : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                )
                        }
                        .padding(16)
                        .ipInsetSurface(selected: currentAppearance == appearance, cornerRadius: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var currentAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var preferencesSection: some View {
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Prep Defaults")
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.textPrimary)

                    Spacer()

                    if viewModel.isLoading || viewModel.isSaving {
                        ProgressView()
                            .tint(IPTheme.accent)
                    }
                }

                Text("Set the defaults that the prep dashboard should use before you customize a specific role.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Default interview track")
                        .font(IPTypography.labelMedium)
                        .foregroundStyle(IPTheme.textSecondary)

                    InterviewTypePickerView(selectedType: Binding(
                        get: { viewModel.settings.interviewType },
                        set: { type in
                            Task { await viewModel.setDefaultInterviewType(type) }
                        }
                    ))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Default answer layout")
                        .font(IPTypography.labelMedium)
                        .foregroundStyle(IPTheme.textSecondary)

                    ForEach(ResponseFormat.allCases, id: \.self) { format in
                        Button(action: {
                            Task { await viewModel.setDefaultResponseFormat(format) }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.settings.responseFormat == format ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(viewModel.settings.responseFormat == format ? IPTheme.accent : IPTheme.insetSurfaceTertiaryText(for: colorScheme))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(IPTypography.bodyLarge)
                                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    Text(format.description)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .ipInsetSurface(selected: viewModel.settings.responseFormat == format, cornerRadius: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(
                    isOn: Binding(
                        get: { viewModel.settings.shouldPreGenerate },
                        set: { enabled in
                            Task { await viewModel.setShouldPreGenerate(enabled) }
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-generate prep banks")
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                        Text("Prepare likely questions before you start a new session.")
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                    }
                }
                .tint(IPTheme.accent)
                .padding(16)
                .ipInsetSurface(cornerRadius: 22)
            }
        }
    }

    private var aboutSection: some View {
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Text("About")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                infoRow(icon: "lock.shield.fill", title: "Security", detail: "Authentication tokens are stored in the iOS Keychain.")
                infoRow(icon: "antenna.radiowaves.left.and.right", title: "Connectivity", detail: "Live interview mode needs network access for transcription and response generation.")
                infoRow(icon: "waveform.badge.magnifyingglass", title: "Speech stack", detail: "Live mode keeps the current interview audio pipeline and on-screen answer workflow.")
            }
        }
    }

    private var signOutDock: some View {
        IPBottomDock {
            Button(action: { showSignOutConfirm = true }) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IPPrimaryButtonStyle(isEnabled: true))
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
                .fill(IPTheme.accent.opacity(0.10))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IPTheme.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textPrimary)
                Text(detail)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
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
