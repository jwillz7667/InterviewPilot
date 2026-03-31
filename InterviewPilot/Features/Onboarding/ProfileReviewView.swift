import SwiftUI

struct ProfileReviewView: View {
    @Binding var displayName: String
    @Binding var currentRole: String
    @Binding var currentCompany: String
    @Binding var skills: [SkillEntry]
    @Binding var newSkillText: String
    var onAddSkill: () -> Void
    var onRemoveSkill: (SkillEntry) -> Void
    var resumeLoaded: Bool
    var linkedInConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review your profile")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Confirm your details before getting started. You can edit these later.")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                profileField(title: "Full Name", text: $displayName, placeholder: "Your name")
                profileField(title: "Current Role", text: $currentRole, placeholder: "e.g. Senior iOS Engineer")
                profileField(title: "Company", text: $currentCompany, placeholder: "e.g. Apple")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Expertise")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                FlowLayout(spacing: 8) {
                    ForEach(skills) { skill in
                        IASkillChip(name: skill.name) {
                            onRemoveSkill(skill)
                        }
                    }

                    addSkillField
                }
            }

            HStack(spacing: 12) {
                statusBadge(
                    icon: resumeLoaded ? "checkmark.circle.fill" : "circle",
                    title: "Resume",
                    active: resumeLoaded
                )
                statusBadge(
                    icon: linkedInConnected ? "checkmark.circle.fill" : "circle",
                    title: "LinkedIn",
                    active: linkedInConnected
                )
            }
        }
    }

    private var addSkillField: some View {
        HStack(spacing: 6) {
            TextField("Add skill", text: $newSkillText)
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textPrimary)
                .frame(width: 80)
                .submitLabel(.done)
                .onSubmit { onAddSkill() }

            Button(action: onAddSkill) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(IATheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(IATheme.surface, in: Capsule())
        .overlay {
            Capsule()
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    private func profileField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)

            TextField(placeholder, text: text)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
        }
    }

    private func statusBadge(icon: String, title: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(active ? IATheme.success : IATheme.textTertiary)

            Text(title)
                .font(IATypography.labelLarge)
                .foregroundStyle(active ? IATheme.textPrimary : IATheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(active ? IATheme.successContainer.opacity(0.3) : IATheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(active ? IATheme.success.opacity(0.3) : IATheme.outlineVariant, lineWidth: 1)
        }
    }
}

// FlowLayout is defined in JobDescriptionInputView.swift and shared across the app.
