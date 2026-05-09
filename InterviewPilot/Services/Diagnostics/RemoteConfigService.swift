import Foundation
import Observation

/// Pulls runtime config (Sentry DSN, App Attest enforcement flag) from the
/// backend. Cached in-memory; refetched on app launch and after sign-in.
@Observable
final class RemoteConfigService {
    static let shared = RemoteConfigService()

    struct Sentry: Codable {
        let dsn: String?
        let environment: String
        let tracesSampleRate: Double
    }

    struct AppAttest: Codable {
        let required: Bool
        let environment: String
    }

    struct Config: Codable {
        let sentry: Sentry
        let appAttest: AppAttest
    }

    private(set) var config: Config?

    @ObservationIgnored private let baseURL: String
    @ObservationIgnored private let session: URLSession

    private init(
        baseURL: String = AppEnvironment.backendBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    @discardableResult
    func refresh() async -> Config? {
        guard let url = URL(string: "\(baseURL)/api/v1/config") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(Config.self, from: data)
            config = decoded
            return decoded
        } catch {
            return nil
        }
    }
}
