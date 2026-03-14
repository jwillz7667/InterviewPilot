import SwiftUI

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showSignOutConfirm = false
    @State private var showPaywall = false
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        IPPanel(tone: .secondary) {
                            VStack(alignment: .leading, spacing: 18) {
                                IPSectionHeader(
                                    eyebrow: "Preferences",
                                    title: "Settings",
                                    subtitle: "Control app appearance and review account details without breaking the visual rhythm across screens.",
                                    symbol: "slider.horizontal.3"
                                )

                                if let user = authService.currentUser {
                                    HStack(spacing: 14) {
                                        IPBrandLogo(size: 54, cornerRadius: 18)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(user.displayName ?? "Job Hopper User")
                                                .font(IPTypography.headlineSmall)
                                                .foregroundStyle(IPTheme.textPrimary)

                                            Text(user.email)
                                                .font(IPTypography.bodyMedium)
                                                .foregroundStyle(IPTheme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }

                        IPPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Subscription")
                                    .font(IPTypography.headlineSmall)
                                    .foregroundStyle(IPTheme.textPrimary)

                                infoRow(
                                    icon: "creditcard.fill",
                                    title: subscriptionService.entitlement?.planTitle ?? "Trial",
                                    detail: subscriptionService.entitlement?.statusDetail ?? "5 free live interviews are included for new accounts."
                                )

                                Button(action: { showPaywall = true }) {
                                    Label(
                                        subscriptionService.entitlement?.hasActiveSubscription == true ? "Manage Subscription" : "Upgrade to Continue",
                                        systemImage: "sparkles"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(IPSecondaryButtonStyle())
                            }
                        }

                        IPPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Appearance")
                                    .font(IPTypography.headlineSmall)
                                    .foregroundStyle(IPTheme.textPrimary)

                                ForEach(AppAppearance.allCases) { appearance in
                                    Button(action: { appearanceRawValue = appearance.rawValue }) {
                                        HStack(spacing: 14) {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill((currentAppearance == appearance ? IPTheme.accent : IPTheme.surfaceTertiary).opacity(0.18))
                                                .frame(width: 42, height: 42)
                                                .overlay {
                                                    Image(systemName: appearance.symbol)
                                                        .font(.system(size: 17, weight: .semibold))
                                                        .foregroundStyle(
                                                            currentAppearance == appearance
                                                                ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
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
                                                        ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                                        : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                                )
                                        }
                                        .padding(14)
                                        .ipInsetSurface(selected: currentAppearance == appearance, cornerRadius: 18)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        IPPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("About")
                                    .font(IPTypography.headlineSmall)
                                    .foregroundStyle(IPTheme.textPrimary)

                                infoRow(icon: "lock.shield.fill", title: "Security", detail: "Authentication tokens are stored in the iOS Keychain.")
                                infoRow(icon: "antenna.radiowaves.left.and.right", title: "Connectivity", detail: "Live interview mode needs network access for transcription and response generation.")
                                infoRow(icon: "waveform.badge.magnifyingglass", title: "Speech stack", detail: "Live mode keeps the current interview audio pipeline and on-screen answer workflow.")
                            }
                        }

                        Button(action: { showSignOutConfirm = true }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IPPrimaryButtonStyle(isEnabled: true))
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.accent)
                }
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
                await subscriptionService.refresh(forceStoreKitSync: true)
            }
        }
    }

    private var currentAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(IPTheme.accent.opacity(0.10))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                Text(detail)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
            }

            Spacer()
        }
        .padding(14)
        .ipInsetSurface(cornerRadius: 18)
    }
}
