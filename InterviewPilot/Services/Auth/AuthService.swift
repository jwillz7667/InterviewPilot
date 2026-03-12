import Foundation

struct AuthUser: Codable, Sendable {
    let id: String
    let email: String
    let displayName: String?
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

    private init() {
        restoreSession()
    }

    // MARK: - Session Restore (persistent login)

    private func restoreSession() {
        guard let token = KeychainService.load(key: .accessToken),
              let userId = KeychainService.load(key: .userId),
              let email = KeychainService.load(key: .userEmail) else {
            return
        }

        currentUser = AuthUser(
            id: userId,
            email: email,
            displayName: KeychainService.load(key: .displayName)
        )
        isAuthenticated = true

        // Fetch fresh API keys in background
        Task { await fetchAndStoreAPIKeys(token: token) }
    }

    // MARK: - Register

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

            storeAuthData(response)
            await fetchAndStoreAPIKeys(token: response.accessToken)
            isAuthenticated = true
            currentUser = response.user
        } catch {
            errorMessage = parseError(error)
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body: [String: String] = [
                "email": email,
                "password": password,
                "deviceId": deviceId(),
            ]

            let response: AuthResponse = try await post(
                path: "/api/v1/auth/login",
                body: body
            )

            storeAuthData(response)
            await fetchAndStoreAPIKeys(token: response.accessToken)
            isAuthenticated = true
            currentUser = response.user
        } catch {
            errorMessage = parseError(error)
        }
    }

    // MARK: - Logout

    func logout() async {
        if let refreshToken = KeychainService.load(key: .refreshToken),
           let accessToken = KeychainService.load(key: .accessToken) {
            let body = ["refreshToken": refreshToken]
            try? await post(
                path: "/api/v1/auth/logout",
                body: body,
                token: accessToken
            ) as [String: Bool]
        }

        clearAuthData()
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded() async -> String? {
        guard let refreshToken = KeychainService.load(key: .refreshToken) else { return nil }

        do {
            let response: TokenRefreshResponse = try await post(
                path: "/api/v1/auth/refresh",
                body: ["refreshToken": refreshToken]
            )

            _ = KeychainService.save(key: .accessToken, value: response.accessToken)
            _ = KeychainService.save(key: .refreshToken, value: response.refreshToken)

            return response.accessToken
        } catch {
            // Refresh failed — force re-login
            clearAuthData()
            isAuthenticated = false
            currentUser = nil
            return nil
        }
    }

    // MARK: - API Keys

    func fetchAndStoreAPIKeys(token: String? = nil) async {
        let authToken = token ?? KeychainService.load(key: .accessToken)
        guard let authToken else { return }

        do {
            let url = URL(string: "\(baseURL)/api/v1/config/api-keys")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired — try refresh
                if let newToken = await refreshTokenIfNeeded() {
                    await fetchAndStoreAPIKeys(token: newToken)
                }
                return
            }

            let keys = try JSONDecoder().decode(APIKeysResponse.self, from: data)
            _ = KeychainService.save(key: .deepgramAPIKey, value: keys.deepgramApiKey)
            _ = KeychainService.save(key: .openAIAPIKey, value: keys.openaiApiKey)
        } catch {
            // Non-fatal — keys may already be cached locally
        }
    }

    // MARK: - Authenticated Request Helper

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

    // MARK: - Private Helpers

    private func storeAuthData(_ response: AuthResponse) {
        _ = KeychainService.save(key: .accessToken, value: response.accessToken)
        _ = KeychainService.save(key: .refreshToken, value: response.refreshToken)
        _ = KeychainService.save(key: .userId, value: response.user.id)
        _ = KeychainService.save(key: .userEmail, value: response.user.email)
        if let displayName = response.user.displayName {
            _ = KeychainService.save(key: .displayName, value: displayName)
        }
    }

    private func clearAuthData() {
        _ = KeychainService.delete(key: .accessToken)
        _ = KeychainService.delete(key: .refreshToken)
        _ = KeychainService.delete(key: .userId)
        _ = KeychainService.delete(key: .userEmail)
        _ = KeychainService.delete(key: .displayName)
        _ = KeychainService.delete(key: .deepgramAPIKey)
        _ = KeychainService.delete(key: .openAIAPIKey)
    }

    private func deviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: "deviceId") {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "deviceId")
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

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorObj["message"] as? String {
                throw AuthError.serverError(message)
            }
            throw AuthError.serverError("Request failed (\(httpResponse.statusCode))")
        }

        return try JSONDecoder().decode(T.self, from: data)
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
        case .serverError(let message): return message
        }
    }
}
