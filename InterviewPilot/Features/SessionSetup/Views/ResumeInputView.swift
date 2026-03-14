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
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        IPPanel(tone: .accent(IPTheme.accent)) {
                            VStack(alignment: .leading, spacing: 14) {
                                IPSectionHeader(
                                    eyebrow: "Resume",
                                    title: "Import or paste your resume",
                                    subtitle: "A full resume gives the app better language for tailored answers and prep questions.",
                                    symbol: "doc.text.fill"
                                )

                                Button(action: { showFilePicker = true }) {
                                    Label("Upload PDF Resume", systemImage: "doc.badge.plus")
                                }
                                .buttonStyle(IPSecondaryButtonStyle())

                                TextEditor(text: $resumeText)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 260)
                                    .padding(12)
                                    .ipInsetSurface(cornerRadius: 20)
                            }
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
            .navigationTitle("Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.accent)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let text = ResumeParserService.extractText(from: url) {
                        resumeText = text
                    }
                }
            }
        }
    }
}
