import Foundation

struct AuthSession: Identifiable, Decodable, Hashable {
    let deviceId: String?
    let userAgent: String?
    let createdAt: Date
    let lastUsedAt: Date
    let current: Bool

    var id: String { deviceId ?? userAgent ?? createdAt.ISO8601Format() }

    /// Best-effort human label parsed from the User-Agent header.
    /// Falls back to "Unknown device" so the row always renders something.
    var deviceLabel: String {
        if current { return "This device" }
        guard let ua = userAgent, !ua.isEmpty else { return "Unknown device" }

        if ua.contains("iPad") { return "iPad" }
        if ua.contains("iPhone") { return "iPhone" }
        if ua.contains("Macintosh") || ua.contains("Mac OS X") { return "Mac" }
        if ua.contains("Android") { return "Android device" }
        if ua.contains("Windows") { return "Windows PC" }
        if ua.contains("Linux") { return "Linux device" }

        return ua.split(separator: " ").first.map(String.init) ?? "Unknown device"
    }
}
