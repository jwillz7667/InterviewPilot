import SwiftUI

struct InterviewTypePickerView: View {
    @Binding var selectedType: InterviewType

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: IPTheme.spacing8) {
            ForEach(InterviewType.allCases, id: \.self) { type in
                Button(action: {
                    withAnimation(IPAnimations.snappy) {
                        selectedType = type
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: iconForType(type))
                            .font(.system(size: 20))

                        Text(type.displayName)
                            .font(IPTypography.labelMedium)
                    }
                    .foregroundStyle(selectedType == type ? .white : .white.opacity(0.5))
                    .padding(.vertical, IPTheme.spacing12)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedType == type
                            ? IPTheme.brand.opacity(0.8)
                            : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall)
                    )
                }
                .sensoryFeedback(.selection, trigger: selectedType)
            }
        }
    }

    private func iconForType(_ type: InterviewType) -> String {
        switch type {
        case .behavioral:   return "person.2.fill"
        case .technical:    return "wrench.and.screwdriver.fill"
        case .systemDesign: return "server.rack"
        case .caseStudy:    return "doc.text.magnifyingglass"
        case .hrScreen:     return "person.text.rectangle.fill"
        case .general:      return "rectangle.3.group.fill"
        }
    }
}
