import Foundation

@Observable
final class ProfileService {
    static let shared = ProfileService()

    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    var errorMessage: String?

    private let baseURL = AppEnvironment.backendBaseURL

    private init() {}

    func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            profile = try await get(path: "/api/v1/users/me/profile")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(_ updates: ProfileUpdate) async throws {
        let updated: UserProfile = try await patch(path: "/api/v1/users/me/profile", body: updates)
        profile = updated
    }

    func updateWorkExperience(_ entries: [WorkExperienceEntry]) async throws {
        let body = BulkItemsBody(items: entries)
        let _: EmptyResponse = try await put(path: "/api/v1/users/me/work-experience", body: body)
        profile?.workExperiences = entries
    }

    func updateSkills(_ skills: [SkillEntry]) async throws {
        let body = BulkItemsBody(items: skills.map(\.name))
        let _: EmptyResponse = try await put(path: "/api/v1/users/me/skills", body: body)
        profile?.skills = skills
    }

    var onboardingCompleted: Bool {
        profile?.onboardingCompleted ?? false
    }

    // MARK: - Networking

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let request = await AuthService.shared.authenticatedRequest(url: URL(string: "\(baseURL)\(path)")!) else {
            throw ProfileError.notAuthenticated
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func patch<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        guard var request = await AuthService.shared.authenticatedRequest(url: URL(string: "\(baseURL)\(path)")!) else {
            throw ProfileError.notAuthenticated
        }
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func put<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        guard var request = await AuthService.shared.authenticatedRequest(url: URL(string: "\(baseURL)\(path)")!) else {
            throw ProfileError.notAuthenticated
        }
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        if httpResponse.statusCode >= 400 {
            if let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorObj["message"] as? String {
                throw ProfileError.serverError(message)
            }
            throw ProfileError.serverError("Request failed (\(httpResponse.statusCode))")
        }
    }
}

struct ProfileUpdate: Codable, Sendable {
    var displayName: String?
    var linkedinUrl: String?
    var primaryGoal: String?
    var resumeFileUrl: String?
    var resumeText: String?
    var currentRole: String?
    var currentCompany: String?
    var yearsInRole: Int?
    var onboardingCompleted: Bool?
}

private struct BulkItemsBody<T: Encodable>: Encodable {
    let items: T
}

private struct EmptyResponse: Decodable {
    init(from decoder: Decoder) throws {}
}

enum ProfileError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let message):
            return message
        }
    }
}
