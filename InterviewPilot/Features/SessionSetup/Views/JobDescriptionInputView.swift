import SwiftUI

struct JobDescriptionInputView: View {
    @Binding var jobDescription: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(IPTheme.backgroundTop).ignoresSafeArea()

                VStack(spacing: IPTheme.spacing16) {
                    Text("Paste the full job description below")
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, IPTheme.spacing16)

                    TextEditor(text: $jobDescription)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .padding(IPTheme.spacing12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
                        .padding(.horizontal, IPTheme.spacing16)

                    if !jobDescription.isEmpty {
                        let keywords = JobDescriptionService.extractKeywords(from: jobDescription)
                        if !keywords.isEmpty {
                            VStack(alignment: .leading, spacing: IPTheme.spacing8) {
                                Text("Detected Keywords")
                                    .font(IPTypography.labelMedium)
                                    .foregroundStyle(.white.opacity(0.5))

                                FlowLayout(spacing: 6) {
                                    ForEach(keywords, id: \.self) { keyword in
                                        Text(keyword)
                                            .font(IPTypography.labelSmall)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(IPTheme.brand.opacity(0.3), in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, IPTheme.spacing16)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Job Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IPTheme.brandLight)
                }
            }
        }
    }
}

// Simple flow layout for keyword tags
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
