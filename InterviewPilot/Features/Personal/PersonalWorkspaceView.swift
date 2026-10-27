import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct PersonalWorkspaceView: View {
    @Bindable var store: LocalInterviewStore
    let onStart: (InterviewConfiguration) -> Void
    @State private var configuration: InterviewConfiguration
    @State private var editingProfile: CandidateProfile?
    @State private var showingSettings = false
    @State private var showingResumeImporter = false
    @State private var importingResume = false
    @State private var importingJob = false
    @State private var launching = false
    @State private var error: String?
    @State private var hasKey = false
    @Environment(\.scenePhase) private var scenePhase

    init(store: LocalInterviewStore, onStart: @escaping (InterviewConfiguration) -> Void) {
        self.store = store
        self.onStart = onStart
        _configuration = State(initialValue: store.draft)
    }

    var body: some View {
        TabView {
            Tab("Prepare", systemImage: "waveform.badge.mic") {
                NavigationStack { preparation }
            }
            Tab("Profiles", systemImage: "person.text.rectangle") {
                NavigationStack { profiles }
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                NavigationStack { history }
            }
        }
        .tint(.indigo)
        .onAppear { refreshKeyStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive { perform { try await store.saveDraft(configuration) } }
        }
        .sheet(item: $editingProfile) { profile in
            CandidateEditor(profile: profile) { updated in
                try await store.saveProfile(updated)
                configuration.useProfile(updated)
                try await store.saveDraft(configuration)
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: refreshKeyStatus) {
            PersonalSettingsView()
        }
        .alert("Unable to complete that action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .fileImporter(isPresented: $showingResumeImporter, allowedContentTypes: [.pdf, .plainText], allowsMultipleSelection: false) { result in
            importResume(result)
        }
    }

    private var preparation: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("InterviewPilot", systemImage: "waveform")
                        .font(.title2.bold())
                    Text("Your experience. A clearer answer.")
                        .font(.headline)
                    Text("Prepare your context, then get timely suggestions or practice one question at a time.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            recoverySection
            Section("Session") {
                Picker("Mode", selection: $configuration.mode) {
                    ForEach(InterviewRunMode.allCases) { Text($0.title).tag($0) }
                }
                if !store.profiles.isEmpty {
                    Menu {
                        ForEach(store.profiles) { profile in
                            Button(profile.name.isEmpty ? "Unnamed profile" : profile.name) {
                                configuration.useProfile(profile)
                            }
                        }
                    } label: {
                        Label(configuration.candidateName.isEmpty ? "Choose saved profile" : configuration.candidateName, systemImage: "person.crop.circle")
                    }
                }
                TextField("Candidate name", text: $configuration.candidateName)
                    .textContentType(.name)
                TextField("Target role", text: $configuration.role)
                TextField("Company", text: $configuration.company)
                Picker("Interview type", selection: $configuration.interviewType) {
                    ForEach(["General", "Behavioral", "Technical", "Leadership", "Recruiter screen"], id: \.self) { Text($0).tag($0) }
                }
            }
            Section {
                labeledEditor("Resume or experience", text: $configuration.resume, height: 140)
                Button { showingResumeImporter = true } label: {
                    Label(importingResume ? "Importing…" : "Import resume PDF or text", systemImage: "doc.badge.plus")
                }.disabled(importingResume)
                labeledEditor("Projects and verified accomplishments", text: $configuration.projects, height: 90)
            } header: {
                Text("Candidate facts")
            } footer: {
                Text("Specific facts make answers more useful. Missing experience will not be invented.")
            }
            Section("Interview context") {
                TextField("Job listing URL (optional)", text: $configuration.jobURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(action: importJob) {
                    Label(importingJob ? "Importing job listing…" : "Import job description from URL", systemImage: "link")
                }.disabled(importingJob || configuration.jobURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !configuration.jobURL.isEmpty && configuration.jobURL != configuration.importedJobURL {
                    Text("Import this URL to update the context, or clear it and paste the job description below.")
                        .font(.caption).foregroundStyle(.orange)
                }
                labeledEditor("Job description", text: $configuration.jobDescription, height: 130)
                labeledEditor("Notes, interview stage, and priorities", text: $configuration.notes, height: 90)
                Picker("Tone", selection: $configuration.tone) {
                    ForEach(InterviewAnswerTone.allCases) { Text($0.title).tag($0) }
                }
                Picker("Answer length", selection: $configuration.answerLength) {
                    ForEach(InterviewAnswerLength.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Context check") {
                Label(configuration.resume.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Resume not provided" : "Resume text ready",
                      systemImage: configuration.resume.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "circle" : "checkmark.circle.fill")
                Label(configuration.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Job description not provided" : "Job description text ready",
                      systemImage: configuration.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "circle" : "checkmark.circle.fill")
                Text("Review the extracted text above. The session uses that text to tailor answers. Up to 7,000 characters each of resume and job text are included; keep the most relevant details near the top.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button(action: launch) {
                    HStack {
                        Spacer()
                        if launching { ProgressView().padding(.trailing, 6) }
                        Label(configuration.mode == .practice ? "Start practice" : "Start listening", systemImage: configuration.mode == .practice ? "bubble.left.and.bubble.right.fill" : "mic.fill")
                            .font(.headline)
                        Spacer()
                    }.padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .disabled(launching || importingJob || importingResume || store.requiresRecovery)
                Button("Save setup") { perform { try await store.saveDraft(configuration) } }
                    .disabled(store.requiresRecovery)
                if !hasKey {
                    Button("Add your Deepgram key") { showingSettings = true }
                }
            } footer: {
                Text("Uses this device’s microphone. Audio and interview context are sent to Deepgram during a connected session. Deepgram usage consumes your account credit.")
            }
        }
        .navigationTitle("Prepare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
    }

    @ViewBuilder private var recoverySection: some View {
        if let message = store.errorMessage {
            Section("Local storage") {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                if store.requiresRecovery {
                    if store.hasBackup {
                        Button("Restore last backup") { perform {
                            try await store.restoreBackup()
                            configuration = store.draft
                        } }
                    }
                    Button("Start fresh and preserve unreadable file") { perform {
                        try await store.startFreshKeepingOriginal()
                        configuration = store.draft
                    } }
                } else {
                    Button("Retry saving") { perform { try await store.retrySave() } }
                }
            }
        }
    }

    private var profiles: some View {
        List {
            if store.profiles.isEmpty {
                ContentUnavailableView("Your candidate profiles", systemImage: "person.text.rectangle", description: Text("Save your resume and verified project details for future interviews."))
            }
            ForEach(store.profiles) { profile in
                Button { editingProfile = profile } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name.isEmpty ? "Unnamed profile" : profile.name).font(.headline).foregroundStyle(.primary)
                        Text(profile.role.isEmpty ? "Tap to edit" : profile.role).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in
                let ids = indices.map { store.profiles[$0].id }
                perform { for id in ids { try await store.deleteProfile(id) } }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editingProfile = CandidateProfile() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add candidate profile")
            }
        }
    }

    private var history: some View {
        List {
            if store.sessions.isEmpty {
                ContentUnavailableView("Your sessions stay here", systemImage: "clock", description: Text("Saved questions and answers are available offline on this device."))
            }
            ForEach(store.sessions) { session in
                NavigationLink {
                    SessionTranscriptDetail(session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.configuration.title).font(.headline)
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(session.messages.count) messages · \(session.configuration.mode.title)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in
                let ids = indices.map { store.sessions[$0].id }
                perform { for id in ids { try await store.deleteSession(id) } }
            }
        }
        .navigationTitle("History")
    }

    private func labeledEditor(_ label: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text).frame(minHeight: height).accessibilityLabel(label)
        }
    }

    private func refreshKeyStatus() {
        do { hasKey = try DeepgramKeyStore.load() != nil }
        catch { self.error = error.localizedDescription }
    }

    private func launch() {
        guard !importingJob && !importingResume else { return }
        let jobURL = configuration.jobURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard jobURL.isEmpty || (jobURL == configuration.importedJobURL && !configuration.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
            error = "Import the job listing first. If it cannot be opened, clear the URL and paste the job description before starting."
            return
        }
        refreshKeyStatus()
        guard hasKey else { showingSettings = true; return }
        launching = true
        Task {
            defer { launching = false }
            do {
                try await store.saveDraft(configuration)
                onStart(configuration)
            } catch { self.error = error.localizedDescription }
        }
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            do { try await operation() }
            catch { self.error = error.localizedDescription }
        }
    }

    private func importJob() {
        let requestedURL = configuration.jobURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedURL.isEmpty, !importingJob else { return }
        importingJob = true
        Task {
            defer { importingJob = false }
            do {
                let imported = try await JobDescriptionURLService().importJob(from: requestedURL)
                // An edit while the request was in flight must not overwrite a different listing.
                guard configuration.jobURL.trimmingCharacters(in: .whitespacesAndNewlines) == requestedURL else { return }
                configuration.jobDescription = imported.text
                configuration.jobURL = imported.url.absoluteString
                configuration.importedJobURL = imported.url.absoluteString
                if !imported.title.isEmpty { configuration.role = imported.title }
                if !imported.company.isEmpty { configuration.company = imported.company }
            } catch { self.error = error.localizedDescription }
        }
    }

    private func importResume(_ result: Result<[URL], Error>) {
        Task {
            importingResume = true
            defer { importingResume = false }
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let text = try await Task.detached(priority: .userInitiated) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= 20 * 1024 * 1024 else {
                        throw ResumeImportError.tooLarge
                    }
                    let extracted: String
                    if url.pathExtension.lowercased() == "pdf" {
                        guard let document = PDFDocument(url: url), !document.isLocked,
                              let content = document.string, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            throw ResumeImportError.noText
                        }
                        extracted = content
                    } else {
                        let data = try Data(contentsOf: url)
                        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                            throw ResumeImportError.noText
                        }
                        extracted = content
                    }
                    guard extracted.count <= 100_000 else { throw ResumeImportError.tooLong }
                    return extracted
                }.value
                configuration.resume = text
            } catch { self.error = error.localizedDescription }
        }
    }
}

nonisolated private enum ResumeImportError: LocalizedError {
    case tooLarge, noText, tooLong
    var errorDescription: String? {
        switch self {
        case .tooLarge: "Choose a resume smaller than 20 MB."
        case .noText: "This file has no readable text. For scanned PDFs, paste the resume text instead."
        case .tooLong: "This document is too long for a resume. Import a shorter document or paste the relevant experience."
        }
    }
}

private struct CandidateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: CandidateProfile
    var onSave: (CandidateProfile) async throws -> Void
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $profile.name)
                TextField("Role", text: $profile.role)
                Section("Resume and experience") {
                    TextEditor(text: $profile.resume).frame(minHeight: 180)
                }
                Section("Projects and verified accomplishments") {
                    TextEditor(text: $profile.projects).frame(minHeight: 140)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Candidate profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        saving = true
                        Task {
                            do { try await onSave(profile); dismiss() }
                            catch { self.error = error.localizedDescription }
                            saving = false
                        }
                    }.disabled(saving || profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct PersonalSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var saved = false
    @State private var message: String?
    @State private var isError = false
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(saved ? "Key saved on this device" : "Add an API key to connect", systemImage: saved ? "checkmark.shield" : "key")
                    SecureField(saved ? "Replace Deepgram API key" : "Deepgram API key", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                    Button(saved ? "Replace key" : "Save key") {
                        do {
                            try DeepgramKeyStore.save(key)
                            key = ""
                            saved = true
                            isError = false
                            message = "Saved securely in this device’s Keychain. The connection is checked when a session starts."
                        } catch { isError = true; message = error.localizedDescription }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if saved {
                        Button("Remove saved key", role: .destructive) { confirmRemove = true }
                    }
                } header: {
                    Text("Deepgram")
                } footer: {
                    Text("Your Deepgram account covers transcription and managed response generation. No separate OpenAI key is needed.")
                }
                if let message { Text(message).foregroundStyle(isError ? Color.red : Color.secondary) }
                Section("Your data") {
                    Text("Profiles and session history stay on this device. Export important sessions before deleting the app.")
                    Text("During a session, microphone audio and the context you provide are sent to Deepgram. Suggested answers are shown silently on screen.")
                    Link("Deepgram account and credits", destination: URL(string: "https://console.deepgram.com")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                do { saved = try DeepgramKeyStore.load() != nil }
                catch { isError = true; message = error.localizedDescription }
            }
            .confirmationDialog("Remove the key from this device?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove key", role: .destructive) {
                    do {
                        try DeepgramKeyStore.remove()
                        saved = false
                        key = ""
                        isError = false
                        message = "Key removed."
                    } catch { isError = true; message = error.localizedDescription }
                }
            }
        }
    }
}

private struct SessionTranscriptDetail: View {
    let session: SavedInterview
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.configuration.title).font(.title2.bold())
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                }
                ForEach(session.messages) { message in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(label(for: message)).font(.caption.bold()).foregroundStyle(.secondary)
                        Text(message.content).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(message.role == .assistant ? Color.indigo.opacity(0.08) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }
            }.padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: session.exportText) { Label("Export transcript", systemImage: "square.and.arrow.up") }
            }
        }
    }
    private func label(for message: InterviewMessage) -> String {
        if session.configuration.mode == .practice {
            return message.role == .user ? "CANDIDATE" : "INTERVIEWER"
        }
        return message.role == .user ? "HEARD / ENTERED" : "SUGGESTED ANSWER"
    }
}
