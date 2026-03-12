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
                withAnimation(IPAnimations.hero) {
                    hasSeenOnboarding = true
                }
            }
        } else {
            loginForm
        }
    }

    private var loginForm: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing24) {
                        heroSection

                        IPPanel(tone: .accent(IPTheme.accent)) {
                            VStack(spacing: 18) {
                                if isRegistering {
                                    authField(
                                        title: "Display name",
                                        placeholder: "How should we label your sessions?",
                                        text: $displayName,
                                        icon: "person.text.rectangle"
                                    )
                                }

                                authField(
                                    title: "Email",
                                    placeholder: "name@company.com",
                                    text: $email,
                                    icon: "envelope.badge"
                                )
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)

                                secureAuthField(
                                    title: "Password",
                                    placeholder: "At least 8 characters",
                                    text: $password,
                                    icon: "lock.shield"
                                )

                                if let error = authService.errorMessage {
                                    Label(error, systemImage: "exclamationmark.triangle.fill")
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.error)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }

                                Button(action: submit) {
                                    HStack(spacing: 10) {
                                        if authService.isLoading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: isRegistering ? "person.crop.circle.badge.plus" : "arrow.right.circle.fill")
                                                .symbolEffect(.bounce, value: isRegistering)

                                            Text(isRegistering ? "Create Account" : "Sign In")
                                        }
                                    }
                                }
                                .buttonStyle(IPPrimaryButtonStyle(isEnabled: canSubmit && !authService.isLoading))
                                .disabled(!canSubmit || authService.isLoading)

                                Button(action: {
                                    withAnimation(IPAnimations.standard) {
                                        isRegistering.toggle()
                                        authService.errorMessage = nil
                                    }
                                }) {
                                    Text(isRegistering ? "Already have an account? Sign In" : "Need an account? Sign Up")
                                }
                                .buttonStyle(IPSecondaryButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing24)
                }
                .ipScrollablePage()
            }
        }
    }

    private var heroSection: some View {
        IPPanel(tone: .secondary) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    IPStatusPill(title: isRegistering ? "Create workspace" : "Secure sign in", symbol: "lock.fill")
                    Spacer()
                    IPStatusPill(title: "Live + Prep", symbol: "sparkles", tint: IPTheme.accentWarm)
                }

                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [IPTheme.accent, IPTheme.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)

                        Image(systemName: "mic.and.signal.meter.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, isActive: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("InterviewPilot")
                            .font(IPTypography.displayMedium)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text("Real-time interview assistance with a clean voice prep workflow and live in-call support.")
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    featurePill("Resume aware", symbol: "doc.text.fill")
                    featurePill("Realtime prep", symbol: "person.wave.2.fill")
                    featurePill("Low latency", symbol: "bolt.fill")
                }
            }
        }
    }

    private func featurePill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(IPTypography.labelSmall)
            .foregroundStyle(IPTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12), in: Capsule())
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

    private func authField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String
    ) -> some View {
        IPInputShell(icon: icon, title: title, subtitle: nil) {
            TextField(placeholder, text: text)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textPrimary)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func secureAuthField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String
    ) -> some View {
        IPInputShell(icon: icon, title: title, subtitle: nil) {
            SecureField(placeholder, text: text)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textPrimary)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
