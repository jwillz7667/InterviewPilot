import AuthenticationServices
import CryptoKit
import SwiftUI

struct LoginView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var authService = AuthService.shared
    @State private var currentNonce = ""
    @State private var showEmailAuth = false
    @Environment(\.colorScheme) private var colorScheme

    private let hasSeenOnboardingOverride: Bool?

    init(hasSeenOnboardingOverride: Bool? = nil) {
        self.hasSeenOnboardingOverride = hasSeenOnboardingOverride
    }

    var body: some View {
        if !(hasSeenOnboardingOverride ?? hasSeenOnboarding) {
            OnboardingView {
                withAnimation(IAAnimations.hero) {
                    hasSeenOnboarding = true
                }
            }
        } else {
            signInScreen
        }
    }

    private var signInScreen: some View {
        ZStack {
            IATheme.surfaceWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    IABrandLogo(size: 80, showShadow: false, variant: .outlined)

                    VStack(spacing: 8) {
                        Text("Interview Ace")
                            .font(IATypography.displayLarge)
                            .foregroundStyle(IATheme.textPrimary)

                        Text("Real-time AI interview guidance\nthat helps you land the job.")
                            .font(IATypography.bodyLarge)
                            .foregroundStyle(IATheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                VStack(spacing: IATheme.spacing16) {
                    if let error = authService.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    appleSignInButton

                    linkedInSignInButton

                    Button(action: { showEmailAuth = true }) {
                        Text("Continue with Email")
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.accent)
                    }
                }
                .padding(.horizontal, IATheme.spacing24)

                Spacer()
                    .frame(height: 40)

                footer
                    .padding(.bottom, IATheme.spacing24)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthSheet()
        }
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
        .signInWithAppleButtonStyle(.black)
        .frame(height: 56)
        .clipShape(Capsule())
        .disabled(authService.isLoading)
    }

    /// LinkedIn brand uses #0A66C2; the button mirrors Apple's height and shape
    /// so the two CTAs read as a stacked pair, not two unrelated controls.
    private var linkedInSignInButton: some View {
        Button(action: handleLinkedInSignIn) {
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Continue with LinkedIn")
                    .font(IATypography.bodyMedium.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(red: 0.039, green: 0.400, blue: 0.761))
            .clipShape(Capsule())
        }
        .disabled(authService.isLoading)
        .accessibilityLabel("Sign in with LinkedIn")
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://interviewpilot-production.up.railway.app/terms")!)
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textTertiary)

                Text("|")
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textTertiary)

                Link("Privacy Policy", destination: URL(string: "https://interviewpilot-production.up.railway.app/privacy")!)
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textTertiary)
            }

            Text("\u{00A9} 2026 Interview Ace AI")
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textTertiary)
        }
    }

    private func handleLinkedInSignIn() {
        Task {
            await authService.signInWithLinkedIn()
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
}

#Preview("Login Light") {
    LoginView(hasSeenOnboardingOverride: true)
}

#Preview("Login Dark") {
    LoginView(hasSeenOnboardingOverride: true)
        .preferredColorScheme(.dark)
}
