import SwiftUI

enum IPTheme {
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

    static let accent = dynamicColor(lightHex: 0x2D59F0, darkHex: 0x5F86FF)
    static let accentForeground = Color.white
    static let accentSecondary = dynamicColor(lightHex: 0x8AA5FF, darkHex: 0xAFC0FF)
    static let accentWarm = dynamicColor(lightHex: 0x6B85F8, darkHex: 0x88A2FF)

    static let brand = accent
    static let brandLight = dynamicColor(lightHex: 0xDCE7FF, darkHex: 0x25334D)
    static let brandDark = dynamicColor(lightHex: 0x1D3FC3, darkHex: 0xD9E3FF)

    static let success = dynamicColor(lightHex: 0x22A06B, darkHex: 0x42D392)
    static let warning = dynamicColor(lightHex: 0xE39A1F, darkHex: 0xF3BF5C)
    static let error = dynamicColor(lightHex: 0xD14343, darkHex: 0xFF7A7A)
    static let live = dynamicColor(lightHex: 0xFF3B30, darkHex: 0xFF6B63)

    static let textPrimary = dynamicColor(lightHex: 0x000000, darkHex: 0xF7FAFF)
    static let textSecondary = dynamicColor(lightHex: 0x4E596C, darkHex: 0xB7C4DD)
    static let textTertiary = dynamicColor(lightHex: 0x8A94A6, darkHex: 0x8390AA)
    static let pageTextPrimary = textPrimary
    static let pageTextSecondary = textSecondary
    static let pageTextTertiary = textTertiary
    static let divider = dynamicColor(lightHex: 0xD6DDEB, darkHex: 0x2A3346)

    static let surfacePrimary = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0x141B29)
    static let surfaceSecondary = dynamicColor(lightHex: 0xF9FBFF, darkHex: 0x1B2435)
    static let surfaceTertiary = dynamicColor(lightHex: 0xE9F1FC, darkHex: 0x232E44)
    static let groupedBackground = dynamicColor(lightHex: 0xDDE5EF, darkHex: 0x0B1120)

    static let interviewerBg = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0x1A2436)
    static let responseBg = dynamicColor(lightHex: 0xE9F1FC, darkHex: 0x21314E)

    static let backgroundTop = dynamicColor(lightHex: 0xF4F7FD, darkHex: 0x050814)
    static let backgroundBottom = dynamicColor(lightHex: 0xDDE5EF, darkHex: 0x15203B)

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x050814) : color(hex: 0xEEF2FA)
    }

    static func meshColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [
                color(hex: 0x08101F),
                color(hex: 0x121C34),
                accent.opacity(0.50),
                color(hex: 0x1B2A48),
                accentSecondary.opacity(0.24),
                Color.white.opacity(0.08)
            ]
        }

        return [
            color(hex: 0xF8FBFF),
            color(hex: 0xE9F1FC),
            accent.opacity(0.16),
            color(hex: 0xDDE5EF),
            Color.white.opacity(0.85),
            accentSecondary.opacity(0.14)
        ]
    }

    static func appBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                stops: [
                    .init(color: color(hex: 0x04070F), location: 0.00),
                    .init(color: color(hex: 0x09101C), location: 0.28),
                    .init(color: color(hex: 0x121C33), location: 0.64),
                    .init(color: color(hex: 0x1B2950), location: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            stops: [
                .init(color: color(hex: 0xF7FAFF), location: 0.00),
                .init(color: color(hex: 0xEEF3FC), location: 0.52),
                .init(color: color(hex: 0xDDE5EF), location: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func panelFill(for colorScheme: ColorScheme, emphasis: Double = 0) -> AnyShapeStyle {
        let clampedEmphasis = min(max(emphasis, 0), 0.20)
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        color(hex: 0x1A2436).opacity(0.96),
                        color(hex: 0x141C2B).opacity(0.98 + clampedEmphasis)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white,
                    color(hex: 0xF8FBFF).opacity(0.96 + clampedEmphasis)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    static func elevatedFill(for colorScheme: ColorScheme, tint: Color? = nil) -> AnyShapeStyle {
        if let tint {
            return AnyShapeStyle(
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [tint.opacity(0.34), color(hex: 0x1B2540)]
                        : [tint.opacity(0.20), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            colorScheme == .dark
                ? LinearGradient(
                    colors: [color(hex: 0x202A3E), color(hex: 0x171F2F)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.white, color(hex: 0xF6FAFF)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        )
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
                ? [color(hex: 0x5F86FF), color(hex: 0x2D59F0)]
                : [color(hex: 0x4770F5), color(hex: 0x2D59F0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func secondaryButtonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [color(hex: 0x1C2537), color(hex: 0x171F2F)]
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
        colorScheme == .dark ? color(hex: 0x141C2B) : Color.white
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
            return accent.opacity(colorScheme == .dark ? 0.82 : 0.46)
        }

        return borderColor(for: colorScheme)
    }

    static func insetSurfaceShadow(for colorScheme: ColorScheme, selected: Bool) -> Color {
        if colorScheme == .dark {
            return Color.black.opacity(selected ? 0.30 : 0.18)
        }

        return accent.opacity(selected ? 0.14 : 0.06)
    }

    static func questionTypeColor(_ type: QuestionType) -> Color {
        switch type {
        case .behavioral:
            return color(hex: 0x2D59F0)
        case .technical:
            return color(hex: 0x5A64D8)
        case .systemDesign:
            return color(hex: 0x7289F5)
        case .coding:
            return color(hex: 0x2451E7)
        case .situational:
            return color(hex: 0x3C79FF)
        case .background:
            return dynamicColor(lightHex: 0x7C8596, darkHex: 0x95A0B7)
        case .curveball:
            return color(hex: 0x1E2F86)
        case .followUp:
            return color(hex: 0x5772FF)
        case .unknown:
            return dynamicColor(lightHex: 0x8A94A6, darkHex: 0x7B869E)
        }
    }

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    static let radiusSmall: CGFloat = 14
    static let radiusMedium: CGFloat = 20
    static let radiusLarge: CGFloat = 28
    static let radiusXL: CGFloat = 34
}
