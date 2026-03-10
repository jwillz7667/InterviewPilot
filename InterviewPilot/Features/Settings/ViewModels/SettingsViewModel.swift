import Foundation

@Observable
final class SettingsViewModel {
    // Settings are now managed server-side
    // API keys are fetched from the backend and cached in Keychain
    // This ViewModel is kept for future user preference settings

    var hasAPIKeys: Bool {
        KeychainService.hasKey(.deepgramAPIKey) && KeychainService.hasKey(.openAIAPIKey)
    }
}
