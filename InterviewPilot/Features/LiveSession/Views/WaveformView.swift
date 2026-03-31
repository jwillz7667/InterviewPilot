import SwiftUI

struct WaveformView: View {
    let level: Float
    private let barCount = 28

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [IATheme.accentSecondary.opacity(0.45), IATheme.accent],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 5, height: barHeight(for: index))
                    .animation(.spring(duration: 0.16).delay(Double(index) * 0.008), value: level)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalized = CGFloat(level)
        let oscillation = sin(CGFloat(index) * 0.65 + normalized * 8)
        let centerBias = 1.0 - abs(CGFloat(index) - CGFloat(barCount) / 2) / (CGFloat(barCount) / 2)
        let amplitude = max(0.18, (oscillation + 1) / 2)
        return max(6, min(34, normalized * 28 * amplitude * (0.45 + centerBias * 0.55)))
    }
}
