import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                IATheme.surfaceWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: IATheme.spacing24) {
                        // Header
                        VStack(spacing: IATheme.spacing8) {
                            Text("Reset Password")
                                .font(IATypography.headlineLarge)
                                .foregroundStyle(IATheme.textPrimary)

                            Text("Enter your email and we'll send you a link to reset your password.")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, IATheme.spacing24)

                        if showSuccess {
                            successContent
                        } else {
                            formContent
                        }

                        Spacer()
                    }
                    .padding(.horizontal, IATheme.spacing24)
                    .padding(.bottom, 40)
                }
                .iaScrollablePage()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
            }
        }
    }

    private var successContent: some View {
        VStack(spacing: IATheme.spacing16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 48))
                .foregroundStyle(IATheme.accent)

            Text("Check your email")
                .font(IATypography.headlineMedium)
                .foregroundStyle(IATheme.textPrimary)

            Text("If an account exists with that email, we've sent password reset instructions.")
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(IATheme.spacing24)
    }

    private var formContent: some View {
        VStack(spacing: IATheme.spacing16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)

                HStack(spacing: 10) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.textSecondary)
                        .frame(width: 20)

                    TextField("name@company.com", text: $email)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Button(action: { Task { await submitReset() } }) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Send Reset Link")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: isFormValid && !isLoading))
            .disabled(!isFormValid || isLoading)
        }
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitReset() async {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService.shared.requestPasswordReset(
                email: email.trimmingCharacters(in: .whitespaces)
            )
            withAnimation(IAAnimations.standard) {
                showSuccess = true
            }
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }
}
