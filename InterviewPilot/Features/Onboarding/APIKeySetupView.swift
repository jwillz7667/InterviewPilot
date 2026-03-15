import SwiftUI

struct APIKeySetupView: View {
    var body: some View {
        ZStack {
            IPAppBackground()

            IPPanel(tone: .secondary, padding: 22, cornerRadius: 28) {
                HStack(spacing: 14) {
                    IPBrandLogo(size: 44, showShadow: false, variant: .surface)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access is ready")
                            .font(IPTypography.headlineSmall)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text("API keys are configured automatically after sign-in.")
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textSecondary)
                    }
                }
            }
            .padding()
        }
    }
}
