import SwiftUI

struct APIKeySetupView: View {
    var body: some View {
        ZStack {
            IAAppBackground()

            IAPanel(tone: .secondary, padding: 22, cornerRadius: 28) {
                HStack(spacing: 14) {
                    IABrandLogo(size: 44, showShadow: false, variant: .surface)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access is ready")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        Text("API keys are configured automatically after sign-in.")
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }
            }
            .padding()
        }
    }
}
