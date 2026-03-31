import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var profileService = ProfileService.shared
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    @AppStorage("appAppearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("onboardingCompletedLocal") private var onboardingCompletedLocal = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Group {
                if !authService.isAuthenticated {
                    LoginView()
                } else if showOnboarding {
                    OnboardingView {
                        withAnimation(IAAnimations.hero) {
                            showOnboarding = false
                            onboardingCompletedLocal = true
                        }
                    }
                } else {
                    mainTabView
                }
            }
            .preferredColorScheme(appAppearance.colorScheme)
            .onAppear {
                SessionStorageService.shared.configure(with: modelContext)
            }
            .task(id: authService.isAuthenticated) {
                if authService.isAuthenticated {
                    await subscriptionService.refresh(forceStoreKitSync: true)
                    await profileService.fetchProfile()
                    checkOnboardingStatus()
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

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView()
            }

            Tab("Insights", systemImage: "chart.bar.fill", value: 1) {
                NavigationStack {
                    InterviewInsightsView()
                }
            }

            Tab("Profile", systemImage: "person.fill", value: 2) {
                SettingsView()
            }
        }
        .tint(IATheme.accent)
    }

    private func checkOnboardingStatus() {
        if let profile = profileService.profile {
            showOnboarding = !profile.onboardingCompleted
        } else {
            showOnboarding = !onboardingCompletedLocal
        }
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }
}
