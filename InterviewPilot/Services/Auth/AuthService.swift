import Foundation

struct AuthUser: Codable, Sendable {
    let id: String
    let email: String
    let displayName: String?
    let appAccountToken: String
}

struct AuthResponse: Codable, Sendable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
}

struct TokenRefreshResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
}

struct APIKeysResponse: Codable, Sendable {
    let deepgramApiKey: String
    let openaiApiKey: String
}

@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var isAuthenticated: Bool = false
    private(set) var currentUser: AuthUser?
    private(set) var isLoading: Bool = false
    var errorMessage: String?
    private let baseURL = AppEnvironment.backendBaseURL
    private var activeRefreshTask: Task<String?, Never>?

    private init() {
        restoreSession()
    }

    private func restoreSession() {
        guard let token = KeychainService.load(key: .accessToken),
              let userId = KeychainService.load(key: .userId),
              let email = KeychainService.load(key: .userEmail),
              let appAccountToken = KeychainService.load(key: .appAccountToken) else {
            return
        }

        currentUser = AuthUser(
            id: userId,
            email: email,
            displayName: KeychainService.load(key: .displayName),
            appAccountToken: appAccountToken
        )
        isAuthenticated = true

        Task { await fetchAndStoreAPIKeys(token: token) }
    }

    func register(email: String, password: String, displayName: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var body: [String: String] = [
                "email": email,
                "password": password,
            ]
            if let displayName, !displayName.isEmpty {
                body["displayName"] = displayName
            }

            let response: AuthResponse = try await post(
                path: "/api/v1/auth/register",
                body: body
            )

            applyAuthenticatedSession(response)
        } catch {
            errorMessage = parseError(error)
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: AuthResponse = try await post(
                path: "/api/v1/auth/login",
                body: [
                    "email": email,
                    "password": password,
                    "deviceId": deviceId(),
                ]
            )

            applyAuthenticatedSession(response)
        } catch {
            errorMessage = parseError(error)
        }
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        nonce: String,
        displayName: String?
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var body: [String: String] = [
                "identityToken": identityToken,
                "nonce": nonce,
            ]
            if let authorizationCode, !authorizationCode.isEmpty {
                body["authorizationCode"] = authorizationCode
            }
            if let displayName, !displayName.isEmpty {
                body["displayName"] = displayName
            }

            let response: AuthResponse = try await post(
                path: "/api/v1/auth/apple",
                body: body
            )

            applyAuthenticatedSession(response)
        } catch {
            errorMessage = parseError(error)
        }
    }

    func logout() async {
        if let refreshToken = KeychainService.load(key: .refreshToken),
           let accessToken = KeychainService.load(key: .accessToken) {
            let body = ["refreshToken": refreshToken]
            _ = try? await post(
                path: "/api/v1/auth/logout",
                body: body,
                token: accessToken
            ) as [String: Bool]
        }

        clearAuthData()
        SessionStorageService.shared.deleteAllSessions()
        SubscriptionService.shared.reset()
        ProfileService.shared.reset()
        InterviewProfileService.shared.reset()
        SyncRetryQueue.shared.clear()
        clearUserDefaults()
        isAuthenticated = false
        currentUser = nil
    }

    private func clearUserDefaults() {
        let keysToRemove = [
            "linkedInProfileText",
            "additionalNotes",
            "hasSeenTrialExpiry",
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func requestPasswordReset(email: String) async throws {
        let body = ["email": email]
        let _: [String: String] = try await post(
            path: "/api/v1/auth/forgot-password",
            body: body
        )
    }

    func resetPassword(token: String, newPassword: String) async throws {
        let body = ["token": token, "password": newPassword]
        let _: [String: String] = try await post(
            path: "/api/v1/auth/reset-password",
            body: body
        )
    }

    func refreshTokenIfNeeded() async -> String? {
        // Coalesce concurrent refresh calls onto a single task
        if let existing = activeRefreshTask {
            return await existing.value
        }

        let task = Task<String?, Never> { [weak self] in
            guard let self else { return nil }
            defer { self.activeRefreshTask = nil }

            guard let refreshToken = KeychainService.load(key: .refreshToken) else { return nil }

            do {
                let response: TokenRefreshResponse = try await self.post(
                    path: "/api/v1/auth/refresh",
                    body: ["refreshToken": refreshToken]
                )

                _ = KeychainService.save(key: .accessToken, value: response.accessToken)
                _ = KeychainService.save(key: .refreshToken, value: response.refreshToken)

                return response.accessToken
            } catch {
                self.clearAuthData()
                SubscriptionService.shared.reset()
                self.isAuthenticated = false
                self.currentUser = nil
                return nil
            }
        }
        activeRefreshTask = task
        return await task.value
    }

    func fetchAndStoreAPIKeys(token: String? = nil) async {
        let authToken = token ?? KeychainService.load(key: .accessToken)
        guard let authToken else { return }

        do {
            let url = URL(string: "\(baseURL)/api/v1/config/api-keys")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 401 {
                if let newToken = await refreshTokenIfNeeded() {
                    await fetchAndStoreAPIKeys(token: newToken)
                }
                return
            }

            if httpResponse.statusCode == 402 || httpResponse.statusCode == 403 {
                if !applyDeveloperRuntimeKeysFallback() {
                    clearRuntimeKeys()
                }
                return
            }

            if httpResponse.statusCode >= 400 {
                throw AuthError.serverError(serverMessage(from: data, fallback: "Request failed (\(httpResponse.statusCode))"))
            }

            let keys = try JSONDecoder().decode(APIKeysResponse.self, from: data)
            _ = KeychainService.save(key: .deepgramAPIKey, value: keys.deepgramApiKey)
            _ = KeychainService.save(key: .openAIAPIKey, value: keys.openaiApiKey)
        } catch {
            _ = applyDeveloperRuntimeKeysFallback()
            // Preserve the last known keys on transient failures.
        }
    }

    func updateProfile(displayName: String) async throws {
        guard let token = KeychainService.load(key: .accessToken) else {
            throw AuthError.serverError("Not authenticated")
        }

        let _: [String: String] = try await post(
            path: "/api/v1/auth/profile",
            body: ["displayName": displayName],
            token: token
        )

        _ = KeychainService.save(key: .displayName, value: displayName)
        currentUser = AuthUser(
            id: currentUser?.id ?? "",
            email: currentUser?.email ?? "",
            displayName: displayName,
            appAccountToken: currentUser?.appAccountToken ?? ""
        )
    }

    func deleteAccount(password: String) async throws {
        guard let token = KeychainService.load(key: .accessToken) else {
            throw AuthError.serverError("Not authenticated")
        }

        let _: [String: String] = try await post(
            path: "/api/v1/auth/delete-account",
            body: ["password": password],
            token: token
        )
    }

    func authenticatedRequest(url: URL) async -> URLRequest? {
        var token = KeychainService.load(key: .accessToken)
        if token == nil {
            token = await refreshTokenIfNeeded()
        }
        guard let token else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func applyAuthenticatedSession(_ response: AuthResponse) {
        storeAuthData(response)
        isAuthenticated = true
        currentUser = response.user

        Task {
            await fetchAndStoreAPIKeys(token: response.accessToken)
        }
    }

    private func storeAuthData(_ response: AuthResponse) {
        _ = KeychainService.save(key: .accessToken, value: response.accessToken)
        _ = KeychainService.save(key: .refreshToken, value: response.refreshToken)
        _ = KeychainService.save(key: .userId, value: response.user.id)
        _ = KeychainService.save(key: .userEmail, value: response.user.email)
        _ = KeychainService.save(key: .appAccountToken, value: response.user.appAccountToken)
        if let displayName = response.user.displayName {
            _ = KeychainService.save(key: .displayName, value: displayName)
        }
    }

    private func clearRuntimeKeys() {
        _ = KeychainService.delete(key: .deepgramAPIKey)
        _ = KeychainService.delete(key: .openAIAPIKey)
    }

    var hasDeveloperFullAccess: Bool {
        AppEnvironment.hasDeveloperFullAccess(
            email: currentUser?.email ?? KeychainService.load(key: .userEmail)
        )
    }

    @discardableResult
    private func applyDeveloperRuntimeKeysFallback() -> Bool {
        // In DEBUG builds, always try developer keys from build config
        // so live sessions work during development without a paid subscription.
        // This does NOT grant sandbox subscription status — only provides API keys.
        #if DEBUG
        let canUseFallback = true
        #else
        let canUseFallback = hasDeveloperFullAccess
        #endif

        guard canUseFallback else { return false }

        if let deepgramAPIKey = AppEnvironment.developerDeepgramAPIKey {
            _ = KeychainService.save(key: .deepgramAPIKey, value: deepgramAPIKey)
        }

        if let openAIAPIKey = AppEnvironment.developerOpenAIAPIKey {
            _ = KeychainService.save(key: .openAIAPIKey, value: openAIAPIKey)
        }

        return KeychainService.hasKey(.deepgramAPIKey) && KeychainService.hasKey(.openAIAPIKey)
    }

    private func clearAuthData() {
        _ = KeychainService.delete(key: .accessToken)
        _ = KeychainService.delete(key: .refreshToken)
        _ = KeychainService.delete(key: .userId)
        _ = KeychainService.delete(key: .userEmail)
        _ = KeychainService.delete(key: .displayName)
        _ = KeychainService.delete(key: .appAccountToken)
        clearRuntimeKeys()
    }

    private func deviceId() -> String {
        // Migrate from UserDefaults if present
        if let legacyId = UserDefaults.standard.string(forKey: "deviceId") {
            _ = KeychainService.save(key: .deviceId, value: legacyId)
            UserDefaults.standard.removeObject(forKey: "deviceId")
            return legacyId
        }

        if let existing = KeychainService.load(key: .deviceId) {
            return existing
        }

        let id = UUID().uuidString
        _ = KeychainService.save(key: .deviceId, value: id)
        return id
    }

    private func post<T: Decodable>(
        path: String,
        body: [String: String],
        token: String? = nil
    ) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Invalid server response")
        }

        if httpResponse.statusCode >= 400 {
            if let routeError = missingRouteErrorMessage(
                path: path,
                data: data,
                statusCode: httpResponse.statusCode
            ) {
                throw AuthError.serverError(routeError)
            }

            throw AuthError.serverError(
                serverMessage(from: data, fallback: "Request failed (\(httpResponse.statusCode))")
            )
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func missingRouteErrorMessage(path: String, data: Data, statusCode: Int) -> String? {
        guard statusCode == 404 else { return nil }

        let message = serverMessage(from: data, fallback: "")
        guard message.contains("Route POST:\(path) not found") else { return nil }

        if path == "/api/v1/auth/apple" {
            return "Apple sign-in is not enabled on the deployed backend yet. Deploy the latest backend so POST \(path) exists."
        }

        return "The backend is missing POST \(path). Deploy the latest backend and try again."
    }

    private func serverMessage(from data: Data, fallback: String) -> String {
        if let errorObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = errorObject["message"] as? String {
            return message
        }

        return fallback
    }

    private func parseError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection"
            case .timedOut:
                return "Request timed out"
            case .cannotConnectToHost:
                return "Cannot connect to server"
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }

        return error.localizedDescription
    }
}

enum AuthError: LocalizedError {
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        }
    }
}
