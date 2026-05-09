import Foundation
import Network
import Observation

/// Observes the device's network reachability so views can render an inline
/// banner instead of letting requests fail silently.
///
/// `NWPathMonitor` runs on a background queue; we hop back to MainActor before
/// publishing the latest snapshot so SwiftUI bindings stay isolation-clean.
@Observable
final class NetworkPathMonitor {
    static let shared = NetworkPathMonitor()

    private(set) var isOnline: Bool = true
    private(set) var isExpensive: Bool = false
    private(set) var isConstrained: Bool = false

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.res.jobhopperAI.network-monitor")
    @ObservationIgnored private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isOnline = online
                self.isExpensive = expensive
                self.isConstrained = constrained
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
