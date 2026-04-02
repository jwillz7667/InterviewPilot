import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @State private var authService = AuthService.shared
    @State private var profileService = ProfileService.shared

    // Personal info
    @State private var displayName = ""
    @State private var linkedInURL = ""

    // Current position
    @State private var currentRole = ""
    @State private var currentCompany = ""
    @State private var yearsInRole = 0

    // Career goal
    @State private var primaryGoal: UserGoal?

    // Work experience
    @State private var workExperiences: [WorkExperienceEntry] = []
    @State private var isAddingExperience = false
    @State private var editingExperience: WorkExperienceEntry?

    // Resume
    @State private var resumeText = ""
    @State private var resumeDocumentName: String?
    @State private var showFilePicker = false
    @State private var showResumeEditor = false

    // Skills
    @State private var skills: [SkillEntry] = []
    @State private var newSkillText = ""

    // State
    @State private var isSaving = false
    @State private var isExtractingProfile = false
    @State private var errorMessage: String?
    @State private var showSuccessBanner = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        headerSection
                        if !resumeText.isEmpty && currentRole.isEmpty && skills.isEmpty && workExperiences.isEmpty && !isExtractingProfile {
                            autoFillSuggestion
                        }
                        personalInfoSection
                        currentPositionSection
                        careerGoalSection
                        workExperienceSection
                        resumeSection
                        skillsSection
                        infoBanner
                        actionButtons
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
            .onAppear { loadFromProfile() }
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
            .sheet(isPresented: $isAddingExperience) {
                WorkExperienceEditorSheet(
                    experience: nil,
                    onSave: { entry in
                        workExperiences.append(entry)
                    }
                )
            }
            .sheet(item: $editingExperience) { experience in
                WorkExperienceEditorSheet(
                    experience: experience,
                    onSave: { updated in
                        if let idx = workExperiences.firstIndex(where: { $0.id == updated.id }) {
                            workExperiences[idx] = updated
                        }
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Profile")
                .font(IATypography.headlineLarge)
                .foregroundStyle(IATheme.textPrimary)

            Text("Your profile helps generate interview responses tailored to your experience.")
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            .background(IATheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                    .stroke(IATheme.outlineVariant.opacity(0.5), lineWidth: 1)
                            }
                    }

                    profileField(
                        title: "LinkedIn URL",
                        text: $linkedInURL,
                        placeholder: "linkedin.com/in/yourname",
                        keyboardType: .URL,
                        textContentType: .URL
                    )
                }
            }
        }
    }

    // MARK: - Current Position

    private var currentPositionSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Current Position",
                subtitle: nil,
                symbol: "building.2.fill"
            )

            IAPanel(tone: .secondary) {
                VStack(spacing: IATheme.spacing16) {
                    profileField(
                        title: "Current Role",
                        text: $currentRole,
                        placeholder: "e.g., Senior Software Engineer"
                    )

                    profileField(
                        title: "Current Company",
                        text: $currentCompany,
                        placeholder: "e.g., Google"
                    )

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
                }
            }
        }
    }

    // MARK: - Career Goal

    private var careerGoalSection: some View {
        VStack(alignment: .leading, spacing: IATheme.spacing12) {
            IASectionHeader(
                eyebrow: nil,
                title: "Career Goal",
                subtitle: nil,
                symbol: "target"
            )

            IAPanel(tone: .secondary) {
                VStack(alignment: .leading, spacing: IATheme.spacing12) {
                    Text("Primary Goal")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(UserGoal.allCases) { goal in
                            goalRow(goal)
                        }
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: UserGoal) -> some View {
        let isSelected = primaryGoal == goal

        return Button {
            withAnimation(IAAnimations.snappy) {
                primaryGoal = goal
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? IATheme.accent : IATheme.accent.opacity(0.10))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: goal.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : IATheme.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text(goal.subtitle)
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                        .lineLimit(1)
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
                            workExperienceRow(experience)
                        }
                    }

                    Button {
                        isAddingExperience = true
                    } label: {
                        Label("Add Experience", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }
            }
        }
    }

    private func workExperienceRow(_ experience: WorkExperienceEntry) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(IATheme.accent.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "building.2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(experience.title)
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)

                Text("\(experience.company) (\(String(experience.startYear))–\(experience.endYear.map(String.init) ?? "Present"))")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                editingExperience = experience
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(IATheme.textTertiary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(IAAnimations.snappy) {
                    workExperiences.removeAll { $0.id == experience.id }
                }
            } label: {
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

                        Button(action: { showResumeEditor = true }) {
                            Label("Edit Text", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(IASecondaryButtonStyle())
                    }

                    if !resumeText.isEmpty {
                        Button(action: extractProfileFromResume) {
                            HStack(spacing: 10) {
                                if isExtractingProfile {
                                    ProgressView()
                                        .tint(IATheme.accent)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Text(isExtractingProfile ? "Analyzing resume..." : "Auto-fill profile from resume")
                                    .font(IATypography.labelLarge)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IAPrimaryButtonStyle(isEnabled: !isExtractingProfile))
                        .disabled(isExtractingProfile)
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
                VStack(alignment: .leading, spacing: 10) {
                    FlowLayout(spacing: 8) {
                        ForEach(skills) { skill in
                            IASkillChip(name: skill.name) {
                                withAnimation(IAAnimations.snappy) {
                                    skills.removeAll { $0.id == skill.id }
                                }
                            }
                        }

                        addSkillField
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

    // MARK: - Info Banner

    private var infoBanner: some View {
        IAPanel(tone: .accent(IATheme.accent), padding: IATheme.spacing16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(IATheme.accent)

                Text("This information is used to personalize your interview responses. The more detail you provide, the more specific and authentic your answers will be.")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Auto-fill Suggestion

    private var autoFillSuggestion: some View {
        IAPanel(tone: .accent(IATheme.accent), padding: IATheme.spacing16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(IATheme.accent)

                    Text("Auto-fill your profile")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)
                }

                Text("We can analyze your resume to automatically fill in your role, skills, and work history.")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)

                Button(action: extractProfileFromResume) {
                    Text("Auto-fill now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IAPrimaryButtonStyle())
            }
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

            if showSuccessBanner {
                Label("Profile saved successfully", systemImage: "checkmark.circle.fill")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IATheme.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func profileField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
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
                .textContentType(textContentType)
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
            currentRole = profile.currentRole ?? ""
            currentCompany = profile.currentCompany ?? ""
            yearsInRole = profile.yearsInRole ?? 0
            resumeText = profile.resumeText ?? ""
            skills = profile.skills
            workExperiences = profile.workExperiences

            if let goalStr = profile.primaryGoal {
                primaryGoal = UserGoal(rawValue: goalStr)
            }
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

    private func extractProfileFromResume() {
        guard !resumeText.isEmpty else { return }
        guard let apiKey = KeychainService.load(key: .openAIAPIKey), !apiKey.isEmpty else {
            errorMessage = "API key not available. Start an interview session first to configure keys."
            return
        }

        isExtractingProfile = true
        errorMessage = nil

        Task {
            do {
                let extracted = try await ResumeProfileExtractor.extract(from: resumeText, apiKey: apiKey)

                if let role = extracted.currentRole, currentRole.isEmpty {
                    currentRole = role
                }
                if let company = extracted.currentCompany, currentCompany.isEmpty {
                    currentCompany = company
                }
                if let years = extracted.yearsInRole, yearsInRole == 0 {
                    yearsInRole = years
                }

                for skillName in extracted.skills {
                    if !skills.contains(where: { $0.name.lowercased() == skillName.lowercased() }) {
                        skills.append(SkillEntry(name: skillName))
                    }
                }

                if workExperiences.isEmpty {
                    workExperiences = extracted.workExperiences.map { exp in
                        WorkExperienceEntry(
                            title: exp.title,
                            company: exp.company,
                            startYear: exp.startYear,
                            endYear: exp.endYear
                        )
                    }
                }

                showSuccessBanner = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isExtractingProfile = false
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        showSuccessBanner = false

        Task {
            do {
                let updates = ProfileUpdate(
                    displayName: displayName,
                    linkedinUrl: linkedInURL.isEmpty ? nil : linkedInURL,
                    primaryGoal: primaryGoal?.rawValue,
                    resumeText: resumeText.isEmpty ? nil : resumeText,
                    currentRole: currentRole.isEmpty ? nil : currentRole,
                    currentCompany: currentCompany.isEmpty ? nil : currentCompany,
                    yearsInRole: yearsInRole > 0 ? yearsInRole : nil
                )
                try await profileService.updateProfile(updates)

                // Sync display name to Keychain for local persistence
                if !displayName.isEmpty {
                    _ = KeychainService.save(key: .displayName, value: displayName)
                }

                if !workExperiences.isEmpty {
                    try await profileService.updateWorkExperience(workExperiences)
                }

                try await profileService.updateSkills(skills)

                showSuccessBanner = true

                try? await Task.sleep(for: .seconds(1.2))
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
                    if currentRole.isEmpty && currentCompany.isEmpty && skills.isEmpty {
                        extractProfileFromResume()
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Work Experience Editor Sheet

struct WorkExperienceEditorSheet: View {
    @State private var title: String
    @State private var company: String
    @State private var startYear: String
    @State private var endYear: String
    @State private var isCurrentRole: Bool

    private let existingId: String?
    private let onSave: (WorkExperienceEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    init(experience: WorkExperienceEntry?, onSave: @escaping (WorkExperienceEntry) -> Void) {
        self.existingId = experience?.id
        self.onSave = onSave
        _title = State(initialValue: experience?.title ?? "")
        _company = State(initialValue: experience?.company ?? "")
        _startYear = State(initialValue: experience.map { String($0.startYear) } ?? "")
        _endYear = State(initialValue: experience?.endYear.map(String.init) ?? "")
        _isCurrentRole = State(initialValue: experience?.endYear == nil)
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
                                fieldRow(title: "Job Title", text: $title, placeholder: "e.g., Software Engineer")
                                fieldRow(title: "Company", text: $company, placeholder: "e.g., Google")

                                fieldRow(title: "Start Year", text: $startYear, placeholder: "e.g., 2020", keyboardType: .numberPad)

                                Toggle(isOn: $isCurrentRole) {
                                    Text("I currently work here")
                                        .font(IATypography.labelLarge)
                                        .foregroundStyle(IATheme.textPrimary)
                                }
                                .tint(IATheme.accent)

                                if !isCurrentRole {
                                    fieldRow(title: "End Year", text: $endYear, placeholder: "e.g., 2024", keyboardType: .numberPad)
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
                    Button("Save") { saveExperience() }
                        .foregroundStyle(isValid ? IATheme.accent : IATheme.textTertiary)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func fieldRow(
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

    private func saveExperience() {
        guard let start = Int(startYear) else { return }
        let end = isCurrentRole ? nil : Int(endYear)
        let entry = WorkExperienceEntry(
            id: existingId ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            company: company.trimmingCharacters(in: .whitespacesAndNewlines),
            startYear: start,
            endYear: end
        )
        onSave(entry)
        dismiss()
    }
}
