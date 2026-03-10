import SwiftUI

// API keys are now managed server-side.
// This file is retained for backward compatibility but no longer used.
struct APIKeySetupView: View {
    var body: some View {
        Text("API keys are configured automatically.")
            .foregroundStyle(.white.opacity(0.5))
    }
}
