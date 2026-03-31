import SwiftUI

struct DeleteAccountView: View {
    @State private var authService = AuthService.shared
    @State private var password = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showFinalConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        IAPanel(tone: .accent(IATheme.error), padding: 22, cornerRadius: 30) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(IATheme.error.opacity(0.14))
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(IATheme.error)
                                        }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Delete Account")
                                            .font(IATypography.headlineSmall)
                                            .foregroundStyle(IATheme.textPrimary)

                                        Text("This action is permanent and cannot be undone.")
                                            .font(IATypography.bodySmall)
                                            .foregroundStyle(IATheme.error)
                                    }
                                }

                                Text("Deleting your account will permanently remove all session history, prep banks, subscription data, and stored credentials. You will be signed out immediately.")
                                    .font(IATypography.bodyMedium)
                                    .foregroundStyle(IATheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Confirm your identity")
                                    .font(IATypography.headlineSmall)
                                    .foregroundStyle(IATheme.textPrimary)

                                Text("Enter your password to proceed with account deletion.")
                                    .font(IATypography.bodySmall)
                                    .foregroundStyle(IATheme.textSecondary)

                                SecureField("Password", text: $password)
                                    .font(IATypography.bodyMedium)
                                    .foregroundStyle(IATheme.textPrimary)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .iaInsetSurface(cornerRadius: 20)

                                if let errorMessage {
                                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                        .font(IATypography.bodySmall)
                                        .foregroundStyle(IATheme.error)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }

                                Button(action: { showFinalConfirm = true }) {
                                    HStack(spacing: 10) {
                                        if isDeleting {
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        Text("Delete My Account")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(IAPrimaryButtonStyle(isEnabled: canDelete && !isDeleting, tint: IATheme.error))
                                .disabled(!canDelete || isDeleting)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
            .confirmationDialog("Are you absolutely sure?", isPresented: $showFinalConfirm) {
                Button("Delete Account Permanently", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account, all session data, and sign you out. This cannot be undone.")
            }
        }
    }

    private var canDelete: Bool {
        password.count >= 8
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await authService.deleteAccount(password: password)
                await authService.logout()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isDeleting = false
        }
    }
}
