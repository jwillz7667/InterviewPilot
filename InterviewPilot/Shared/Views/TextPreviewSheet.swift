import SwiftUI

struct TextPreviewSheet: View {
    let title: String
    let subtitle: String
    let text: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        IPPanel(tone: .secondary) {
                            VStack(alignment: .leading, spacing: 14) {
                                IPSectionHeader(
                                    eyebrow: "Preview",
                                    title: title,
                                    subtitle: subtitle,
                                    symbol: "doc.text.magnifyingglass"
                                )

                                Text(text)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .ipInsetSurface(cornerRadius: 20)
                            }
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.accent)
                }
            }
        }
    }
}
