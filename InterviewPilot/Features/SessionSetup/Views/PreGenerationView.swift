import SwiftUI

struct PreGenerationView: View {
    let progress: (current: Int, total: Int)
    let answers: [PreComputedAnswer]
    let isGenerating: Bool

    var body: some View {
        VStack(spacing: IPTheme.spacing16) {
            if isGenerating {
                IPPanel(tone: .secondary, padding: 18, cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(IPTheme.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Building your prep bank")
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.textPrimary)

                                Text("Personalized questions and fast-answer scaffolds are being prepared.")
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.textSecondary)
                            }
                        }

                        if progress.total > 0 {
                            ProgressView(value: Double(progress.current), total: Double(progress.total))
                                .tint(IPTheme.accent)

                            Text("\(progress.current) of \(progress.total) questions ready")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.textSecondary)
                        }
                    }
                }
            }

            if !answers.isEmpty {
                IPPanel(tone: .secondary, padding: 18, cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prepared questions")
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textPrimary)

                        ForEach(answers.prefix(5)) { answer in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(IPTheme.questionTypeColor(answer.questionType).opacity(0.14))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(IPTheme.questionTypeColor(answer.questionType))
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(answer.question)
                                        .font(IPTypography.bodyMedium)
                                        .foregroundStyle(IPTheme.textPrimary)
                                        .lineLimit(2)

                                    Text(answer.questionType.displayName)
                                        .font(IPTypography.labelSmall)
                                        .foregroundStyle(IPTheme.questionTypeColor(answer.questionType))
                                }

                                Spacer()
                            }
                        }

                        if answers.count > 5 {
                            Text("+\(answers.count - 5) more questions ready")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}
