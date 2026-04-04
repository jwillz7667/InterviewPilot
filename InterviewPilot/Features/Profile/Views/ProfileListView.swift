import SwiftUI

struct ProfileListView: View {
    @State private var viewModel = ProfileListViewModel()
    @State private var showCreateAlert = false
    @State private var newProfileName = ""
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        if !viewModel.hasFeature {
                            gatedState
                        } else if viewModel.profiles.isEmpty && !viewModel.isLoading {
                            emptyState
                        } else {
                            headerInfo
                            profileCards
                            addButton
                        }

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()

                if viewModel.isLoading && viewModel.profiles.isEmpty {
                    ProgressView()
                        .tint(IATheme.accent)
                }
            }
            .navigationTitle("Interview Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
            .alert("Create Profile", isPresented: $showCreateAlert) {
                TextField("Profile name", text: $newProfileName)
                Button("Cancel", role: .cancel) {
                    newProfileName = ""
                }
                Button("Create") {
                    let name = newProfileName
                    newProfileName = ""
                    Task { await viewModel.createProfile(name: name) }
                }
            } message: {
                Text("Enter a name for your new interview profile.")
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
            }
            .task {
                await viewModel.loadProfiles()
            }
        }
    }

    // MARK: - Header

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interview Profiles")
                .font(IATypography.headlineLarge)
                .foregroundStyle(IATheme.textPrimary)

            Text("\(viewModel.profilesUsed) of \(viewModel.profileLimit) profiles used")
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Profile Cards

    private var profileCards: some View {
        VStack(spacing: IATheme.spacing12) {
            ForEach(viewModel.profiles) { profile in
                NavigationLink(value: profile.id) {
                    profileCard(profile)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if !profile.isDefault {
                        Button {
                            Task { await viewModel.setDefault(id: profile.id) }
                        } label: {
                            Label("Set as Default", systemImage: "checkmark.circle")
                        }
                    }

                    if !profile.isDefault {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteProfile(id: profile.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationDestination(for: String.self) { profileId in
            ProfileDetailEditorView(profileId: profileId)
        }
    }

    private func profileCard(_ profile: InterviewProfileSummary) -> some View {
        IAPanel(tone: .secondary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(profile.name)
                                .font(IATypography.headlineSmall)
                                .foregroundStyle(IATheme.textPrimary)
                                .lineLimit(1)

                            if profile.isDefault {
                                Label("Default", systemImage: "checkmark.circle.fill")
                                    .font(IATypography.labelSmall)
                                    .foregroundStyle(IATheme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(IATheme.accent.opacity(0.10), in: Capsule())
                            }
                        }

                        if let role = profile.currentRole {
                            let subtitle = [role, profile.currentCompany].compactMap { $0 }.joined(separator: " @ ")
                            Text(subtitle)
                                .font(IATypography.bodyMedium)
                                .foregroundStyle(IATheme.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IATheme.textTertiary)
                }

                HStack(spacing: 8) {
                    if profile.skillCount > 0 {
                        statChip(count: profile.skillCount, label: "skills", symbol: "star.fill")
                    }
                    if profile.workExperienceCount > 0 {
                        statChip(count: profile.workExperienceCount, label: "roles", symbol: "briefcase.fill")
                    }
                    if profile.educationCount > 0 {
                        statChip(count: profile.educationCount, label: "degrees", symbol: "graduationcap.fill")
                    }
                    if profile.projectCount > 0 {
                        statChip(count: profile.projectCount, label: "projects", symbol: "hammer.fill")
                    }
                }
            }
        }
    }

    private func statChip(count: Int, label: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count) \(label)")
                .font(IATypography.labelSmall)
        }
        .foregroundStyle(IATheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(IATheme.surface.opacity(0.6), in: Capsule())
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showCreateAlert = true
        } label: {
            Label("Create New Profile", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(IAPrimaryButtonStyle(isEnabled: viewModel.canAddProfile))
        .disabled(!viewModel.canAddProfile)
    }

    // MARK: - Gated State

    private var gatedState: some View {
        VStack(spacing: IATheme.spacing20) {
            IAEmptyState(
                title: "Interview Profiles",
                subtitle: "Upgrade to unlock personalized profiles that tailor AI responses to your unique experience and career goals.",
                symbol: "lock.fill"
            )

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to Unlock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IAPrimaryButtonStyle())
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: IATheme.spacing20) {
            IAEmptyState(
                title: "Create Your First Profile",
                subtitle: "Interview profiles store your resume, skills, and experience to generate tailored responses during live sessions.",
                symbol: "person.crop.rectangle.stack"
            )

            Button {
                showCreateAlert = true
            } label: {
                Label("Create New Profile", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IAPrimaryButtonStyle())
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
