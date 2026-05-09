import SwiftUI

struct SessionControlBar: View {
    let isCapturing: Bool
    let onToggleMute: () -> Void
    let onEndSession: () -> Void
    let onSkip: () -> Void

    var body: some View {
        IABottomDock {
            HStack(spacing: 18) {
                ControlButton(
                    icon: isCapturing ? "mic.fill" : "mic.slash.fill",
                    label: isCapturing ? "Mute" : "Unmute",
                    isActive: isCapturing,
                    tint: IATheme.accent,
                    action: onToggleMute
                )

                Spacer()

                Button(action: onEndSession) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(IATheme.error.gradient, in: Circle())
                        .shadow(color: IATheme.error.opacity(0.24), radius: 16, y: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End interview session")
                .accessibilityHint("Stops audio capture and saves the session")

                Spacer()

                ControlButton(
                    icon: "forward.fill",
                    label: "Next",
                    isActive: true,
                    tint: IATheme.accent,
                    action: onSkip
                )
            }
        }
    }
}
