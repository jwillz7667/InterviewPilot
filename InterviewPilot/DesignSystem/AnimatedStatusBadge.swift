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
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && isActive ? 1.25 : 1.0)
                .opacity(isPulsing && isActive ? 0.45 : 1.0)
                .animation(IPAnimations.pulse, value: isPulsing)

            Text(text.uppercased())
                .font(IPTypography.labelSmall)
                .tracking(0.9)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: Capsule())
        .overlay {
            Capsule()
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .onAppear { isPulsing = true }
    }
}
