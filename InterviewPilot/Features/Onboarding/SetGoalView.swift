import SwiftUI

struct SetGoalView: View {
    @Binding var selectedGoal: UserGoal?

    var body: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's your primary goal?")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("This helps us tailor your interview prep experience.")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(UserGoal.allCases) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: UserGoal) -> some View {
        let isSelected = selectedGoal == goal

        return Button(action: {
            withAnimation(IAAnimations.snappy) {
                selectedGoal = goal
            }
        }) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? IATheme.accent : IATheme.accent.opacity(0.10))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: goal.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : IATheme.accent)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)

                    Text(goal.subtitle)
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? IATheme.accent : IATheme.outlineVariant)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .fill(isSelected ? IATheme.accent.opacity(0.06) : IATheme.surfaceWhite)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(isSelected ? IATheme.accent : IATheme.outlineVariant, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}
