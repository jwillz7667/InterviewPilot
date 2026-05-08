import Foundation

@Observable
final class ProfileService {
    static let shared = ProfileService()

    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    var errorMessage: String?

    private let apiClient = AuthenticatedAPIClient.shared
    private let profileCacheKey = "com.res.jobhopperAI.cached-profile"

    private init() {
        profile = loadCachedProfile()
    }

    func fetchProfile() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let fetched: UserProfile = try await apiClient.get("/api/v1/users/me/profile")
            apply(fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(_ updates: ProfileUpdate) async throws {
        let updated: UserProfile = try await apiClient.patch("/api/v1/users/me/profile", body: updates)
        apply(updated)
    }

    /// Single write path for fresh profile data from the backend. Persists to
    /// the in-memory store, the UserDefaults cache, and reconciles AuthService's
    /// display-name cache so all source-of-truth surfaces stay consistent.
    private func apply(_ fresh: UserProfile) {
        profile = fresh
        cacheProfile(fresh)
        AuthService.shared.updateCachedDisplayName(fresh.displayName)
    }

    func updateWorkExperience(_ entries: [WorkExperienceEntry]) async throws {
        let body = BulkItemsBody(items: entries)
        let _: EmptyResponse = try await apiClient.put("/api/v1/users/me/work-experience", body: body)
        profile?.workExperiences = entries
    }

    func updateSkills(_ skills: [SkillEntry]) async throws {
        let body = BulkItemsBody(items: skills.map(\.name))
        let _: EmptyResponse = try await apiClient.put("/api/v1/users/me/skills", body: body)
        profile?.skills = skills
    }

    var onboardingCompleted: Bool {
        profile?.onboardingCompleted ?? false
    }

    func reset() {
        profile = nil
        errorMessage = nil
        isLoading = false
        UserDefaults.standard.removeObject(forKey: profileCacheKey)
    }

    private func cacheProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileCacheKey)
        }
    }

    private func loadCachedProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileCacheKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
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
