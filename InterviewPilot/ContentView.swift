import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var authService = AuthService.shared
    @State private var subscriptionService = SubscriptionService.shared
    @State private var profileService = ProfileService.shared
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    @State private var showTrialExpiry = false
    @State private var showPaywall = false
    // App is light-mode only — IATheme colors are not dark-mode aware
    @AppStorage("onboardingCompletedLocal") private var onboardingCompletedLocal = false
    @AppStorage("hasSeenTrialExpiry") private var hasSeenTrialExpiry = false
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
            .preferredColorScheme(.light)
            .onAppear {
                SessionStorageService.shared.configure(with: modelContext)
            }
            .task(id: authService.isAuthenticated) {
                if authService.isAuthenticated {
                    await subscriptionService.refresh(forceStoreKitSync: true)
                    await profileService.fetchProfile()
                    checkOnboardingStatus()
                    checkTrialExpiry()
                } else {
                    subscriptionService.reset()
                    showOnboarding = false
                    selectedTab = 0
                }
            }
            .fullScreenCover(isPresented: $showTrialExpiry) {
                TrialExpiryView {
                    showTrialExpiry = false
                    showPaywall = true
                }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
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
        // Local flag is authoritative — once completed, never show again
        if onboardingCompletedLocal {
            showOnboarding = false
            return
        }
        // Sync from server if available
        if let profile = profileService.profile, profile.onboardingCompleted {
            onboardingCompletedLocal = true
            showOnboarding = false
            return
        }
        // First-time user: show onboarding
        showOnboarding = true
    }

    private func checkTrialExpiry() {
        guard let entitlement = subscriptionService.currentEntitlement,
              entitlement.isFreeTier,
              !hasSeenTrialExpiry else { return }
        showTrialExpiry = true
        hasSeenTrialExpiry = true
    }

}
