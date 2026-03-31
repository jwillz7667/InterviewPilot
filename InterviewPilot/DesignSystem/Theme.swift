import SwiftUI

enum IATheme {
    private static func uiColor(hex: Int) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func color(hex: Int) -> Color {
        Color(uiColor: uiColor(hex: hex))
    }

    private static func dynamicColor(lightHex: Int, darkHex: Int) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? uiColor(hex: darkHex)
                    : uiColor(hex: lightHex)
            }
        )
    }

    // MARK: - Primary Violet Palette

    static let accent = dynamicColor(lightHex: 0x6C5CE7, darkHex: 0x6C5CE7)
    static let accentForeground = Color.white
    static let accentSecondary = dynamicColor(lightHex: 0xA29BFE, darkHex: 0xC4B5FD)
    static let accentWarm = dynamicColor(lightHex: 0xE17055, darkHex: 0xF0896B)
    static let teal = dynamicColor(lightHex: 0x00CEC9, darkHex: 0x55EFC4)
    static let accentSelected = dynamicColor(lightHex: 0x4834D4, darkHex: 0x4834D4)

    static let brand = accent
    static let brandLight = dynamicColor(lightHex: 0xEDE7F6, darkHex: 0x2D1B4E)
    static let brandDark = dynamicColor(lightHex: 0x4A1D96, darkHex: 0xD1C4E9)

    // MARK: - Semantic

    static let success = dynamicColor(lightHex: 0x00CEC9, darkHex: 0x55EFC4)
    static let warning = dynamicColor(lightHex: 0xE39A1F, darkHex: 0xF3BF5C)
    static let error = dynamicColor(lightHex: 0xD14343, darkHex: 0xFF7A7A)
    static let live = dynamicColor(lightHex: 0xFF3B30, darkHex: 0xFF6B63)

    // MARK: - Text

    static let textPrimary = dynamicColor(lightHex: 0x000000, darkHex: 0xF7FAFF)
    static let textSecondary = dynamicColor(lightHex: 0x4E596C, darkHex: 0xB7C4DD)
    static let textTertiary = dynamicColor(lightHex: 0x8A94A6, darkHex: 0x8390AA)
    static let pageTextPrimary = textPrimary
    static let pageTextSecondary = textSecondary
    static let pageTextTertiary = textTertiary
    static let divider = dynamicColor(lightHex: 0xD6DDEB, darkHex: 0x2A3346)

    // MARK: - Surfaces

    static let surfacePrimary = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0x2C2C2E)
    static let surfaceSecondary = dynamicColor(lightHex: 0xF9FBFF, darkHex: 0x3A3A3C)
    static let surfaceTertiary = dynamicColor(lightHex: 0xE9F1FC, darkHex: 0x3A3A3C)
    static let groupedBackground = dynamicColor(lightHex: 0xDDE5EF, darkHex: 0x0B1120)

    static let interviewerBg = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0x1A2436)
    static let responseBg = dynamicColor(lightHex: 0xEDE7F6, darkHex: 0x2D1B4E)

    static let backgroundTop = dynamicColor(lightHex: 0xF4F7FD, darkHex: 0x1C1C1E)
    static let backgroundBottom = dynamicColor(lightHex: 0xDDE5EF, darkHex: 0x1C1C1E)

    // MARK: - Dynamic Helpers

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x1C1C1E) : color(hex: 0xEEF2FA)
    }

    static func selectionFill(for colorScheme: ColorScheme, selected: Bool) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(colorScheme == .dark ? accent.opacity(0.28) : accent.opacity(0.12))
        }

        return AnyShapeStyle(colorScheme == .dark ? surfaceSecondary : Color.white.opacity(0.76))
    }

    static func buttonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [color(hex: 0x3A3A3C), color(hex: 0x2C2C2E)]
                : [color(hex: 0x7C6CF0), color(hex: 0x6C5CE7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func secondaryButtonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [color(hex: 0x3A3A3C), color(hex: 0x2C2C2E)]
                : [Color.white, color(hex: 0xF7FAFF)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func tabAccessoryFill(for colorScheme: ColorScheme) -> AnyShapeStyle {
        AnyShapeStyle(
            colorScheme == .dark
                ? LinearGradient(
                    colors: [color(hex: 0x1A2436), color(hex: 0x131B2B)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.white.opacity(0.97), color(hex: 0xF7FAFF).opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        )
    }

    static func primaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        .white
    }

    static func secondaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : textPrimary
    }

    static func controlFill(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? accent.opacity(0.28) : accent.opacity(0.14)
        }

        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.03)
    }

    static func controlForeground(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? Color.white : accent
        }

        return colorScheme == .dark ? textSecondary : pageTextSecondary
    }

    static func borderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : accent.opacity(0.10)
    }

    static func inputFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x2C2C2E) : Color.white
    }

    static func insetSurfacePrimaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : textPrimary
    }

    static func insetSurfaceSecondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textSecondary : pageTextSecondary
    }

    static func insetSurfaceTertiaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textTertiary : pageTextTertiary
    }

    static func insetSurfaceBorder(for colorScheme: ColorScheme, selected: Bool) -> Color {
        if selected {
            return Color.white.opacity(0.35)
        }

        return borderColor(for: colorScheme)
    }

    static func insetSurfaceShadow(for colorScheme: ColorScheme, selected: Bool) -> Color {
        if colorScheme == .dark {
            return Color.black.opacity(selected ? 0.30 : 0.18)
        }

        return accent.opacity(selected ? 0.14 : 0.06)
    }

    // MARK: - Question Type Colors (Violet / Teal / Coral spread)

    static func questionTypeColor(_ type: QuestionType) -> Color {
        switch type {
        case .behavioral:
            return color(hex: 0x6C5CE7)
        case .technical:
            return dynamicColor(lightHex: 0x00CEC9, darkHex: 0x55EFC4)
        case .systemDesign:
            return dynamicColor(lightHex: 0xE17055, darkHex: 0xF0896B)
        case .coding:
            return color(hex: 0x4834D4)
        case .situational:
            return color(hex: 0xA29BFE)
        case .background:
            return dynamicColor(lightHex: 0x7C8596, darkHex: 0x95A0B7)
        case .curveball:
            return color(hex: 0xD63031)
        case .followUp:
            return color(hex: 0x7C6CF0)
        case .unknown:
            return dynamicColor(lightHex: 0x8A94A6, darkHex: 0x7B869E)
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

    // MARK: - Radii

    static let radiusSmall: CGFloat = 14
    static let radiusMedium: CGFloat = 20
    static let radiusLarge: CGFloat = 28
    static let radiusXL: CGFloat = 34
}
