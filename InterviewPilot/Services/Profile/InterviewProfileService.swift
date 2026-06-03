import Foundation

@Observable
final class InterviewProfileService {
    static let shared = InterviewProfileService()

    private(set) var profiles: [InterviewProfileSummary] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let apiClient = AuthenticatedAPIClient.shared

    private init() {}

    var defaultProfile: InterviewProfileSummary? {
        profiles.first(where: \.isDefault)
    }

    // MARK: - Profile CRUD

    func fetchProfiles() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let response: ProfileListEnvelope = try await apiClient.get("/api/v1/profiles")
            profiles = response.profiles
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchProfile(id: String) async throws -> InterviewProfile {
        let response: ProfileEnvelope = try await apiClient.get("/api/v1/profiles/\(id)")
        return response.profile
    }

    func createProfile(_ input: CreateProfileInput) async throws -> InterviewProfile {
        let response: ProfileEnvelope = try await apiClient.post(
            "/api/v1/profiles",
            body: input,
            expectedStatusCodes: [200, 201]
        )
        await fetchProfiles()
        return response.profile
    }

    /// Saves the entire profile — scalars and all six collections — in a single
    /// atomic request. This is the one write path for an interview profile:
    /// it replaces the old fan-out of a PATCH plus six per-collection PUTs, which
    /// could leave the profile half-written if any one call failed.
    func saveFullProfile(id: String, _ input: FullProfileInput) async throws -> InterviewProfile {
        let response: ProfileEnvelope = try await apiClient.put("/api/v1/profiles/\(id)/full", body: input)
        await fetchProfiles()
        return response.profile
    }

    func deleteProfile(id: String) async throws {
        let _: SuccessEnvelope = try await apiClient.delete("/api/v1/profiles/\(id)")
        profiles.removeAll { $0.id == id }
    }

    func setDefault(id: String) async throws {
        let _: ProfileEnvelope = try await apiClient.post(
            "/api/v1/profiles/\(id)/set-default",
            body: EmptyBody()
        )
        await fetchProfiles()
    }

    // MARK: - Reset

    func reset() {
        profiles = []
        errorMessage = nil
    }
}

// MARK: - Response Envelopes

private struct ProfileListEnvelope: Decodable {
    let profiles: [InterviewProfileSummary]
}

private struct ProfileEnvelope: Decodable {
    let profile: InterviewProfile
}

private struct SuccessEnvelope: Decodable {
    let success: Bool
}

private struct EmptyBody: Encodable {}
