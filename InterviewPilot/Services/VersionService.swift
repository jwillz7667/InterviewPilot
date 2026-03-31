import Foundation

@Observable
final class VersionService {
    static let shared = VersionService()

    private(set) var requiresUpdate = false

    func checkVersion() async {
        guard let url = URL(string: "\(AppEnvironment.backendBaseURL)/api/v1/config/app-version") else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let config = try JSONDecoder().decode(AppVersionConfig.self, from: data)

            guard config.forceUpdate else { return }

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

            if isVersion(currentVersion, lessThan: config.minVersion) {
                requiresUpdate = true
            }
        } catch {
            // Silently skip — backend endpoint may not exist yet
        }
    }

    private func isVersion(_ current: String, lessThan minimum: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let minimumParts = minimum.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(currentParts.count, minimumParts.count)

        for i in 0..<maxLength {
            let c = i < currentParts.count ? currentParts[i] : 0
            let m = i < minimumParts.count ? minimumParts[i] : 0

            if c < m { return true }
            if c > m { return false }
        }

        return false
    }
}

private struct AppVersionConfig: Decodable {
    let minVersion: String
    let forceUpdate: Bool
}
