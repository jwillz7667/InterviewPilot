import SwiftUI
import UniformTypeIdentifiers

struct ProfileDetailEditorView: View {
    let profileId: String

    @State private var profile: InterviewProfile?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccessBanner = false

    // Scalar fields
    @State private var name = ""
    @State private var currentRole = ""
    @State private var currentCompany = ""
    @State private var yearsInRole = 0
    @State private var linkedinUrl = ""
    @State private var summary = ""
    @State private var communicationStyle: CommunicationStyle = .detailed

    // Resume
    @State private var resumeText = ""
    @State private var resumeDocumentName: String?
    @State private var showFilePicker = false
    @State private var isExtractingProfile = false

    // Collections
    @State private var workExperiences: [ProfileWorkExperience] = []
    @State private var skills: [ProfileSkillEntry] = []
    @State private var education: [ProfileEducation] = []
    @State private var certifications: [ProfileCertification] = []
    @State private var projects: [ProfileProject] = []
    @State private var achievements: [ProfileAchievement] = []

    // Skills input
    @State private var newSkillText = ""
    @State private var newSkillCategory: SkillCategory = .language

    // Editor sheets
    @State private var showWorkExperienceEditor = false
    @State private var editingWorkExperience: ProfileWorkExperience?
    @State private var showEducationEditor = false
    @State private var editingEducation: ProfileEducation?
    @State private var showCertificationEditor = false
    @State private var editingCertification: ProfileCertification?
    @State private var showProjectEditor = false
    @State private var editingProject: ProfileProject?
    @State private var showAchievementEditor = false
    @State private var editingAchievement: ProfileAchievement?

    private let service = InterviewProfileService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            IAAppBackground()

            if isLoading && profile == nil {
                ProgressView()
                    .tint(IATheme.accent)
            } else if let _ = profile {
                editorContent
            } else {
                IAEmptyState(
                    title: "Profile Not Found",
                    subtitle: "This profile could not be loaded.",
                    symbol: "exclamationmark.triangle"
                )
            }
        }
        .navigationTitle(name.isEmpty ? "Edit Profile" : name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await saveAll() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(IATheme.accent)
                    } else {
                        Text("Save")
                            .foregroundStyle(IATheme.accent)
                    }
                }
                .disabled(isSaving)
            }
        }
        .task { await loadProfile() }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: ResumeFileFormat.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleResumeFile(result)
        }
        .sheet(isPresented: $showWorkExperienceEditor) {
            ProfileWorkExperienceEditorSheet(experience: nil) { entry in
                workExperiences.append(entry)
            }
        }
        .sheet(item: $editingWorkExperience) { experience in
            ProfileWorkExperienceEditorSheet(experience: experience) { updated in
                if let idx = workExperiences.firstIndex(where: { $0.id == updated.id }) {
                    workExperiences[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showEducationEditor) {
            ProfileEducationEditorSheet(education: nil) { entry in
                education.append(entry)
            }
        }
        .sheet(item: $editingEducation) { edu in
            ProfileEducationEditorSheet(education: edu) { updated in
                if let idx = education.firstIndex(where: { $0.id == updated.id }) {
                    education[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showCertificationEditor) {
            ProfileCertificationEditorSheet(certification: nil) { entry in
                certifications.append(entry)
            }
        }
        .sheet(item: $editingCertification) { cert in
            ProfileCertificationEditorSheet(certification: cert) { updated in
                if let idx = certifications.firstIndex(where: { $0.id == updated.id }) {
                    certifications[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showProjectEditor) {
            ProfileProjectEditorSheet(project: nil) { entry in
                projects.append(entry)
            }
        }
        .sheet(item: $editingProject) { project in
            ProfileProjectEditorSheet(project: project) { updated in
                if let idx = projects.firstIndex(where: { $0.id == updated.id }) {
                    projects[idx] = updated
                }
            }
        }
        .sheet(isPresented: $showAchievementEditor) {
            ProfileAchievementEditorSheet(achievement: nil) { entry in
                achievements.append(entry)
            }
        }
        .sheet(item: $editingAchievement) { achievement in
            ProfileAchievementEditorSheet(achievement: achievement) { updated in
                if let idx = achievements.firstIndex(where: { $0.id == updated.id }) {
                    achievements[idx] = updated
                }
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        ScrollView {
            VStack(spacing: IATheme.spacing20) {
                profileNameSection
                personalInfoSection
                summarySection
                communicationStyleSection
                resumeSection
                workExperienceSection
                skillsSection
                educationSection
                certificationsSection
                projectsSection
                achievementsSection
                statusBanners
            }
            .padding(.horizontal, IATheme.spacing20)
            .padding(.vertical, IATheme.spacing20)
        }
        .iaScrollablePage()
    }

    // MARK: - Profile Name

    private var profileNameSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Profile Name",
                subtitle: nil,
                symbol: "tag.fill"
            )

            IAPanel(tone: .secondary) {
                profileField("Profile name", text: $name)
            }
        }
    }

    // MARK: - Personal Info

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Personal Info",
                subtitle: nil,
                symbol: "person.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing16) {
                    profileField("Current Role", text: $currentRole, placeholder: "e.g., Senior Software Engineer")
                    profileField("Current Company", text: $currentCompany, placeholder: "e.g., Google")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Years in Role")
                            .font(IATypography.labelLarge)
                            .foregroundStyle(IATheme.textPrimary)

                        HStack(spacing: 12) {
                            Text("\(yearsInRole)")
                                .font(IATypography.bodyLarge)
                                .foregroundStyle(IATheme.textPrimary)
                                .frame(width: 36, alignment: .center)

                            Stepper("", value: $yearsInRole, in: 0...50)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                .stroke(IATheme.outlineVariant, lineWidth: 1)
                        }
                    }

                    profileField("LinkedIn URL", text: $linkedinUrl, placeholder: "linkedin.com/in/yourname", keyboardType: .URL)
                }
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Summary",
                subtitle: "A brief elevator pitch about yourself",
                symbol: "text.quote"
            )

            IAPanel(tone: .secondary) {
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: $summary)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100, maxHeight: 180)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                .stroke(IATheme.outlineVariant, lineWidth: 1)
                        }

                    Text("\(summary.count) characters")
                        .font(IATypography.labelSmall)
                        .foregroundStyle(IATheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Communication Style

    private var communicationStyleSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Communication Style",
                subtitle: "How should AI-generated responses sound?",
                symbol: "bubble.left.and.bubble.right.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: 10) {
                    ForEach(CommunicationStyle.allCases, id: \.self) { style in
                        communicationStyleRow(style)
                    }
                }
            }
        }
    }

    private func communicationStyleRow(_ style: CommunicationStyle) -> some View {
        let isSelected = communicationStyle == style

        return Button {
            withAnimation(IAAnimations.snappy) {
                communicationStyle = style
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? IATheme.accent : IATheme.accent.opacity(0.10))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: symbolForStyle(style))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : IATheme.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text(style.description)
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? IATheme.accent : IATheme.outlineVariant)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .fill(isSelected ? IATheme.accent.opacity(0.06) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(isSelected ? IATheme.accent : IATheme.outlineVariant.opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func symbolForStyle(_ style: CommunicationStyle) -> String {
        switch style {
        case .concise: return "arrow.right.circle"
        case .detailed: return "text.alignleft"
        case .storyteller: return "book.fill"
        }
    }

    // MARK: - Resume

    private var resumeSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Resume",
                subtitle: nil,
                symbol: "doc.text.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: 12) {
                    if !resumeText.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(IATheme.success)
                            Text(resumeDocumentName ?? "Resume loaded")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textPrimary)
                            Spacer()
                            Text("\(resumeText.count) characters")
                                .font(IATypography.labelSmall)
                                .foregroundStyle(IATheme.textTertiary)
                        }
                    }

                    HStack(spacing: 10) {
                        Button(action: { showFilePicker = true }) {
                            Label("Upload PDF", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(IASecondaryButtonStyle())

                        if !resumeText.isEmpty {
                            Button {
                                extractProfileFromResume()
                            } label: {
                                HStack(spacing: 6) {
                                    if isExtractingProfile {
                                        ProgressView()
                                            .tint(IATheme.accent)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    Text("Auto-fill")
                                        .font(IATypography.bodyMedium)
                                }
                            }
                            .buttonStyle(IASecondaryButtonStyle())
                            .disabled(isExtractingProfile)
                        }
                    }

                    TextEditor(text: $resumeText)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, maxHeight: 240)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                                .foregroundStyle(IATheme.outlineVariant)
                        }
                }
            }
        }
    }

    // MARK: - Work Experience

    private var workExperienceSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Work Experience",
                subtitle: nil,
                symbol: "briefcase.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing12) {
                    if workExperiences.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "briefcase")
                                .font(.system(size: 16))
                                .foregroundStyle(IATheme.textTertiary)
                            Text("No work experience added yet")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(workExperiences) { experience in
                            collectionRow(
                                title: experience.title,
                                subtitle: "\(experience.company) (\(String(experience.startYear))–\(experience.endYear.map(String.init) ?? "Present"))",
                                symbol: "building.2",
                                onEdit: { editingWorkExperience = experience },
                                onDelete: {
                                    withAnimation(IAAnimations.snappy) {
                                        workExperiences.removeAll { $0.id == experience.id }
                                    }
                                }
                            )
                        }
                    }

                    Button { showWorkExperienceEditor = true } label: {
                        Label("Add Experience", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Skills

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Skills",
                subtitle: nil,
                symbol: "star.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(alignment: .leading, spacing: 12) {
                    FlowLayout(spacing: 8) {
                        ForEach(skills) { skill in
                            IASkillChip(name: skillDisplayName(skill)) {
                                withAnimation(IAAnimations.snappy) {
                                    skills.removeAll { $0.id == skill.id }
                                }
                            }
                        }

                        addSkillField
                    }

                    HStack(spacing: 8) {
                        Text("Category:")
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textSecondary)

                        Picker("Category", selection: $newSkillCategory) {
                            ForEach(SkillCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if skills.isEmpty {
                        Text("Add skills to help personalize your responses")
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textTertiary)
                    }
                }
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

    // MARK: - Education

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Education",
                subtitle: nil,
                symbol: "graduationcap.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing12) {
                    if education.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "graduationcap")
                                .font(.system(size: 16))
                                .foregroundStyle(IATheme.textTertiary)
                            Text("No education added yet")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(education) { edu in
                            collectionRow(
                                title: "\(edu.degree)\(edu.field.map { " in \($0)" } ?? "")",
                                subtitle: "\(edu.institution)\(edu.endYear.map { " (\(String($0)))" } ?? "")",
                                symbol: "graduationcap",
                                onEdit: { editingEducation = edu },
                                onDelete: {
                                    withAnimation(IAAnimations.snappy) {
                                        education.removeAll { $0.id == edu.id }
                                    }
                                }
                            )
                        }
                    }

                    Button { showEducationEditor = true } label: {
                        Label("Add Education", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Certifications

    private var certificationsSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Certifications",
                subtitle: nil,
                symbol: "rosette"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing12) {
                    if certifications.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "rosette")
                                .font(.system(size: 16))
                                .foregroundStyle(IATheme.textTertiary)
                            Text("No certifications added yet")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(certifications) { cert in
                            collectionRow(
                                title: cert.name,
                                subtitle: [cert.issuer, cert.year.map(String.init)].compactMap { $0 }.joined(separator: " - "),
                                symbol: "rosette",
                                onEdit: { editingCertification = cert },
                                onDelete: {
                                    withAnimation(IAAnimations.snappy) {
                                        certifications.removeAll { $0.id == cert.id }
                                    }
                                }
                            )
                        }
                    }

                    Button { showCertificationEditor = true } label: {
                        Label("Add Certification", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Projects",
                subtitle: nil,
                symbol: "hammer.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing12) {
                    if projects.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "hammer")
                                .font(.system(size: 16))
                                .foregroundStyle(IATheme.textTertiary)
                            Text("No projects added yet")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(projects) { project in
                            collectionRow(
                                title: project.name,
                                subtitle: [project.techStack, project.year.map(String.init)].compactMap { $0 }.joined(separator: " - "),
                                symbol: "hammer",
                                onEdit: { editingProject = project },
                                onDelete: {
                                    withAnimation(IAAnimations.snappy) {
                                        projects.removeAll { $0.id == project.id }
                                    }
                                }
                            )
                        }
                    }

                    Button { showProjectEditor = true } label: {
                        Label("Add Project", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Achievements",
                subtitle: nil,
                symbol: "trophy.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing12) {
                    if achievements.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "trophy")
                                .font(.system(size: 16))
                                .foregroundStyle(IATheme.textTertiary)
                            Text("No achievements added yet")
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(achievements) { achievement in
                            collectionRow(
                                title: achievement.description,
                                subtitle: [achievement.metric, achievement.year.map(String.init)].compactMap { $0 }.joined(separator: " - "),
                                symbol: "trophy",
                                onEdit: { editingAchievement = achievement },
                                onDelete: {
                                    withAnimation(IAAnimations.snappy) {
                                        achievements.removeAll { $0.id == achievement.id }
                                    }
                                }
                            )
                        }
                    }

                    Button { showAchievementEditor = true } label: {
                        Label("Add Achievement", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Status Banners

    private var statusBanners: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if showSuccessBanner {
                Label("Profile saved successfully", systemImage: "checkmark.circle.fill")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IATheme.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    // MARK: - Shared Row

    private func collectionRow(
        title: String,
        subtitle: String,
        symbol: String,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(IATheme.accent.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(IATheme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(IATheme.error.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: - Field Helper

    private func profileField(_ title: String, text: Binding<String>, placeholder: String? = nil, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)

            TextField(placeholder ?? title, text: text)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
        }
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchProfile(id: profileId)
            profile = fetched
            populateFields(from: fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func populateFields(from p: InterviewProfile) {
        name = p.name
        currentRole = p.currentRole ?? ""
        currentCompany = p.currentCompany ?? ""
        yearsInRole = p.yearsInRole ?? 0
        linkedinUrl = p.linkedinUrl ?? ""
        summary = p.summary ?? ""
        resumeText = p.resumeText ?? ""

        if let styleRaw = p.communicationStyle,
           let style = CommunicationStyle(rawValue: styleRaw) {
            communicationStyle = style
        }

        workExperiences = p.workExperiences
        skills = p.skills
        education = p.education
        certifications = p.certifications
        projects = p.projects
        achievements = p.achievements
    }

    // MARK: - Save

    private func saveAll() async {
        isSaving = true
        errorMessage = nil
        showSuccessBanner = false

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let input = UpdateProfileInput(
                name: trimmedName.isEmpty ? nil : trimmedName,
                resumeText: resumeText,
                currentRole: currentRole,
                currentCompany: currentCompany,
                yearsInRole: yearsInRole,
                linkedinUrl: linkedinUrl,
                summary: summary,
                communicationStyle: communicationStyle.rawValue
            )

            _ = try await service.updateProfile(id: profileId, input)

            async let workTask: () = service.updateWorkExperiences(profileId: profileId, workExperiences)
            async let skillsTask: () = service.updateSkills(profileId: profileId, skills)
            async let eduTask: () = service.updateEducation(profileId: profileId, education)
            async let certTask: () = service.updateCertifications(profileId: profileId, certifications)
            async let projTask: () = service.updateProjects(profileId: profileId, projects)
            async let achieveTask: () = service.updateAchievements(profileId: profileId, achievements)

            _ = try await (workTask, skillsTask, eduTask, certTask, projTask, achieveTask)

            showSuccessBanner = true

            try? await Task.sleep(for: .seconds(2))
            showSuccessBanner = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Skills Helpers

    private func addSkill() {
        let trimmed = newSkillText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !skills.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            newSkillText = ""
            return
        }
        skills.append(ProfileSkillEntry(name: trimmed, category: newSkillCategory.rawValue))
        newSkillText = ""
    }

    private func skillDisplayName(_ skill: ProfileSkillEntry) -> String {
        if let category = skill.category, !category.isEmpty,
           let cat = SkillCategory(rawValue: category) {
            return "\(skill.name) (\(cat.shortLabel))"
        }
        return skill.name
    }

    // MARK: - Resume Helpers

    private func handleResumeFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            resumeDocumentName = url.lastPathComponent
            Task {
                do {
                    let extracted = try await ResumeTextExtractor.extract(from: url)
                    resumeText = extracted.text
                    if currentRole.isEmpty && currentCompany.isEmpty && skills.isEmpty {
                        extractProfileFromResume()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func extractProfileFromResume() {
        guard !resumeText.isEmpty else {
            errorMessage = "Add your resume text first, then tap Auto-fill."
            return
        }

        isExtractingProfile = true
        errorMessage = nil

        Task {
            do {
                let extracted = try await ResumeProfileExtractor.extract(from: resumeText)

                // Personal info — always overwrite with extracted data
                if let role = extracted.currentRole {
                    currentRole = role
                }
                if let company = extracted.currentCompany {
                    currentCompany = company
                }
                if let years = extracted.yearsInRole, years > 0 {
                    yearsInRole = years
                }
                if let extractedSummary = extracted.summary, !extractedSummary.isEmpty {
                    summary = extractedSummary
                }

                // Skills — merge (add new, keep existing)
                for skill in extracted.skills {
                    if !skills.contains(where: { $0.name.lowercased() == skill.name.lowercased() }) {
                        skills.append(ProfileSkillEntry(name: skill.name, category: skill.category))
                    }
                }

                // Work experiences — always replace with extracted data
                workExperiences = extracted.workExperiences.map { exp in
                    ProfileWorkExperience(
                        title: exp.title,
                        company: exp.company,
                        startYear: exp.startYear,
                        endYear: exp.endYear,
                        description: exp.description
                    )
                }

                // Education — always replace
                education = extracted.education.map { edu in
                    ProfileEducation(
                        institution: edu.institution,
                        degree: edu.degree,
                        field: edu.field,
                        startYear: edu.startYear,
                        endYear: edu.endYear
                    )
                }

                // Certifications — always replace
                certifications = extracted.certifications.map { cert in
                    ProfileCertification(
                        name: cert.name,
                        issuer: cert.issuer,
                        year: cert.year
                    )
                }

                // Projects — always replace
                projects = extracted.projects.map { proj in
                    ProfileProject(
                        name: proj.name,
                        description: proj.description,
                        techStack: proj.techStack,
                        year: proj.year
                    )
                }

                // Achievements — always replace
                achievements = extracted.achievements.map { ach in
                    ProfileAchievement(
                        description: ach.description,
                        metric: ach.metric,
                        year: ach.year
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isExtractingProfile = false
        }
    }
}

// MARK: - Skill Category

enum SkillCategory: String, CaseIterable, Sendable {
    case language
    case framework
    case tool
    case soft

    var displayName: String {
        switch self {
        case .language: return "Language"
        case .framework: return "Framework"
        case .tool: return "Tool"
        case .soft: return "Soft Skill"
        }
    }

    var shortLabel: String {
        switch self {
        case .language: return "Lang"
        case .framework: return "FW"
        case .tool: return "Tool"
        case .soft: return "Soft"
        }
    }
}

// MARK: - Work Experience Editor Sheet

struct ProfileWorkExperienceEditorSheet: View {
    @State private var title: String
    @State private var company: String
    @State private var startYear: String
    @State private var endYear: String
    @State private var isCurrentRole: Bool
    @State private var description: String

    private let existingId: String?
    private let onSave: (ProfileWorkExperience) -> Void
    @Environment(\.dismiss) private var dismiss

    init(experience: ProfileWorkExperience?, onSave: @escaping (ProfileWorkExperience) -> Void) {
        self.existingId = experience?.id
        self.onSave = onSave
        _title = State(initialValue: experience?.title ?? "")
        _company = State(initialValue: experience?.company ?? "")
        _startYear = State(initialValue: experience.map { String($0.startYear) } ?? "")
        _endYear = State(initialValue: experience?.endYear.map(String.init) ?? "")
        _isCurrentRole = State(initialValue: experience?.endYear == nil)
        _description = State(initialValue: experience?.description ?? "")
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && Int(startYear) != nil
        && (isCurrentRole || Int(endYear) != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing16) {
                        IAPanel(tone: .secondary) {
                            VStack(spacing: IATheme.spacing16) {
                                sheetField(title: "Job Title", text: $title, placeholder: "e.g., Software Engineer")
                                sheetField(title: "Company", text: $company, placeholder: "e.g., Google")
                                sheetField(title: "Start Year", text: $startYear, placeholder: "e.g., 2020", keyboardType: .numberPad)

                                Toggle(isOn: $isCurrentRole) {
                                    Text("I currently work here")
                                        .font(IATypography.labelLarge)
                                        .foregroundStyle(IATheme.textPrimary)
                                }
                                .tint(IATheme.accent)

                                if !isCurrentRole {
                                    sheetField(title: "End Year", text: $endYear, placeholder: "e.g., 2024", keyboardType: .numberPad)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Description")
                                        .font(IATypography.labelLarge)
                                        .foregroundStyle(IATheme.textPrimary)

                                    TextEditor(text: $description)
                                        .font(IATypography.bodyMedium)
                                        .foregroundStyle(IATheme.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 80, maxHeight: 160)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 10)
                                        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                                .stroke(IATheme.outlineVariant, lineWidth: 1)
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle(existingId != nil ? "Edit Experience" : "Add Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .foregroundStyle(isValid ? IATheme.accent : IATheme.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func saveEntry() {
        guard let start = Int(startYear) else { return }
        let end = isCurrentRole ? nil : Int(endYear)
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ProfileWorkExperience(
            id: existingId ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            company: company.trimmingCharacters(in: .whitespacesAndNewlines),
            startYear: start,
            endYear: end,
            description: desc.isEmpty ? nil : desc
        )
        onSave(entry)
        dismiss()
    }
}

// MARK: - Education Editor Sheet

struct ProfileEducationEditorSheet: View {
    @State private var institution: String
    @State private var degree: String
    @State private var field: String
    @State private var startYear: String
    @State private var endYear: String

    private let existingId: String?
    private let onSave: (ProfileEducation) -> Void
    @Environment(\.dismiss) private var dismiss

    init(education: ProfileEducation?, onSave: @escaping (ProfileEducation) -> Void) {
        self.existingId = education?.id
        self.onSave = onSave
        _institution = State(initialValue: education?.institution ?? "")
        _degree = State(initialValue: education?.degree ?? "")
        _field = State(initialValue: education?.field ?? "")
        _startYear = State(initialValue: education?.startYear.map(String.init) ?? "")
        _endYear = State(initialValue: education?.endYear.map(String.init) ?? "")
    }

    private var isValid: Bool {
        !institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !degree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing16) {
                        IAPanel(tone: .secondary) {
                            VStack(spacing: IATheme.spacing16) {
                                sheetField(title: "Institution", text: $institution, placeholder: "e.g., MIT")
                                sheetField(title: "Degree", text: $degree, placeholder: "e.g., B.S. Computer Science")
                                sheetField(title: "Field of Study", text: $field, placeholder: "e.g., Computer Science")
                                sheetField(title: "Start Year", text: $startYear, placeholder: "e.g., 2016", keyboardType: .numberPad)
                                sheetField(title: "End Year", text: $endYear, placeholder: "e.g., 2020", keyboardType: .numberPad)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle(existingId != nil ? "Edit Education" : "Add Education")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .foregroundStyle(isValid ? IATheme.accent : IATheme.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func saveEntry() {
        let fieldTrimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ProfileEducation(
            id: existingId ?? UUID().uuidString,
            institution: institution.trimmingCharacters(in: .whitespacesAndNewlines),
            degree: degree.trimmingCharacters(in: .whitespacesAndNewlines),
            field: fieldTrimmed.isEmpty ? nil : fieldTrimmed,
            startYear: Int(startYear),
            endYear: Int(endYear)
        )
        onSave(entry)
        dismiss()
    }
}

// MARK: - Certification Editor Sheet

struct ProfileCertificationEditorSheet: View {
    @State private var name: String
    @State private var issuer: String
    @State private var year: String

    private let existingId: String?
    private let onSave: (ProfileCertification) -> Void
    @Environment(\.dismiss) private var dismiss

    init(certification: ProfileCertification?, onSave: @escaping (ProfileCertification) -> Void) {
        self.existingId = certification?.id
        self.onSave = onSave
        _name = State(initialValue: certification?.name ?? "")
        _issuer = State(initialValue: certification?.issuer ?? "")
        _year = State(initialValue: certification?.year.map(String.init) ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing16) {
                        IAPanel(tone: .secondary) {
                            VStack(spacing: IATheme.spacing16) {
                                sheetField(title: "Certification Name", text: $name, placeholder: "e.g., AWS Solutions Architect")
                                sheetField(title: "Issuer", text: $issuer, placeholder: "e.g., Amazon Web Services")
                                sheetField(title: "Year", text: $year, placeholder: "e.g., 2023", keyboardType: .numberPad)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle(existingId != nil ? "Edit Certification" : "Add Certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .foregroundStyle(isValid ? IATheme.accent : IATheme.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func saveEntry() {
        let issuerTrimmed = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ProfileCertification(
            id: existingId ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            issuer: issuerTrimmed.isEmpty ? nil : issuerTrimmed,
            year: Int(year)
        )
        onSave(entry)
        dismiss()
    }
}

// MARK: - Project Editor Sheet

struct ProfileProjectEditorSheet: View {
    @State private var name: String
    @State private var description: String
    @State private var techStack: String
    @State private var url: String
    @State private var year: String

    private let existingId: String?
    private let onSave: (ProfileProject) -> Void
    @Environment(\.dismiss) private var dismiss

    init(project: ProfileProject?, onSave: @escaping (ProfileProject) -> Void) {
        self.existingId = project?.id
        self.onSave = onSave
        _name = State(initialValue: project?.name ?? "")
        _description = State(initialValue: project?.description ?? "")
        _techStack = State(initialValue: project?.techStack ?? "")
        _url = State(initialValue: project?.url ?? "")
        _year = State(initialValue: project?.year.map(String.init) ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing16) {
                        IAPanel(tone: .secondary) {
                            VStack(spacing: IATheme.spacing16) {
                                sheetField(title: "Project Name", text: $name, placeholder: "e.g., E-commerce Platform")

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Description")
                                        .font(IATypography.labelLarge)
                                        .foregroundStyle(IATheme.textPrimary)

                                    TextEditor(text: $description)
                                        .font(IATypography.bodyMedium)
                                        .foregroundStyle(IATheme.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 80, maxHeight: 160)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 10)
                                        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                                .stroke(IATheme.outlineVariant, lineWidth: 1)
                                        }
                                }

                                sheetField(title: "Tech Stack", text: $techStack, placeholder: "e.g., Swift, Node.js, PostgreSQL")
                                sheetField(title: "URL", text: $url, placeholder: "e.g., github.com/user/project", keyboardType: .URL)
                                sheetField(title: "Year", text: $year, placeholder: "e.g., 2024", keyboardType: .numberPad)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle(existingId != nil ? "Edit Project" : "Add Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .foregroundStyle(isValid ? IATheme.accent : IATheme.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func saveEntry() {
        let descTrimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let techTrimmed = techStack.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlTrimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ProfileProject(
            id: existingId ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descTrimmed.isEmpty ? nil : descTrimmed,
            techStack: techTrimmed.isEmpty ? nil : techTrimmed,
            url: urlTrimmed.isEmpty ? nil : urlTrimmed,
            year: Int(year)
        )
        onSave(entry)
        dismiss()
    }
}

// MARK: - Achievement Editor Sheet

struct ProfileAchievementEditorSheet: View {
    @State private var description: String
    @State private var metric: String
    @State private var year: String

    private let existingId: String?
    private let onSave: (ProfileAchievement) -> Void
    @Environment(\.dismiss) private var dismiss

    init(achievement: ProfileAchievement?, onSave: @escaping (ProfileAchievement) -> Void) {
        self.existingId = achievement?.id
        self.onSave = onSave
        _description = State(initialValue: achievement?.description ?? "")
        _metric = State(initialValue: achievement?.metric ?? "")
        _year = State(initialValue: achievement?.year.map(String.init) ?? "")
    }

    private var isValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing16) {
                        IAPanel(tone: .secondary) {
                            VStack(spacing: IATheme.spacing16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Description")
                                        .font(IATypography.labelLarge)
                                        .foregroundStyle(IATheme.textPrimary)

                                    TextEditor(text: $description)
                                        .font(IATypography.bodyMedium)
                                        .foregroundStyle(IATheme.textPrimary)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 80, maxHeight: 160)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 10)
                                        .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                                .stroke(IATheme.outlineVariant, lineWidth: 1)
                                        }
                                }

                                sheetField(title: "Metric", text: $metric, placeholder: "e.g., Reduced latency by 40%")
                                sheetField(title: "Year", text: $year, placeholder: "e.g., 2024", keyboardType: .numberPad)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle(existingId != nil ? "Edit Achievement" : "Add Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IATheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .foregroundStyle(isValid ? IATheme.accent : IATheme.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func saveEntry() {
        let metricTrimmed = metric.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ProfileAchievement(
            id: existingId ?? UUID().uuidString,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            metric: metricTrimmed.isEmpty ? nil : metricTrimmed,
            year: Int(year)
        )
        onSave(entry)
        dismiss()
    }
}

// MARK: - Shared Sheet Field Helper

private func sheetField(
    title: String,
    text: Binding<String>,
    placeholder: String,
    keyboardType: UIKeyboardType = .default
) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(IATypography.labelLarge)
            .foregroundStyle(IATheme.textPrimary)

        TextField(placeholder, text: text)
            .font(IATypography.bodyMedium)
            .foregroundStyle(IATheme.textPrimary)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(IATheme.surface, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
    }
}
