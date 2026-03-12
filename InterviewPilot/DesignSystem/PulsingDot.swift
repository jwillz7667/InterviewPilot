import SwiftUI

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.35), radius: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.72 : 1.0)
            .animation(IPAnimations.pulse, value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
