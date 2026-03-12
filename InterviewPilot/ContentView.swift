import SwiftUI

struct ContentView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var showSettings = false
    @State private var selectedTab = 0
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @Environment(\.modelContext) private var modelContext

    var body: some View {
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
                                .navigationTitle("History")
                                .navigationBarTitleDisplayMode(.large)
                                .toolbar {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button(action: { showSettings = true }) {
                                            Image(systemName: "gearshape.2.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(IPTheme.textSecondary)
                                        }
                                    }
                                }
                        }
                    }

                    Tab("Settings", systemImage: "slider.horizontal.3", value: 2) {
                        SettingsView()
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    IPTabAccessory(selectedTab: selectedTab)
                }
                .tint(IPTheme.accent)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
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
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }
}
