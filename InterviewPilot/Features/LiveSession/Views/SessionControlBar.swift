import SwiftUI

struct SessionControlBar: View {
    let isCapturing: Bool
    let onToggleMute: () -> Void
    let onEndSession: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: IPTheme.spacing24) {
            ControlButton(
                icon: isCapturing ? "mic.fill" : "mic.slash.fill",
                label: isCapturing ? "Mute" : "Unmute",
                isActive: isCapturing,
                action: onToggleMute
            )

            Spacer()

            Button(action: onEndSession) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(IPTheme.error.gradient, in: Circle())
                    .shadow(color: IPTheme.error.opacity(0.4), radius: 8, y: 4)
            }

            Spacer()

            ControlButton(
                icon: "forward.fill",
                label: "Next",
                isActive: true,
                action: onSkip
            )
        }
        .padding(.vertical, IPTheme.spacing12)
        .padding(.horizontal, IPTheme.spacing24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusXL))
    }
}
