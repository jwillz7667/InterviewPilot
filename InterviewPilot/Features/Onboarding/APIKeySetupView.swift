import SwiftUI

struct APIKeySetupView: View {
    var body: some View {
        IPPanel(tone: .secondary) {
            Label("API keys are configured automatically by the app.", systemImage: "checkmark.shield.fill")
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textSecondary)
        }
        .padding()
        .background {
            IPAppBackground()
        }
    }
}
