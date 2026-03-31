import SwiftUI

struct JobDescriptionInputView: View {
    @Binding var jobDescription: String
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
                                    IAStarburst(size: 28)
                                }

                                IASectionHeader(
                                    eyebrow: "Job Post",
                                    title: "Paste the full job description",
                                    subtitle: "Include responsibilities, requirements, and preferred skills so the session stays grounded in the actual role.",
                                    symbol: "briefcase.fill"
                                )

                                TextEditor(text: $jobDescription)
                                    .font(IATypography.bodyMedium)
                                    .foregroundStyle(IATheme.insetSurfacePrimaryText(for: colorScheme))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 300)
                                    .padding(16)
                                    .iaInsetSurface(cornerRadius: 24)

                                let keywords = JobDescriptionService.extractKeywords(from: jobDescription)
                                if !keywords.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(keywords, id: \.self) { keyword in
                                            Text(keyword)
                                                .font(IATypography.labelSmall)
                                                .foregroundStyle(IATheme.accent)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(IATheme.accent.opacity(0.10), in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.vertical, IATheme.spacing20)
                }
                .iaScrollablePage()
            }
            .navigationTitle("Job Description")
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), offsets)
    }
}
