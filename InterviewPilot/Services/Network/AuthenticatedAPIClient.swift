import Foundation

struct APIClientErrorEnvelope: Decodable {
    let error: String?
    let message: String?
}

enum APIClientError: LocalizedError {
    case invalidURL
    case unauthenticated
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .unauthenticated:
            return "Please sign in again."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

final class AuthenticatedAPIClient {
    static let shared = AuthenticatedAPIClient()

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
        expectedStatusCodes: Set<Int> = [200]
    ) async throws -> Response {
        let request = try await makeRequest(path: path, method: "POST", body: body)
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        expectedStatusCodes: Set<Int> = [200]
    ) async throws -> Response {
        let request = try await makeRequest(path: path, method: "PUT", body: body)
        return try await perform(request: request, expectedStatusCodes: expectedStatusCodes)
    }

    func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        expectedStatusCodes: Set<Int> = [200]
    ) async throws -> Response {
        let request = try await makeRequest(path: path, method: "PATCH", body: body)
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
        let (data, response) = try await URLSession.shared.data(for: request)
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
            throw APIClientError.server(
                apiError?.message ?? apiError?.error ?? "Request failed (\(httpResponse.statusCode))."
            )
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.invalidResponse
        }
    }
}
