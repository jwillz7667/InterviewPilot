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
                        .tint(IPTheme.accentForeground)
                        .scaleEffect(1.1)

                    Text("Building your Q&A bank...")
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    if progress.total > 0 {
                        ProgressView(value: Double(progress.current), total: Double(progress.total))
                            .tint(IPTheme.accentForeground)

                        Text("\(progress.current) of \(progress.total) questions prepared")
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if !answers.isEmpty {
                VStack(alignment: .leading, spacing: IPTheme.spacing12) {
                    Text("Prepared questions")
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    ForEach(answers.prefix(5)) { answer in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(IPTheme.success)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(answer.question)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.textPrimary)
                                    .lineLimit(2)

                                Text(answer.questionType.displayName)
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(IPTheme.questionTypeColor(answer.questionType))
                            }
                        }
                    }

                    if answers.count > 5 {
                        Text("+\(answers.count - 5) more questions ready")
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
