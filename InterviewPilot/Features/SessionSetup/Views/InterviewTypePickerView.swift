import SwiftUI

struct InterviewTypePickerView: View {
    @Binding var selectedType: InterviewType

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(InterviewType.allCases, id: \.self) { type in
                Button(action: {
                    withAnimation(IPAnimations.snappy) {
                        selectedType = type
                    }
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: iconForType(type))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selectedType == type ? IPTheme.accentForeground : IPTheme.textSecondary)

                        Text(type.displayName)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                    .padding(14)
                    .background(
                        (selectedType == type ? IPTheme.accent.opacity(0.10) : Color.white.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconForType(_ type: InterviewType) -> String {
        switch type {
        case .behavioral:   return "person.2.fill"
        case .technical:    return "terminal.fill"
        case .systemDesign: return "server.rack"
        case .caseStudy:    return "doc.text.magnifyingglass"
        case .hrScreen:     return "person.text.rectangle.fill"
        case .general:      return "square.grid.2x2.fill"
        }
    }
}
