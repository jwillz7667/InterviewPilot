import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var selectedTab = 0
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Group {
                if !authService.isAuthenticated {
                    LoginView()
                } else {
                    TabView(selection: $selectedTab) {
                        Tab("Prepare", systemImage: "mic.badge.plus", value: 0) {
                            SessionSetupView()
                        }

                        Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
                            NavigationStack {
                                SessionHistoryView()
                            }
                        }

                        Tab("Settings", systemImage: "slider.horizontal.3", value: 2) {
                            SettingsView()
                        }
                    }
                    .tint(IATheme.accent)
                }
            }
            .preferredColorScheme(appAppearance.colorScheme)
            .onAppear {
                SessionStorageService.shared.configure(with: modelContext)
            }
            .task(id: authService.isAuthenticated) {
                if authService.isAuthenticated {
                    await subscriptionService.refresh(forceStoreKitSync: true)
                } else {
                    subscriptionService.reset()
                }
            }

            if !networkMonitor.isConnected {
                NetworkErrorView {
                    // Connectivity is auto-detected by NWPathMonitor
                }
                .transition(.opacity)
                .animation(IAAnimations.standard, value: networkMonitor.isConnected)
            }
        }
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }
}
