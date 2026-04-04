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
        let response: ProfileEnvelope = try await apiClient.post("/api/v1/profiles", body: input)
        await fetchProfiles()
        return response.profile
    }

    func updateProfile(id: String, _ input: UpdateProfileInput) async throws -> InterviewProfile {
        let response: ProfileEnvelope = try await apiClient.patch("/api/v1/profiles/\(id)", body: input)
        await fetchProfiles()
        return response.profile
    }

    func deleteProfile(id: String) async throws {
        let _: SuccessEnvelope = try await apiClient.delete("/api/v1/profiles/\(id)")
        profiles.removeAll { $0.id == id }
    }

    func setDefault(id: String) async throws {
        let _: SuccessEnvelope = try await apiClient.post(
            "/api/v1/profiles/\(id)/set-default",
            body: EmptyBody()
        )
        await fetchProfiles()
    }

    // MARK: - Collection Updates

    func updateWorkExperiences(profileId: String, _ items: [ProfileWorkExperience]) async throws {
        let response: WorkExperienceItemsEnvelope = try await apiClient.put(
            "/api/v1/profiles/\(profileId)/work-experiences",
            body: BulkItems(items: items)
        )
        _ = response.items
    }

    func updateSkills(profileId: String, _ items: [ProfileSkillEntry]) async throws {
        let response: SkillItemsEnvelope = try await apiClient.put(
            "/api/v1/profiles/\(profileId)/skills",
            body: BulkItems(items: items)
        )
        _ = response.items
    }

    func updateEducation(profileId: String, _ items: [ProfileEducation]) async throws {
        let response: EducationItemsEnvelope = try await apiClient.put(
            "/api/v1/profiles/\(profileId)/education",
            body: BulkItems(items: items)
        )
        _ = response.items
    }

    func updateCertifications(profileId: String, _ items: [ProfileCertification]) async throws {
        let response: CertificationItemsEnvelope = try await apiClient.put(
            "/api/v1/profiles/\(profileId)/certifications",
            body: BulkItems(items: items)
        )
        _ = response.items
    }

    func updateProjects(profileId: String, _ items: [ProfileProject]) async throws {
        let response: ProjectItemsEnvelope = try await apiClient.put(
            "/api/v1/profiles/\(profileId)/projects",
            body: BulkItems(items: items)
        )
        _ = response.items
    }

    func updateAchievements(profileId: String, _ items: [ProfileAchievement]) async throws {
        let response: AchievementItemsEnvelope = try await apiClient.put(
            "/api/v1/profiles/\(profileId)/achievements",
            body: BulkItems(items: items)
        )
        _ = response.items
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

private struct BulkItems<T: Encodable>: Encodable {
    let items: T
}

private struct WorkExperienceItemsEnvelope: Decodable {
    let items: [ProfileWorkExperience]
}

private struct SkillItemsEnvelope: Decodable {
    let items: [ProfileSkillEntry]
}

private struct EducationItemsEnvelope: Decodable {
    let items: [ProfileEducation]
}

private struct CertificationItemsEnvelope: Decodable {
    let items: [ProfileCertification]
}

private struct ProjectItemsEnvelope: Decodable {
    let items: [ProfileProject]
}

private struct AchievementItemsEnvelope: Decodable {
    let items: [ProfileAchievement]
}
