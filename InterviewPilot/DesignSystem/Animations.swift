import SwiftUI

enum IPAnimations {
    // Standard spring for most transitions
    static let standard = Animation.spring(duration: 0.4, bounce: 0.2)

    // Snappy for button presses and quick feedback
    static let snappy = Animation.spring(duration: 0.25, bounce: 0.3)

    // Gentle for sheets and overlays
    static let gentle = Animation.spring(duration: 0.5, bounce: 0.1)

    // Typewriter token appearance
    static let tokenAppear = Animation.spring(duration: 0.2, bounce: 0.15)

    // Pulse for recording indicator
    static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

    // Waveform
    static let waveform = Animation.linear(duration: 0.1)
}
