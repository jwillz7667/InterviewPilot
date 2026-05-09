import SwiftUI
import UniformTypeIdentifiers

struct ResumeInputView: View {
    @Binding var resumeText: String
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        IAPanel(tone: .primary, padding: 22, cornerRadius: 30) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    IABrandLogo(size: 42, showShadow: false, variant: .surface)
                                    Spacer()
                                    Button(action: { showFilePicker = true }) {
                                        Label("Upload File", systemImage: "doc.badge.plus")
                                    }
                                    .buttonStyle(IASecondaryButtonStyle())
                                }

                                IASectionHeader(
                                    eyebrow: "Resume",
                                    title: "Import or paste your resume",
                                    subtitle: "A full resume gives the app better role-specific language for response guidance and prep generation.",
                                    symbol: "doc.text.fill"
                                )

                                TextEditor(text: $resumeText)
                                    .font(IATypography.bodyMedium)
                                    .foregroundStyle(IATheme.insetSurfacePrimaryText(for: colorScheme))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 320)
                                    .padding(16)
                                    .iaInsetSurface(cornerRadius: 24)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle("Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: ResumeFileFormat.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task {
                        if let extracted = try? await ResumeTextExtractor.extract(from: url) {
                            resumeText = extracted.text
                        }
                    }
                }
            }
        }
    }
}
