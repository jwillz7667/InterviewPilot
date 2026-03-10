import SwiftUI

struct LoginView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var authService = AuthService.shared

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                withAnimation(IPAnimations.standard) {
                    hasSeenOnboarding = true
                }
            }
        } else {
            loginForm
        }
    }

    private var loginForm: some View {
        ZStack {
            Color(IPTheme.backgroundTop).ignoresSafeArea()

            ScrollView {
                VStack(spacing: IPTheme.spacing24) {
                    Spacer().frame(height: 40)

                    // Logo
                    VStack(spacing: IPTheme.spacing12) {
                        Image(systemName: "mic.badge.xmark")
                            .font(.system(size: 56))
                            .foregroundStyle(IPTheme.brand.gradient)

                        Text("InterviewPilot")
                            .font(IPTypography.headlineLarge)
                            .foregroundStyle(.white)

                        Text("Real-time AI interview assistant")
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.bottom, IPTheme.spacing16)

                    // Form
                    VStack(spacing: IPTheme.spacing16) {
                        if isRegistering {
                            formField(
                                icon: "person",
                                placeholder: "Display Name (optional)",
                                text: $displayName,
                                isSecure: false
                            )
                        }

                        formField(
                            icon: "envelope",
                            placeholder: "Email",
                            text: $email,
                            isSecure: false
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                        formField(
                            icon: "lock",
                            placeholder: "Password",
                            text: $password,
                            isSecure: true
                        )
                    }
                    .padding(.horizontal, IPTheme.spacing16)

                    // Error message
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, IPTheme.spacing16)
                    }

                    // Submit button
                    Button(action: submit) {
                        Group {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegistering ? "Create Account" : "Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canSubmit
                                ? AnyShapeStyle(IPTheme.brand.gradient)
                                : AnyShapeStyle(Color.white.opacity(0.1)),
                            in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium)
                        )
                    }
                    .disabled(!canSubmit || authService.isLoading)
                    .padding(.horizontal, IPTheme.spacing16)

                    // Toggle mode
                    Button(action: {
                        withAnimation(IPAnimations.standard) {
                            isRegistering.toggle()
                            authService.errorMessage = nil
                        }
                    }) {
                        Text(isRegistering
                             ? "Already have an account? **Sign In**"
                             : "Don't have an account? **Sign Up**")
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
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
        }
    }

    @ViewBuilder
    private func formField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool
    ) -> some View {
        HStack(spacing: IPTheme.spacing12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: text)
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            }
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
    }
}
