import SwiftUI

struct QuestionTypeBadge: View {
    let classification: QuestionClassification

    var body: some View {
        Text(classification.type.displayName.uppercased())
            .font(IPTypography.labelSmall)
            .tracking(0.8)
            .foregroundStyle(IPTheme.questionTypeColor(classification.type))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(IPTheme.questionTypeColor(classification.type).opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(IPTheme.questionTypeColor(classification.type).opacity(0.14), lineWidth: 1)
            }
    }
}
