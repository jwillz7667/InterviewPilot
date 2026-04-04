import Foundation

@Observable
final class ProfileListViewModel {
    var profiles: [InterviewProfileSummary] = []
    var isLoading = false
    var errorMessage: String?

    private let service = InterviewProfileService.shared

    var canAddProfile: Bool {
        SubscriptionService.shared.currentEntitlement?.canCreateProfile ?? false
    }

    var profileLimit: Int {
        SubscriptionService.shared.currentEntitlement?.profileLimit ?? 0
    }

    var profilesUsed: Int {
        SubscriptionService.shared.currentEntitlement?.profilesUsed ?? 0
    }

    var hasFeature: Bool {
        SubscriptionService.shared.currentEntitlement?.hasResumePersonalization ?? false
    }

    func loadProfiles() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        await service.fetchProfiles()
        profiles = service.profiles

        if let serviceError = service.errorMessage {
            errorMessage = serviceError
        }
    }

    func createProfile(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil

        do {
            _ = try await service.createProfile(CreateProfileInput(name: trimmed))
            profiles = service.profiles
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProfile(id: String) async {
        errorMessage = nil
        do {
            try await service.deleteProfile(id: id)
            profiles = service.profiles
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefault(id: String) async {
        errorMessage = nil
        do {
            try await service.setDefault(id: id)
            profiles = service.profiles
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
