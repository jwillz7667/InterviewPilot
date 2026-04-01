import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @State private var authService = AuthService.shared
    @State private var profileService = ProfileService.shared
    @State private var displayName = ""
    @State private var linkedInURL = ""
    @State private var skills: [SkillEntry] = []
    @State private var newSkillText = ""
    @State private var resumeText = ""
    @State private var resumeDocumentName: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showFilePicker = false
    @State private var showResumeEditor = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        headerSection
                        avatarSection
                        formSection
                        professionalAssetsSection
                        actionButtons
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
            .onAppear {
                loadFromProfile()
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleResumeFile(result)
            }
            .sheet(isPresented: $showResumeEditor) {
                ResumeInputView(resumeText: $resumeText)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account Settings")
                .font(IATypography.headlineLarge)
                .foregroundStyle(IATheme.textPrimary)

            Text("Manage your profile details and professional assets.")
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack {
            ZStack(alignment: .bottomTrailing) {
                IABrandLogo(size: 80, showShadow: false, variant: .filled)

                Circle()
                    .fill(IATheme.accent)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: IATheme.spacing16) {
            profileField(title: "Full Name", text: $displayName, placeholder: "Your name")

            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text(authService.currentUser?.email ?? "")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                            .stroke(IATheme.outlineVariant, lineWidth: 1)
                    }
            }

            profileField(title: "LinkedIn URL", text: $linkedInURL, placeholder: "linkedin.com/in/yourname")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    // MARK: - Professional Assets

    private var professionalAssetsSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing16) {
            Text("Professional Assets")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            resumeUploadZone

            VStack(alignment: .leading, spacing: 10) {
                Text("Expertise Tags")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)

                FlowLayout(spacing: 8) {
                    ForEach(skills) { skill in
                        IASkillChip(name: skill.name) {
                            skills.removeAll { $0.id == skill.id }
                        }
                    }

                    addSkillField
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    private var resumeUploadZone: some View {
        VStack(spacing: 12) {
            if !resumeText.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(IATheme.success)
                    Text(resumeDocumentName ?? "Resume loaded")
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Button(action: { showFilePicker = true }) {
                    Label("Upload PDF", systemImage: "doc.badge.plus")
                }
                .buttonStyle(IASecondaryButtonStyle())

                Button(action: { showResumeEditor = true }) {
                    Label("Edit Text", systemImage: "square.and.pencil")
                }
                .buttonStyle(IASecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .foregroundStyle(IATheme.outlineVariant)
        }
    }

    private var addSkillField: some View {
        HStack(spacing: 6) {
            TextField("Add skill", text: $newSkillText)
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textPrimary)
                .frame(width: 80)
                .submitLabel(.done)
                .onSubmit { addSkill() }

            Button(action: addSkill) {
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Discard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IASecondaryButtonStyle())

                Button(action: save) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Save Changes")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IAPrimaryButtonStyle(isEnabled: !isSaving))
                .disabled(isSaving)
            }
        }
    }

    // MARK: - Helpers

    private func profileField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)

            TextField(placeholder, text: text)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
        }
    }

    private func loadFromProfile() {
        displayName = authService.currentUser?.displayName ?? ""
        if let profile = profileService.profile {
            linkedInURL = profile.linkedinUrl ?? ""
            skills = profile.skills
        }
    }

    private func addSkill() {
        let trimmed = newSkillText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !skills.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            newSkillText = ""
            return
        }
        skills.append(SkillEntry(name: trimmed))
        newSkillText = ""
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await authService.updateProfile(displayName: displayName)

                let updates = ProfileUpdate(
                    displayName: displayName,
                    linkedinUrl: linkedInURL.isEmpty ? nil : linkedInURL,
                    resumeText: resumeText.isEmpty ? nil : resumeText
                )
                try await profileService.updateProfile(updates)

                try await profileService.updateSkills(skills)

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func handleResumeFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }

                resumeDocumentName = url.lastPathComponent
                if let data = try? Data(contentsOf: url),
                   let text = ResumeParserService.extractText(from: data) {
                    resumeText = text
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
