import SwiftUI
import UniformTypeIdentifiers

struct ResumeInputView: View {
    @Binding var resumeText: String
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(IPTheme.backgroundTop).ignoresSafeArea()

                VStack(spacing: IPTheme.spacing16) {
                    // Upload button
                    Button(action: { showFilePicker = true }) {
                        VStack(spacing: IPTheme.spacing12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(IPTheme.brandLight)

                            Text("Upload PDF Resume")
                                .font(IPTypography.bodyLarge)
                                .foregroundStyle(.white)

                            Text("Tap to select a file")
                                .font(IPTypography.labelSmall)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, IPTheme.spacing24)
                        .background(
                            RoundedRectangle(cornerRadius: IPTheme.radiusMedium)
                                .strokeBorder(IPTheme.brand.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )
                    }
                    .padding(.horizontal, IPTheme.spacing16)

                    // Or paste text
                    Text("or paste your resume text below")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.4))

                    TextEditor(text: $resumeText)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .padding(IPTheme.spacing12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
                        .padding(.horizontal, IPTheme.spacing16)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.brandLight)
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
