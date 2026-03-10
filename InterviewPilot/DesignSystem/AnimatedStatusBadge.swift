import SwiftUI

struct AnimatedStatusBadge: View {
    let text: String
    let color: Color
    let isActive: Bool

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing && isActive ? 1.4 : 1.0)
                .opacity(isPulsing && isActive ? 0.6 : 1.0)
                .animation(IPAnimations.pulse, value: isPulsing)

            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .onAppear { isPulsing = true }
    }
}
