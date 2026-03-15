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
                        IPPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    IPBrandLogo(size: 40, showShadow: false, variant: .surface)
                                    Spacer()
                                    IPStarburst(size: 28)
                                }

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
                                    .padding(18)
                                    .ipInsetSurface(cornerRadius: 24)
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
