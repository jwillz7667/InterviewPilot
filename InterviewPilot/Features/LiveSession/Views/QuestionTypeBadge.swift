import SwiftUI

struct QuestionTypeBadge: View {
    let classification: QuestionClassification

    var body: some View {
        Text(classification.type.displayName.uppercased())
            .font(IATypography.labelSmall)
            .tracking(0.8)
            .foregroundStyle(IATheme.questionTypeColor(classification.type))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(IATheme.questionTypeColor(classification.type).opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(IATheme.questionTypeColor(classification.type).opacity(0.14), lineWidth: 1)
            }
    }
}
