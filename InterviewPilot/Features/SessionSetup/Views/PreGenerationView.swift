import SwiftUI

struct PreGenerationView: View {
    let progress: (current: Int, total: Int)
    let answers: [PreComputedAnswer]
    let isGenerating: Bool

    var body: some View {
        VStack(spacing: IPTheme.spacing16) {
            if isGenerating {
                VStack(spacing: IPTheme.spacing12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(IPTheme.brandLight)
                        .scaleEffect(1.2)

                    Text("Pre-generating Q&A Bank...")
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(.white)

                    if progress.total > 0 {
                        ProgressView(value: Double(progress.current), total: Double(progress.total))
                            .tint(IPTheme.brand)
                            .padding(.horizontal, IPTheme.spacing24)

                        Text("\(progress.current) of \(progress.total) questions")
                            .font(IPTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(IPTheme.spacing24)
            }

            if !answers.isEmpty {
                VStack(alignment: .leading, spacing: IPTheme.spacing8) {
                    Text("Generated \(answers.count) Q&A Pairs")
                        .font(IPTypography.bodyLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    ForEach(answers.prefix(5)) { answer in
                        HStack(alignment: .top, spacing: IPTheme.spacing8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(IPTheme.success)
                                .font(.system(size: 12))
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(answer.question)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(2)

                                Text(answer.questionType.displayName)
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(IPTheme.questionTypeColor(answer.questionType).opacity(0.8))
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if answers.count > 5 {
                        Text("+\(answers.count - 5) more questions ready")
                            .font(IPTypography.labelMedium)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(IPTheme.spacing16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
            }
        }
    }
}
