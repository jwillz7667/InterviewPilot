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
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    IABrandLogo(size: 40, showShadow: false, variant: .surface)
                                    Spacer()
                                    IAStarburst(size: 28)
                                }

                                IASectionHeader(
                                    eyebrow: "Preview",
                                    title: title,
                                    subtitle: subtitle,
                                    symbol: "doc.text.magnifyingglass"
                                )

                                Text(text)
                                    .font(IATypography.bodyMedium)
                                    .foregroundStyle(IATheme.insetSurfacePrimaryText(for: colorScheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(18)
                                    .iaInsetSurface(cornerRadius: 24)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IATheme.accent)
                }
            }
        }
    }
}
