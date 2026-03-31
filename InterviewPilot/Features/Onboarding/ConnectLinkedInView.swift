import SwiftUI

struct ConnectLinkedInView: View {
    @Binding var linkedInURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect your LinkedIn")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("We'll use your profile to understand your background and tailor responses to what interviewers see.")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("LinkedIn Profile URL")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)

                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.textSecondary)

                    TextField("linkedin.com/in/yourname", text: $linkedInURL)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
            }

            infoCard(
                icon: "lock.shield.fill",
                title: "Your data is secure",
                detail: "We only store your public profile URL. Your LinkedIn credentials are never accessed."
            )

            infoCard(
                icon: "sparkles",
                title: "Better interview prep",
                detail: "Your profile helps generate responses that align with your professional background."
            )

            Spacer()

            Text("You can skip this step and add it later in settings.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func infoCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(IATheme.accent.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Text(detail)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
        }
        .padding(14)
        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
    }
}
