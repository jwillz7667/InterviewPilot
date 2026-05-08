import SwiftUI
import AVFoundation

struct MicrophonePermissionView: View {
    @Binding var status: AVAuthorizationStatus
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enable microphone access")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Interview Ace listens during your interviews and transcribes every question in real time, so we can suggest tailored answers as you go.")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                bulletRow(
                    icon: "waveform",
                    title: "Real-time transcription",
                    body: "Audio stays on-device until a question is detected, then streams to our secure backend."
                )
                bulletRow(
                    icon: "lock.shield",
                    title: "Never recorded or stored",
                    body: "We process audio in memory only. Nothing is saved to disk or kept after your session ends."
                )
                bulletRow(
                    icon: "person.badge.shield.checkmark",
                    title: "You stay in control",
                    body: "Revoke permission any time in iOS Settings. The app works offline for everything except live sessions."
                )
            }

            ctaButton

            if status == .denied || status == .restricted {
                settingsHint
            }
        }
    }

    private func bulletRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(IATheme.accent)
                .frame(width: 36, height: 36)
                .background(IATheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                Text(body)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        switch status {
        case .authorized:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(IATheme.success)
                Text("Microphone access granted")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(IATheme.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)

        case .notDetermined:
            Button(action: onRequest) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                    Text("Allow microphone access")
                }
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: true))

        case .denied, .restricted:
            Button(action: onRequest) {
                HStack(spacing: 10) {
                    Image(systemName: "gear")
                    Text("Open Settings to enable")
                }
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: true))

        @unknown default:
            Button(action: onRequest) {
                Text("Allow microphone access")
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: true))
        }
    }

    private var settingsHint: some View {
        Text("If iOS no longer shows a permission prompt, tap above to open Settings → Interview Ace → Microphone.")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
