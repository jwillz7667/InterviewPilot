import SwiftUI

struct ForceUpdateView: View {
    var body: some View {
        ZStack {
            IAAppBackground()

            VStack(spacing: 32) {
                Spacer()

                IABrandLogo(size: 96, variant: .filled)

                VStack(spacing: 14) {
                    Text("Update Required")
                        .font(IATypography.displayMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("A newer version of Interview Ace AI is available. Please update to continue using the app.")
                        .font(IATypography.bodyLarge)
                        .foregroundStyle(IATheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: openAppStore) {
                    Label("Update Now", systemImage: "arrow.down.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IAPrimaryButtonStyle())

                Spacer()
            }
            .padding(.horizontal, IATheme.spacing24)
        }
    }

    private func openAppStore() {
        guard let url = URL(string: "https://apps.apple.com/app/id6743397798") else { return }
        UIApplication.shared.open(url)
    }
}
