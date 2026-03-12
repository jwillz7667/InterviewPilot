import SwiftUI

struct WaveformView: View {
    let level: Float
    private let barCount = 28

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [IPTheme.accentSecondary.opacity(0.55), IPTheme.accent.opacity(0.9)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.spring(duration: 0.16).delay(Double(index) * 0.008), value: level)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalized = CGFloat(level)
        let randomFactor = CGFloat.random(in: 0.3...1.0)
        let centerBias = 1.0 - abs(CGFloat(index) - CGFloat(barCount) / 2) / (CGFloat(barCount) / 2)
        return max(4, min(30, normalized * 30 * randomFactor * (0.45 + centerBias * 0.55)))
    }
}
