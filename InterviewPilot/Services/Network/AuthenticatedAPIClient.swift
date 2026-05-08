import Foundation

struct APIClientErrorEnvelope: Decodable {
    let error: String?
    let message: String?
}

enum APIClientError: LocalizedError {
    case invalidURL
    case unauthenticated
    case paymentRequired(String)
    case forbidden(String)
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .unauthenticated:
            return "Please sign in again."
        case .paymentRequired(let message):
            return message
        case .forbidden(let message):
            return message
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

final class AuthenticatedAPIClient {
    static let shared = AuthenticatedAPIClient()

    /// Dedicated session so timeouts apply only to authenticated REST traffic
    /// without affecting `URLSession.shared` (which is still used for streaming
    /// AI calls that legitimately run longer than 30s).
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }()

    private let authService: AuthService
    private let baseURL: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        authService: AuthService = .shared,
        baseURL: String = AppEnvironment.backendBaseURL
    ) {
        self.authService = authService
        self.baseURL = baseURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get<Response: Decodable>(
        _ path: String,
        expectedStatusCodes: Set<Int> = [200]
    ) async throws -> Response {
        let request = try await makeRequest(path: path, method: "GET")
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    func delete<Response: Decodable>(
        _ path: String,
        expectedStatusCodes: Set<Int> = [200]
    ) async throws -> Response {
        let request = try await makeRequest(path: path, method: "DELETE")
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        expectedStatusCodes: Set<Int> = [200],
        idempotencyKey: String? = nil
    ) async throws -> Response {
        var request = try await makeRequest(path: path, method: "POST", body: body)
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        expectedStatusCodes: Set<Int> = [200],
        idempotencyKey: String? = nil
    ) async throws -> Response {
        var request = try await makeRequest(path: path, method: "PUT", body: body)
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        expectedStatusCodes: Set<Int> = [200],
        idempotencyKey: String? = nil
    ) async throws -> Response {
        var request = try await makeRequest(path: path, method: "PATCH", body: body)
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    private func makeRequest(path: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIClientError.invalidURL
        }

        guard var request = await authService.authenticatedRequest(url: url) else {
            throw APIClientError.unauthenticated
        }

        request.httpMethod = method
        return request
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> URLRequest {
        var request = try await makeRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func perform<Response: Decodable>(
        request: URLRequest,
        expectedStatusCodes: Set<Int>,
        retryingUnauthorized: Bool = true
    ) async throws -> Response {
        let (data, response) = try await Self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401, retryingUnauthorized {
            guard let refreshedToken = await authService.refreshTokenIfNeeded() else {
                throw APIClientError.unauthenticated
            }

            var retriedRequest = request
            retriedRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            return try await perform(
                request: retriedRequest,
                expectedStatusCodes: expectedStatusCodes,
                retryingUnauthorized: false
            )
        }

        guard expectedStatusCodes.contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(APIClientErrorEnvelope.self, from: data)
            let message = apiError?.message ?? apiError?.error ?? "Request failed (\(httpResponse.statusCode))."
            switch httpResponse.statusCode {
            case 402:
                throw APIClientError.paymentRequired(message)
            case 403:
                throw APIClientError.forbidden(message)
            default:
                throw APIClientError.server(message)
            }
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.invalidResponse
        }
    }
}
