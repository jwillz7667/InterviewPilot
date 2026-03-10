import SwiftUI

struct SettingsView: View {
    @State private var authService = AuthService.shared
    @State private var showSignOutConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(IPTheme.backgroundTop).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: IPTheme.spacing16) {
                        // Account Section
                        VStack(alignment: .leading, spacing: IPTheme.spacing16) {
                            Text("Account")
                                .font(IPTypography.headlineSmall)
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: IPTheme.spacing12) {
                                if let user = authService.currentUser {
                                    accountRow(
                                        icon: "person.circle.fill",
                                        title: user.displayName ?? "User",
                                        detail: user.email
                                    )
                                }

                                accountRow(
                                    icon: "checkmark.shield.fill",
                                    title: "Status",
                                    detail: "Signed in"
                                )
                            }
                        }
                        .padding(.horizontal, IPTheme.spacing16)

                        // Info section
                        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
                            Text("About")
                                .font(IPTypography.headlineSmall)
                                .foregroundStyle(.white)

                            infoRow(icon: "lock.shield.fill", title: "Security", detail: "Auth tokens stored in iOS Keychain")
                            infoRow(icon: "wifi", title: "Network", detail: "Requires internet for live sessions")
                            infoRow(icon: "server.rack", title: "AI Services", detail: "Powered by Deepgram Nova-3 & OpenAI GPT-4.1")
                        }
                        .padding(.horizontal, IPTheme.spacing16)

                        // Sign Out
                        Button(action: { showSignOutConfirm = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(IPTheme.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(IPTheme.error.opacity(0.1), in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
                        }
                        .padding(.horizontal, IPTheme.spacing16)
                        .padding(.top, IPTheme.spacing8)
                    }
                    .padding(.top, IPTheme.spacing16)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.brandLight)
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { await authService.logout() }
                }
            } message: {
                Text("You will need to sign in again to use the app.")
            }
        }
    }

    private func accountRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: IPTheme.spacing12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(IPTheme.brand)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(IPTypography.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusLarge))
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: IPTheme.spacing12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(IPTheme.brandLight)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(IPTheme.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
    }
}
