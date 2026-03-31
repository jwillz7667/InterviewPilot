import SwiftUI
import UniformTypeIdentifiers

struct UploadResumeView: View {
    @Binding var resumeText: String
    @Binding var resumeDocumentName: String?
    var onFilePick: () -> Void
    @State private var showResumeEditor = false
    @Environment(\.colorScheme) private var colorScheme

    var hasResume: Bool {
        !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Upload your resume")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Your resume grounds every response in your actual experience.")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            uploadZone

            if hasResume {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(IATheme.success)
                    Text(resumeDocumentName ?? "Resume loaded")
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                    Spacer()
                    Button("Edit") { showResumeEditor = true }
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.accent)
                }
                .padding(14)
                .background(IATheme.successContainer.opacity(0.3), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            }

            infoCard(
                icon: "doc.text.fill",
                title: "PDF or text",
                detail: "Upload a PDF file or paste your resume text directly."
            )

            infoCard(
                icon: "eye.slash.fill",
                title: "Private and secure",
                detail: "Your resume is used only during live sessions and never shared externally."
            )

            Spacer()

            Text("You can skip this and upload it from the session setup screen.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showResumeEditor) {
            ResumeInputView(resumeText: $resumeText)
        }
    }

    private var uploadZone: some View {
        VStack(spacing: 16) {
            Image(systemName: hasResume ? "doc.text.fill" : "square.and.arrow.up.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(IATheme.accent)

            Text(hasResume ? "Resume Uploaded" : "Drop your resume here")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            Text(hasResume ? "Tap to replace with a new file" : "or browse files to upload")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)

            HStack(spacing: 12) {
                Button(action: onFilePick) {
                    Label("Browse Files", systemImage: "folder.fill")
                }
                .buttonStyle(IASecondaryButtonStyle())

                Button(action: { showResumeEditor = true }) {
                    Label("Paste Text", systemImage: "square.and.pencil")
                }
                .buttonStyle(IASecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .fill(IATheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .foregroundStyle(IATheme.outlineVariant)
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
