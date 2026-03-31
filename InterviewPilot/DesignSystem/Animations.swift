import SwiftUI

enum IAAnimations {
    static let standard = Animation.spring(duration: 0.45, bounce: 0.16)
    static let snappy = Animation.spring(duration: 0.28, bounce: 0.24)
    static let gentle = Animation.spring(duration: 0.55, bounce: 0.08)
    static let tokenAppear = Animation.spring(duration: 0.22, bounce: 0.12)
    static let pulse = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
    static let waveform = Animation.linear(duration: 0.12)
    static let hero = Animation.spring(duration: 0.8, bounce: 0.20)
}
