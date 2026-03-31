import SwiftUI

enum IATheme {
    private static func color(hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    // MARK: - Material 3 Blue Palette

    static let primary = color(hex: 0x0059BB)
    static let primaryContainer = color(hex: 0x0070EA)
    static let onPrimary = Color.white
    static let onPrimaryContainer = Color.white

    static let secondary = color(hex: 0x535F71)
    static let secondaryContainer = color(hex: 0xD7E3F9)

    static let tertiary = color(hex: 0x006951)
    static let tertiaryContainer = color(hex: 0x008468)

    // MARK: - Surfaces

    static let surface = color(hex: 0xFAF9FF)
    static let surfaceContainer = color(hex: 0xE9EDFF)
    static let surfaceContainerLow = color(hex: 0xF1F3FF)

    static let onSurface = color(hex: 0x151B2A)
    static let onSurfaceVariant = color(hex: 0x414753)

    static let outline = color(hex: 0x717785)
    static let outlineVariant = color(hex: 0xC1C6D5)

    static let inverseSurface = color(hex: 0x2A303F)

    // MARK: - Semantic

    static let error = color(hex: 0xBA1A1A)
    static let errorContainer = color(hex: 0xFFDAD6)
    static let success = color(hex: 0x006D3B)
    static let successContainer = color(hex: 0xD0F5E0)
    static let warning = color(hex: 0xE39A1F)
    static let live = color(hex: 0xFF3B30)

    // MARK: - Backward-Compatible Aliases

    static let accent = primary
    static let accentForeground = Color.white
    static let accentSecondary = primaryContainer
    static let accentSelected = primary

    static let textPrimary = onSurface
    static let textSecondary = onSurfaceVariant
    static let textTertiary = outline
    static let pageTextPrimary = onSurface
    static let pageTextSecondary = onSurfaceVariant
    static let pageTextTertiary = outline
    static let divider = outlineVariant

    static let surfacePrimary = Color.white
    static let surfaceSecondary = surface
    static let surfaceTertiary = surfaceContainerLow
    static let groupedBackground = surfaceContainer

    static let interviewerBg = color(hex: 0xF1F3FF)
    static let responseBg = primaryContainer

    // MARK: - Button Colors

    static let buttonBlue = color(hex: 0x1978E5)
    static let buttonBlueShadow = color(hex: 0x1978E5).opacity(0.20)

    // MARK: - Dynamic Helpers (simplified for light-mode-first design)

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : surface
    }

    static func selectionFill(for colorScheme: ColorScheme, selected: Bool) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(primary.opacity(0.12))
        }
        return AnyShapeStyle(Color.white)
    }

    static func buttonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [buttonBlue, primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func secondaryButtonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [Color.white, Color.white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func tabAccessoryFill(for colorScheme: ColorScheme) -> AnyShapeStyle {
        AnyShapeStyle(Color.white)
    }

    static func primaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        .white
    }

    static func secondaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        onSurface
    }

    static func controlFill(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        isActive ? primary.opacity(0.12) : Color.black.opacity(0.03)
    }

    static func controlForeground(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        isActive ? primary : onSurfaceVariant
    }

    static func borderColor(for colorScheme: ColorScheme) -> Color {
        outlineVariant
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        primary.opacity(0.08)
    }

    static func inputFill(for colorScheme: ColorScheme) -> Color {
        Color.white
    }

    static func insetSurfacePrimaryText(for colorScheme: ColorScheme) -> Color {
        onSurface
    }

    static func insetSurfaceSecondaryText(for colorScheme: ColorScheme) -> Color {
        onSurfaceVariant
    }

    static func insetSurfaceTertiaryText(for colorScheme: ColorScheme) -> Color {
        outline
    }

    static func insetSurfaceBorder(for colorScheme: ColorScheme, selected: Bool) -> Color {
        selected ? primary : outlineVariant
    }

    static func insetSurfaceShadow(for colorScheme: ColorScheme, selected: Bool) -> Color {
        selected ? primary.opacity(0.12) : Color.black.opacity(0.04)
    }

    // MARK: - Question Type Colors (blue-based)

    static func questionTypeColor(_ type: QuestionType) -> Color {
        switch type {
        case .behavioral:
            return color(hex: 0x0059BB)
        case .technical:
            return color(hex: 0x006D3B)
        case .systemDesign:
            return color(hex: 0xE17055)
        case .coding:
            return color(hex: 0x0070EA)
        case .situational:
            return color(hex: 0x535F71)
        case .background:
            return color(hex: 0x717785)
        case .curveball:
            return color(hex: 0xBA1A1A)
        case .followUp:
            return color(hex: 0x006951)
        case .unknown:
            return color(hex: 0x717785)
        }
    }

    // MARK: - Spacing

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    // MARK: - Additional Surfaces

    static let surfaceWhite = Color.white

    // MARK: - Radii

    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 24
    static let radiusXL: CGFloat = 24
    static let radiusFull: CGFloat = 9999
}
