import SwiftUI

struct PreGenerationView: View {
    let progress: (current: Int, total: Int)
    let answers: [PreComputedAnswer]
    let isGenerating: Bool

    var body: some View {
        VStack(spacing: IATheme.spacing16) {
            if isGenerating {
                IAPanel(tone: .secondary, padding: 18, cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(IATheme.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Building your prep bank")
                                    .font(IATypography.bodyLarge)
                                    .foregroundStyle(IATheme.textPrimary)

                                Text("Personalized questions and fast-answer scaffolds are being prepared.")
                                    .font(IATypography.bodySmall)
                                    .foregroundStyle(IATheme.textSecondary)
                            }
                        }

                        if progress.total > 0 {
                            ProgressView(value: Double(progress.current), total: Double(progress.total))
                                .tint(IATheme.accent)

                            Text("\(progress.current) of \(progress.total) questions ready")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                    }
                }
            }

            if !answers.isEmpty {
                IAPanel(tone: .secondary, padding: 18, cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prepared questions")
                            .font(IATypography.bodyLarge)
                            .foregroundStyle(IATheme.textPrimary)

                        ForEach(answers.prefix(5)) { answer in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(IATheme.questionTypeColor(answer.questionType).opacity(0.14))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(IATheme.questionTypeColor(answer.questionType))
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(answer.question)
                                        .font(IATypography.bodyMedium)
                                        .foregroundStyle(IATheme.textPrimary)
                                        .lineLimit(2)

                                    Text(answer.questionType.displayName)
                                        .font(IATypography.labelSmall)
                                        .foregroundStyle(IATheme.questionTypeColor(answer.questionType))
                                }

                                Spacer()
                            }
                        }

                        if answers.count > 5 {
                            Text("+\(answers.count - 5) more questions ready")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}
