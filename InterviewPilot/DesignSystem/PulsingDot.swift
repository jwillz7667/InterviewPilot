import SwiftUI

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(IPAnimations.pulse, value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
