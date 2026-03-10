import SwiftUI

struct WaveformView: View {
    let level: Float
    private let barCount = 30

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(IPTheme.brandLight.opacity(0.6))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(
                        .spring(duration: 0.15).delay(Double(i) * 0.01),
                        value: level
                    )
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalized = CGFloat(level)
        let randomFactor = CGFloat.random(in: 0.3...1.0)
        let centerBias = 1.0 - abs(CGFloat(index) - CGFloat(barCount) / 2) / (CGFloat(barCount) / 2)
        return max(3, min(28, normalized * 28 * randomFactor * (0.5 + centerBias * 0.5)))
    }
}
