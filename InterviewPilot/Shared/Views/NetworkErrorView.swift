import Network
import SwiftUI

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var isConnected = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

struct NetworkErrorView: View {
    var onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            IAPanel(tone: .secondary, padding: 24, cornerRadius: 30) {
                VStack(spacing: 20) {
                    Circle()
                        .fill(IATheme.warning.opacity(0.14))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(IATheme.warning)
                        }

                    VStack(spacing: 8) {
                        Text("No Connection")
                            .font(IATypography.headlineMedium)
                            .foregroundStyle(IATheme.textPrimary)

                        Text("Interview Ace AI requires an active network connection for transcription and response generation.")
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onRetry) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IAPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, IATheme.spacing24)
        }
    }
}
