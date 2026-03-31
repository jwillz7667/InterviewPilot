import SwiftUI

struct EmailAuthSheet: View {
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IATheme.surfaceWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: IATheme.spacing24) {
                        VStack(spacing: 8) {
                            Text(isRegistering ? "Create Account" : "Sign In with Email")
                                .font(IATypography.headlineLarge)
                                .foregroundStyle(IATheme.textPrimary)

                            Text(isRegistering ? "Set up your account to start live interview practice." : "Enter your credentials to continue.")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, IATheme.spacing24)

                        VStack(spacing: IATheme.spacing16) {
                            if isRegistering {
                                inputField(
                                    title: "Display Name",
                                    placeholder: "Your name",
                                    text: $displayName,
                                    icon: "person.text.rectangle"
                                )
                            }

                            inputField(
                                title: "Email",
                                placeholder: "name@company.com",
                                text: $email,
                                icon: "envelope.badge"
                            )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                            secureInputField(
                                title: "Password",
                                placeholder: "At least 8 characters",
                                text: $password,
                                icon: "lock.shield"
                            )
                        }

                        if let error = authService.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if authService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isRegistering ? "Create Account" : "Sign In")
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                            }
                        }
                        .buttonStyle(IAPrimaryButtonStyle(isEnabled: canSubmit && !authService.isLoading))
                        .disabled(!canSubmit || authService.isLoading)

                        Button(action: {
                            withAnimation(IAAnimations.standard) {
                                isRegistering.toggle()
                                authService.errorMessage = nil
                            }
                        }) {
                            Text(isRegistering ? "Already have an account? Sign In" : "Need an account? Sign Up")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.accent)
                        }
                    }
                    .padding(.horizontal, IATheme.spacing24)
                    .padding(.bottom, 40)
                }
                .iaScrollablePage()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8
    }

    private func submit() {
        Task {
            if isRegistering {
                await authService.register(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
            } else {
                await authService.login(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            if authService.isAuthenticated {
                dismiss()
            }
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IATheme.textSecondary)
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
    }

    private func secureInputField(title: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IATheme.textSecondary)
                    .frame(width: 20)

                SecureField(placeholder, text: text)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
    }
}
