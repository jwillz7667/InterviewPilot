import AuthenticationServices
import CryptoKit
import SwiftUI

struct LoginView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = false
    @State private var authService = AuthService.shared
    @State private var currentNonce = ""
    @Environment(\.colorScheme) private var colorScheme

    private let hasSeenOnboardingOverride: Bool?

    init(hasSeenOnboardingOverride: Bool? = nil) {
        self.hasSeenOnboardingOverride = hasSeenOnboardingOverride
    }

    var body: some View {
        if !(hasSeenOnboardingOverride ?? hasSeenOnboarding) {
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
                    VStack(alignment: .leading, spacing: IPTheme.spacing24) {
                        topUtilityBar
                        heroSection
                        credentialsPanel
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.top, IPTheme.spacing20)
                    .padding(.bottom, 40)
                }
                .ipScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var topUtilityBar: some View {
        HStack {
            HStack(spacing: 12) {
                IPBrandLogo(size: 42, showShadow: false, variant: .filled)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Job Hopper")
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text(isRegistering ? "Create account" : "Secure sign in")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }

            Spacer()

            IPStatusPill(
                title: isRegistering ? "Create account" : "Secure sign in",
                symbol: isRegistering ? "person.crop.circle.badge.plus" : "lock.fill"
            )
        }
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Job Hopper")
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)

                Text("Real-time interview support with role-aware prompts, low-latency response guidance, and post-call review.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    featurePill("Resume aware", symbol: "doc.text")
                    featurePill("Live guidance", symbol: "waveform")
                    featurePill("Instant review", symbol: "chart.xyaxis.line")
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 12) {
                IPStarburst(size: 42)
                IPBrandLogo(size: 72, variant: .surface)
            }
        }
    }

    private var credentialsPanel: some View {
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                Text(isRegistering ? "Create your workspace" : "Welcome back")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                Text(isRegistering ? "Set up your account to start live interview practice." : "Sign in to continue into your interview dashboard.")
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(IPTheme.textSecondary)

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
                        .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button(action: submit) {
                    HStack(spacing: 10) {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isRegistering ? "Create Account" : "Sign In")
                            Image(systemName: isRegistering ? "arrow.up.right.circle.fill" : "arrow.right.circle.fill")
                        }
                    }
                }
                .buttonStyle(IPPrimaryButtonStyle(isEnabled: canSubmit && !authService.isLoading))
                .disabled(!canSubmit || authService.isLoading)

                appleSignInButton

                Button(action: {
                    withAnimation(IPAnimations.standard) {
                        isRegistering.toggle()
                        authService.errorMessage = nil
                    }
                }) {
                    Text(isRegistering ? "Already have an account? Sign In" : "Need an account? Sign Up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IPSecondaryButtonStyle())
            }
        }
    }

    private func featurePill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(IPTypography.labelSmall)
            .foregroundStyle(IPTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.85), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
            }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = randomNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            handleAppleSignIn(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .disabled(authService.isLoading)
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

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                authService.errorMessage = "Apple did not return a valid identity token."
                return
            }
            let authorizationCode = credential.authorizationCode.flatMap { code in
                String(data: code, encoding: .utf8)
            }

            let formatter = PersonNameComponentsFormatter()
            let displayName = credential.fullName.flatMap { components -> String? in
                let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }

            Task {
                await authService.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nonce: currentNonce,
                    displayName: displayName
                )
            }
        case .failure(let error):
            authService.errorMessage = error.localizedDescription
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var nonce = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength > 0 && random < charset.count {
                    nonce.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return nonce
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
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
                .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .ipInsetSurface(cornerRadius: 20)
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
                .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .ipInsetSurface(cornerRadius: 20)
        }
    }
}

#Preview("Login Light") {
    LoginView(hasSeenOnboardingOverride: true)
}

#Preview("Login Dark") {
    LoginView(hasSeenOnboardingOverride: true)
        .preferredColorScheme(.dark)
}
