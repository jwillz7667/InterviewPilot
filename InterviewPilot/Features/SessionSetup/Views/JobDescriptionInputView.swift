import SwiftUI

struct JobDescriptionInputView: View {
    @Binding var jobDescription: String
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
                                    eyebrow: "Job Post",
                                    title: "Paste the full job description",
                                    subtitle: "Include the responsibilities, requirements, and preferred skills so the interview plan stays grounded.",
                                    symbol: "briefcase.fill"
                                )

                                TextEditor(text: $jobDescription)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 280)
                                    .padding(12)
                                    .ipInsetSurface(cornerRadius: 20)

                                let keywords = JobDescriptionService.extractKeywords(from: jobDescription)
                                if !keywords.isEmpty {
                                    FlowLayout(spacing: 8) {
                                        ForEach(keywords, id: \.self) { keyword in
                                            Text(keyword)
                                                .font(IPTypography.labelSmall)
                                                .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.white, in: Capsule())
                                                .overlay {
                                                    Capsule()
                                                        .stroke(IPTheme.insetSurfaceBorder(for: colorScheme, selected: false), lineWidth: 1)
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.vertical, IPTheme.spacing20)
                }
                .ipScrollablePage()
            }
            .navigationTitle("Job Description")
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
