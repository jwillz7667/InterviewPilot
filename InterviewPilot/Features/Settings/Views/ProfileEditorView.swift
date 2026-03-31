import SwiftUI

struct ProfileEditorView: View {
    @State private var authService = AuthService.shared
    @State private var displayName = ""
    @State private var linkedInURL = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    IABrandLogo(size: 54, showShadow: false, variant: .filled)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(authService.currentUser?.email ?? "")
                                            .font(IATypography.bodyMedium)
                                            .foregroundStyle(IATheme.textSecondary)

                                        Text("Edit your profile details below.")
                                            .font(IATypography.bodySmall)
                                            .foregroundStyle(IATheme.textTertiary)
                                    }

                                    Spacer()
                                }

                                IAInputShell(icon: "person.text.rectangle", title: "Display Name") {
                                    TextField("Your name", text: $displayName)
                                        .font(IATypography.bodyMedium)
                                        .foregroundStyle(IATheme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                        .iaInsetSurface(cornerRadius: 20)
                                }

                                IAInputShell(icon: "link", title: "LinkedIn URL", subtitle: "Optional — helps personalize interview prep.") {
                                    TextField("linkedin.com/in/yourname", text: $linkedInURL)
                                        .font(IATypography.bodyMedium)
                                        .foregroundStyle(IATheme.textPrimary)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.URL)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                        .iaInsetSurface(cornerRadius: 20)
                                }

                                if let errorMessage {
                                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                        .font(IATypography.bodySmall)
                                        .foregroundStyle(IATheme.error)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }

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
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
            .onAppear {
                displayName = authService.currentUser?.displayName ?? ""
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await authService.updateProfile(displayName: displayName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
