import SwiftUI

struct SessionControlBar: View {
    let isCapturing: Bool
    let onToggleMute: () -> Void
    let onEndSession: () -> Void
    let onSkip: () -> Void

    var body: some View {
        IPPanel(tone: .secondary, padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusXL) {
            HStack(spacing: 18) {
                ControlButton(
                    icon: isCapturing ? "mic.fill" : "mic.slash.fill",
                    label: isCapturing ? "Mute" : "Unmute",
                    isActive: isCapturing,
                    tint: IPTheme.accent,
                    action: onToggleMute
                )

                Spacer()

                Button(action: onEndSession) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(IPTheme.error.gradient, in: Circle())
                        .shadow(color: IPTheme.error.opacity(0.24), radius: 16, y: 10)
                }
                .buttonStyle(.plain)

                Spacer()

                ControlButton(
                    icon: "forward.fill",
                    label: "Next",
                    isActive: true,
                    tint: IPTheme.accentWarm,
                    action: onSkip
                )
            }
        }
    }
}
