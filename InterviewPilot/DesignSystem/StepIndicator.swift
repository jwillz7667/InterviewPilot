import SwiftUI

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("Step \(currentStep) of \(totalSteps)")
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textSecondary)

            HStack(spacing: 6) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? IATheme.accent : IATheme.outlineVariant)
                        .frame(width: step == currentStep ? 24 : 10, height: 6)
                        .animation(IAAnimations.snappy, value: currentStep)
                }
            }
        }
    }
}
