import SwiftUI

@main
struct InterviewPilotApp: App {
    @State private var store = LocalInterviewStore()
    @State private var activeSession: SessionLaunch?

    var body: some Scene {
        WindowGroup {
            PersonalWorkspaceView(store: store) { configuration in
                activeSession = SessionLaunch(configuration: configuration)
            }
            .fullScreenCover(item: $activeSession) { launch in
                LiveSessionView(configuration: launch.configuration, store: store)
            }
        }
    }
}

private struct SessionLaunch: Identifiable {
    let id = UUID()
    let configuration: InterviewConfiguration
}
