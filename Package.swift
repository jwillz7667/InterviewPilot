// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InterviewPilotCore",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [.library(name: "InterviewPilotCore", targets: ["InterviewPilotCore"])],
    targets: [
        .target(name: "InterviewPilotCore", path: "InterviewPilot",
                exclude: ["Assets.xcassets", "Resources", "Features", "Services/AI", "Services/Audio",
                          "Services/Document", "Services/Storage/DeepgramKeyStore.swift",
                          "InterviewPilotApp.swift", "Info.plist", "InterviewPilot.entitlements", "PrivacyInfo.xcprivacy"],
                sources: ["Core", "Services/Storage/LocalInterviewStore.swift"]),
        .testTarget(name: "InterviewPilotCoreTests", dependencies: ["InterviewPilotCore"],
                    path: "Tests/InterviewPilotCoreTests")
    ]
)
