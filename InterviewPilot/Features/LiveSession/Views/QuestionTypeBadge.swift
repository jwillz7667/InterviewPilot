import SwiftUI

struct QuestionTypeBadge: View {
    let classification: QuestionClassification

    var body: some View {
        Text(classification.type.displayName.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                IPTheme.questionTypeColor(classification.type).opacity(0.8),
                in: Capsule()
            )
    }
}
