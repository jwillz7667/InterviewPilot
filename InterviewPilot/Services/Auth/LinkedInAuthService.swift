import AuthenticationServices
import Foundation
import UIKit

/// Surfaces the result of a successful Sign In with LinkedIn (OpenID Connect)
/// flow. The backend exchanges the `code` for tokens — we never see the
/// `id_token` or `access_token` on device.
struct LinkedInAuthorizationResult: Sendable {
    let code: String
    let state: String
    let redirectURI: String
}

enum LinkedInAuthError: LocalizedError {
    case missingClientId
    case userCanceled
    case providerReturnedError(String)
    case stateMismatch
    case missingCode
    case presentationFailed

    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "LinkedIn sign in is unavailable right now. Please try again later."
        case .userCanceled:
            return "LinkedIn sign in was canceled."
        case .providerReturnedError(let detail):
            return "LinkedIn sign in failed: \(detail)"
        case .stateMismatch:
            return "LinkedIn sign in failed (state mismatch). Please retry."
        case .missingCode:
            return "LinkedIn did not return an authorization code."
        case .presentationFailed:
            return "Could not present the LinkedIn sign in screen."
        }
    }
}

/// Drives the user-facing portion of the LinkedIn OIDC flow:
///   1. Open `https://www.linkedin.com/oauth/v2/authorization` in
///      ASWebAuthenticationSession with `response_type=code`.
///   2. Capture the redirect to our app's custom URL scheme.
///   3. Verify CSRF `state`, surface the `code` to AuthService.
///
/// The backend then exchanges the code for tokens and finalizes the session.
@MainActor
final class LinkedInAuthService: NSObject {
    static let shared = LinkedInAuthService()

    private static let authorizationURL = URL(string: "https://www.linkedin.com/oauth/v2/authorization")!
    private static let scope = "openid profile email"

    private var activeSession: ASWebAuthenticationSession?

    /// Fetches the LinkedIn `client_id` from the backend `/config` endpoint.
    /// Cached for the process lifetime so repeated taps don't re-fetch.
    private var cachedClientID: String?

    private override init() {}

    func resetCache() {
        cachedClientID = nil
    }

    func authorize() async throws -> LinkedInAuthorizationResult {
        let clientID = try await fetchClientID()
        let redirectURI = AppEnvironment.linkedInRedirectURI
        let scheme = AppEnvironment.linkedInCallbackScheme
        let state = randomURLSafeToken(length: 32)

        guard var components = URLComponents(url: Self.authorizationURL, resolvingAgainstBaseURL: false) else {
            throw LinkedInAuthError.presentationFailed
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: Self.scope),
        ]

        guard let authURL = components.url else {
            throw LinkedInAuthError.presentationFailed
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LinkedInAuthorizationResult, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil

                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                        continuation.resume(throwing: LinkedInAuthError.userCanceled)
                    } else {
                        continuation.resume(throwing: LinkedInAuthError.providerReturnedError(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: LinkedInAuthError.missingCode)
                    return
                }

                do {
                    let result = try Self.parseCallback(
                        url: callbackURL,
                        expectedState: state,
                        redirectURI: redirectURI
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session

            if !session.start() {
                self.activeSession = nil
                continuation.resume(throwing: LinkedInAuthError.presentationFailed)
            }
        }
    }

    private static func parseCallback(
        url: URL,
        expectedState: String,
        redirectURI: String
    ) throws -> LinkedInAuthorizationResult {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw LinkedInAuthError.missingCode
        }
        let items = components.queryItems ?? []

        if let providerError = items.first(where: { $0.name == "error" })?.value {
            let description = items.first(where: { $0.name == "error_description" })?.value
            throw LinkedInAuthError.providerReturnedError(description ?? providerError)
        }

        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            throw LinkedInAuthError.stateMismatch
        }

        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw LinkedInAuthError.missingCode
        }

        return LinkedInAuthorizationResult(code: code, state: returnedState, redirectURI: redirectURI)
    }

    private func fetchClientID() async throws -> String {
        if let cachedClientID, !cachedClientID.isEmpty {
            return cachedClientID
        }

        guard let url = URL(string: "\(AppEnvironment.backendBaseURL)/api/v1/config") else {
            throw LinkedInAuthError.missingClientId
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw LinkedInAuthError.missingClientId
            }
            let decoded = try JSONDecoder().decode(ConfigResponse.self, from: data)
            guard let clientID = decoded.linkedin.clientId, !clientID.isEmpty, decoded.linkedin.enabled else {
                throw LinkedInAuthError.missingClientId
            }
            cachedClientID = clientID
            return clientID
        } catch let error as LinkedInAuthError {
            throw error
        } catch {
            throw LinkedInAuthError.missingClientId
        }
    }

    private func randomURLSafeToken(length: Int) -> String {
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var token = ""
        token.reserveCapacity(length)
        for _ in 0..<length {
            let idx = Int.random(in: 0..<charset.count)
            token.append(charset[idx])
        }
        return token
    }

    private struct ConfigResponse: Decodable {
        let linkedin: LinkedInConfig
    }

    private struct LinkedInConfig: Decodable {
        let clientId: String?
        let redirectUri: String
        let enabled: Bool
        let scope: String?
    }
}

extension LinkedInAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // ASWebAuthenticationSession invokes this on its own queue. Hop to the
        // main actor to read the active window scene safely. The protocol is
        // synchronous, so we use DispatchQueue.main.sync — acceptable here
        // because we're not in a re-entrant async context.
        if Thread.isMainThread {
            return MainActor.assumeIsolated { Self.activeAnchor() }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { Self.activeAnchor() }
        }
    }

    @MainActor
    fileprivate static func activeAnchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        if let key = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return key
        }
        if let firstWindow = scenes.flatMap(\.windows).first {
            return firstWindow
        }
        return ASPresentationAnchor()
    }
}
