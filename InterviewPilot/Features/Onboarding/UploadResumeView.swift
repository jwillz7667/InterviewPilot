import SwiftUI
import UniformTypeIdentifiers

struct UploadResumeView: View {
    @Binding var resumeText: String
    @Binding var resumeDocumentName: String?
    var autofillState: OnboardingViewModel.AutofillState
    var onFilePick: () -> Void
    var onRetryAutofill: () -> Void
    var onAutofillFromText: () -> Void
    @State private var showResumeEditor = false
    @Environment(\.colorScheme) private var colorScheme

    var hasResume: Bool {
        !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isAutofilling: Bool {
        switch autofillState {
        case .readingFile, .runningOCR, .extractingProfile: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Upload your resume")
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("We'll auto-fill your name, role, skills and work history. You can edit anything before continuing.")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            uploadZone

            autofillStatusCard

            if hasResume && !isAutofilling {
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
                icon: "wand.and.stars",
                title: "Auto-filled, not auto-submitted",
                detail: "We populate the profile fields from your resume — you review and confirm everything before saving."
            )

            infoCard(
                icon: "eye.slash.fill",
                title: "Private and secure",
                detail: "Your resume is used only to power your responses. It is never shared externally."
            )

            Text("You can skip this and upload it later from Settings.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showResumeEditor, onDismiss: maybeAutofillAfterEdit) {
            ResumeInputView(resumeText: $resumeText)
        }
    }

    private func maybeAutofillAfterEdit() {
        if hasResume {
            onAutofillFromText()
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

            Text(hasResume ? "Tap to replace with a new file" : "PDF, DOCX, RTF, Markdown or plain text")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)

            HStack(spacing: 12) {
                Button(action: onFilePick) {
                    Label("Browse Files", systemImage: "folder.fill")
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(isAutofilling)

                Button(action: { showResumeEditor = true }) {
                    Label("Paste Text", systemImage: "square.and.pencil")
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(isAutofilling)
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

    @ViewBuilder
    private var autofillStatusCard: some View {
        switch autofillState {
        case .idle:
            EmptyView()
        case .readingFile:
            progressCard(title: "Reading your resume…", subtitle: "Extracting text from the document.")
        case .runningOCR:
            progressCard(title: "Running OCR…", subtitle: "This looks like a scanned PDF — recognizing text now.")
        case .extractingProfile:
            progressCard(title: "Auto-filling your profile…", subtitle: "Identifying role, skills and work history.")
        case .completed(let summary):
            summaryCard(summary)
        case .failed(let message):
            failureCard(message: message)
        }
    }

    private func progressCard(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressView()
                .tint(IATheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)
                Text(subtitle)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(IATheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.accent.opacity(0.25), lineWidth: 1)
        }
    }

    private func summaryCard(_ summary: OnboardingViewModel.ResumeAutofillSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IATheme.success)
                Text("Profile auto-filled")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                Spacer()
                if summary.usedOCR {
                    badge(text: "OCR", color: IATheme.accent)
                }
            }

            FlowLayout(spacing: 6) {
                ForEach(summary.filledFields, id: \.self) { field in
                    chip(label: chipLabel(for: field, summary: summary))
                }
            }

            Text("Review your details before continuing — tap any field to edit.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)
        }
        .padding(14)
        .background(IATheme.successContainer.opacity(0.25), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.success.opacity(0.30), lineWidth: 1)
        }
    }

    private func chipLabel(for field: ResumeAutofillField, summary: OnboardingViewModel.ResumeAutofillSummary) -> String {
        switch field {
        case .displayName: return "Name"
        case .currentRole: return "Role"
        case .currentCompany: return "Company"
        case .yearsInRole: return "Years"
        case .linkedInURL: return "LinkedIn"
        case .summary: return "Summary"
        case .skills: return "\(summary.addedSkills) skill\(summary.addedSkills == 1 ? "" : "s")"
        case .workExperiences: return "\(summary.addedExperiences) job\(summary.addedExperiences == 1 ? "" : "s")"
        }
    }

    private func failureCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(IATheme.error)
                Text("Couldn't auto-fill")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
            }
            Text(message)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)

            HStack(spacing: 10) {
                Button(action: onRetryAutofill) {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(!hasResume)

                Button(action: { showResumeEditor = true }) {
                    Label("Paste text", systemImage: "square.and.pencil")
                }
                .buttonStyle(IASecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(IATheme.error.opacity(0.08), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.error.opacity(0.30), lineWidth: 1)
        }
    }

    private func chip(label: String) -> some View {
        Text(label)
            .font(IATypography.labelMedium)
            .foregroundStyle(IATheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(IATheme.surface, in: Capsule())
            .overlay {
                Capsule().stroke(IATheme.outlineVariant, lineWidth: 1)
            }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(IATypography.labelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.10), in: Capsule())
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
