import SwiftUI

struct InterviewTypePickerView: View {
    @Binding var selectedType: InterviewType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(InterviewType.allCases, id: \.self) { type in
                Button(action: {
                    withAnimation(IPAnimations.snappy) {
                        selectedType = type
                    }
                }) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: iconForType(type))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selectedType == type ? IPTheme.accent : IPTheme.insetSurfaceSecondaryText(for: colorScheme))

                            Spacer()

                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(IPTheme.accent)
                            }
                        }

                        Text(type.displayName)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                    .padding(16)
                    .ipInsetSurface(selected: selectedType == type, cornerRadius: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconForType(_ type: InterviewType) -> String {
        switch type {
        case .behavioral:
            return "person.2.fill"
        case .technical:
            return "terminal.fill"
        case .systemDesign:
            return "server.rack"
        case .caseStudy:
            return "doc.text.magnifyingglass"
        case .hrScreen:
            return "person.text.rectangle.fill"
        case .general:
            return "square.grid.2x2.fill"
        }
    }
}
