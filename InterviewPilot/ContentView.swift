import SwiftUI

struct ContentView: View {
    @State private var authService = AuthService.shared
    @State private var showSettings = false
    @State private var selectedTab = 0

    var body: some View {
        if !authService.isAuthenticated {
            LoginView()
        } else {
            TabView(selection: $selectedTab) {
                Tab("Interview", systemImage: "mic.fill", value: 0) {
                    SessionSetupView()
                }

                Tab("History", systemImage: "clock.arrow.circlepath", value: 1) {
                    NavigationStack {
                        SessionHistoryView()
                            .navigationTitle("History")
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: { showSettings = true }) {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                            }
                    }
                }

                Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                    SettingsView()
                }
            }
            .preferredColorScheme(.dark)
            .tint(IPTheme.brand)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}
