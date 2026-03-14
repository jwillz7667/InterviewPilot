import Foundation

@Observable
final class SettingsViewModel {
    var settings: UserSettingsSnapshot = .fallback
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?

    private let settingsService: UserSettingsService
    private var hasLoaded = false

    init(settingsService: UserSettingsService = .shared) {
        self.settingsService = settingsService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }

        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            settings = try await settingsService.fetchSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefaultInterviewType(_ type: InterviewType) async {
        await apply(
            optimistic: settings.updating(defaultInterviewType: type.rawValue),
            update: UserSettingsUpdate(defaultInterviewType: type.rawValue)
        )
    }

    func setDefaultResponseFormat(_ format: ResponseFormat) async {
        await apply(
            optimistic: settings.updating(defaultResponseFormat: format.rawValue),
            update: UserSettingsUpdate(defaultResponseFormat: format.rawValue)
        )
    }

    func setShouldPreGenerate(_ enabled: Bool) async {
        await apply(
            optimistic: settings.updating(shouldPreGenerate: enabled),
            update: UserSettingsUpdate(shouldPreGenerate: enabled)
        )
    }

    private func apply(
        optimistic updatedValue: UserSettingsSnapshot,
        update: UserSettingsUpdate
    ) async {
        let previousValue = settings
        settings = updatedValue
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            settings = try await settingsService.updateSettings(update)
        } catch {
            settings = previousValue
            errorMessage = error.localizedDescription
        }
    }
}

private extension UserSettingsSnapshot {
    func updating(
        defaultInterviewType: String? = nil,
        defaultResponseFormat: String? = nil,
        shouldPreGenerate: Bool? = nil
    ) -> UserSettingsSnapshot {
        UserSettingsSnapshot(
            defaultInterviewType: defaultInterviewType ?? self.defaultInterviewType,
            defaultResponseFormat: defaultResponseFormat ?? self.defaultResponseFormat,
            shouldPreGenerate: shouldPreGenerate ?? self.shouldPreGenerate
        )
    }
}
