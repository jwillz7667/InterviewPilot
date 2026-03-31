import SwiftUI

struct IAInsetSurfaceStyle: ViewModifier {
    let selected: Bool
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(selected ? IATheme.accentSelected : IATheme.inputFill(for: colorScheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                IATheme.insetSurfaceBorder(for: colorScheme, selected: selected),
                                lineWidth: selected ? 1.5 : 1
                            )
                    }
            }
            .shadow(
                color: IATheme.insetSurfaceShadow(for: colorScheme, selected: selected),
                radius: selected ? 20 : 12,
                y: selected ? 10 : 6
            )
    }
}

extension View {
    func iaInsetSurface(selected: Bool = false, cornerRadius: CGFloat = 18) -> some View {
        modifier(IAInsetSurfaceStyle(selected: selected, cornerRadius: cornerRadius))
    }
}
