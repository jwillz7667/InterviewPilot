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

                                appleSignInButton

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
                    IPStatusPill(title: "Live Interview", symbol: "waveform.and.mic", tint: IPTheme.accent)
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

                        Text("Real-time interview assistance built for live in-call support with resume-aware answer guidance.")
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    featurePill("Resume aware", symbol: "doc.text.fill")
                    featurePill("Live guidance", symbol: "waveform.and.mic")
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

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = randomNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            handleAppleSignIn(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

            let formatter = PersonNameComponentsFormatter()
            let displayName = credential.fullName.flatMap { components -> String? in
                let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }

            Task {
                await authService.signInWithApple(
                    identityToken: identityToken,
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
