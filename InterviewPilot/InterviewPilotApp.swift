import SwiftUI
import SwiftData

@main
struct InterviewAceApp: App {
    @State private var versionService = VersionService.shared
    @State private var showSplash = true

    init() {
        NetworkPathMonitor.shared.start()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: InterviewPilotMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if versionService.requiresUpdate {
                        ForceUpdateView()
                    } else {
                        ContentView()
                    }
                }
                .task { await versionService.checkVersion() }

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
