import SwiftUI
import SwiftData

@main
struct InterviewAceApp: App {
    @State private var versionService = VersionService.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            InterviewSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if versionService.requiresUpdate {
                    ForceUpdateView()
                } else {
                    ContentView()
                }
            }
            .task { await versionService.checkVersion() }
        }
        .modelContainer(sharedModelContainer)
    }
}
