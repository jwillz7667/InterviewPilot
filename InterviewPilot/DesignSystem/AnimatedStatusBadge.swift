import SwiftUI

struct AnimatedStatusBadge: View {
    let text: String
    let color: Color
    let isActive: Bool

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .scaleEffect(isPulsing && isActive ? 1.4 : 1.0)
                .opacity(isPulsing && isActive ? 0.55 : 1.0)
                .animation(IPAnimations.pulse, value: isPulsing)

            Text(text.uppercased())
                .font(IPTypography.labelSmall)
                .tracking(1.0)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: Capsule())
        .onAppear { isPulsing = true }
    }
}
