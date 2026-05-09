import SwiftUI

/// Inline banner attached to the top of a screen when the device drops offline.
/// Reduce-motion users get an opacity transition instead of slide.
struct OfflineBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOnline: Bool

    var body: some View {
        if !isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .accessibilityHidden(true)
                Text("You're offline — answers will resume when reconnected.")
                    .font(.footnote.weight(.medium))
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.92))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
    }
}

extension View {
    /// Pins an offline banner to the top of the receiver.
    func offlineBanner(_ isOnline: Bool) -> some View {
        VStack(spacing: 0) {
            OfflineBanner(isOnline: isOnline)
            self
        }
        .animation(.easeInOut(duration: 0.25), value: isOnline)
    }
}
