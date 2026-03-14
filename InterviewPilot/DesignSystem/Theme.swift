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

    private static func subtleBlueGradient(
        for colorScheme: ColorScheme,
        lightTopHex: Int,
        lightBottomHex: Int,
        darkTopHex: Int,
        darkBottomHex: Int
    ) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [color(hex: darkTopHex), color(hex: darkBottomHex)]
                : [color(hex: lightTopHex), color(hex: lightBottomHex)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let accent = dynamicColor(lightHex: 0x004391, darkHex: 0xFFFFFF)
    static let accentForeground = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0xFFFFFF)
    static let accentSecondary = dynamicColor(lightHex: 0x003D84, darkHex: 0xD9E8FF)
    static let accentWarm = Color(red: 0.984, green: 0.706, blue: 0.349)

    static let brand = accent
    static let brandLight = dynamicColor(lightHex: 0x326FC4, darkHex: 0xEEF5FF)
    static let brandDark = dynamicColor(lightHex: 0x003D84, darkHex: 0xBFD8FF)

    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)
    static let live = Color(red: 0.922, green: 0.267, blue: 0.329)

    static let textPrimary = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0xFFFFFF)
    static let textSecondary = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0xEAF2FF)
    static let textTertiary = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0xD9E8FF)
    static let pageTextPrimary = dynamicColor(lightHex: 0x004391, darkHex: 0xFFFFFF)
    static let pageTextSecondary = dynamicColor(lightHex: 0x2F5692, darkHex: 0xD9E8FF)
    static let pageTextTertiary = dynamicColor(lightHex: 0x355179, darkHex: 0xC6DAFF)
    static let divider = dynamicColor(lightHex: 0xD4E1F4, darkHex: 0x4A70B6)

    static let surfacePrimary = dynamicColor(lightHex: 0x004391, darkHex: 0x012F79)
    static let surfaceSecondary = dynamicColor(lightHex: 0x003D84, darkHex: 0x003D84)
    static let surfaceTertiary = dynamicColor(lightHex: 0x00356F, darkHex: 0x022B6D)
    static let groupedBackground = dynamicColor(lightHex: 0xFFFFFF, darkHex: 0x0141A2)

    static let interviewerBg = surfaceSecondary
    static let responseBg = surfacePrimary

    static let backgroundTop = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? uiColor(hex: 0x0141A2)
                : uiColor(hex: 0xFFFFFF)
        }
    )

    static let backgroundBottom = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? uiColor(hex: 0x012F79)
                : uiColor(hex: 0xFFFFFF)
        }
    )

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundTop : color(hex: 0xFFFFFF)
    }

    static func meshColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [
                color(hex: 0x0141A2),
                color(hex: 0x0A52B7),
                Color.white.opacity(0.20),
                color(hex: 0x073A8C),
                color(hex: 0x0B4FB2),
                color(hex: 0x032E73),
                color(hex: 0x01245D),
                accentSecondary.opacity(0.62),
                Color.white.opacity(0.10)
            ]
        }

        return [
            Color(red: 0.984, green: 0.992, blue: 1.000),
            accent.opacity(0.34),
            Color(red: 0.886, green: 0.957, blue: 1.000),
            Color(red: 0.969, green: 0.980, blue: 1.000),
            accentWarm.opacity(0.26),
            Color(red: 0.888, green: 0.929, blue: 1.000),
            Color(red: 0.965, green: 0.980, blue: 0.996),
            accentSecondary.opacity(0.23),
            Color(red: 0.941, green: 0.965, blue: 1.000)
        ]
    }

    static func panelFill(for colorScheme: ColorScheme, emphasis: Double = 0) -> AnyShapeStyle {
        let _ = min(max(emphasis, 0), 0.12)
        return AnyShapeStyle(
            subtleBlueGradient(
                for: colorScheme,
                lightTopHex: 0x074695,
                lightBottomHex: 0x003D84,
                darkTopHex: 0x0A469F,
                darkBottomHex: 0x003D84
            )
        )
    }

    static func elevatedFill(for colorScheme: ColorScheme, tint: Color? = nil) -> AnyShapeStyle {
        if tint != nil {
            return AnyShapeStyle(
                subtleBlueGradient(
                    for: colorScheme,
                    lightTopHex: 0x084A99,
                    lightBottomHex: 0x004391,
                    darkTopHex: 0x0B49A8,
                    darkBottomHex: 0x0141A2
                )
            )
        }

        return AnyShapeStyle(
            subtleBlueGradient(
                for: colorScheme,
                lightTopHex: 0x084A99,
                lightBottomHex: 0x004391,
                darkTopHex: 0x094397,
                darkBottomHex: 0x012F79
            )
        )
    }

    static func selectionFill(for colorScheme: ColorScheme, selected: Bool) -> AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(color(hex: selected ? 0x00356F : 0x012F79))
        }

        return AnyShapeStyle(color(hex: selected ? 0x003D84 : 0x004391))
    }

    static func buttonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [Color.white, Color.white, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : subtleBlueGradient(
                for: colorScheme,
                lightTopHex: 0x084A99,
                lightBottomHex: 0x004391,
                darkTopHex: 0x0B49A8,
                darkBottomHex: 0x0141A2
            )
    }

    static func secondaryButtonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark
            ? LinearGradient(
                colors: [Color.white, Color.white, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : subtleBlueGradient(
                for: colorScheme,
                lightTopHex: 0x074695,
                lightBottomHex: 0x003D84,
                darkTopHex: 0x0A469F,
                darkBottomHex: 0x003D84
            )
    }

    static func tabAccessoryFill(for colorScheme: ColorScheme) -> AnyShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color.white)
            : AnyShapeStyle(
                subtleBlueGradient(
                    for: colorScheme,
                    lightTopHex: 0x084A99,
                    lightBottomHex: 0x004391,
                    darkTopHex: 0x0B49A8,
                    darkBottomHex: 0x0141A2
                )
            )
    }

    static func primaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x0141A2) : .white
    }

    static func secondaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x0141A2) : .white
    }

    static func controlFill(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? .white : color(hex: 0x004391)
        }

        return colorScheme == .dark ? .white.opacity(0.10) : color(hex: 0x004391).opacity(0.14)
    }

    static func controlForeground(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? color(hex: 0x0141A2) : .white
        }

        return colorScheme == .dark ? textSecondary : pageTextSecondary
    }

    static func borderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.16) : .white.opacity(0.18)
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.30) : color(hex: 0x004391).opacity(0.16)
    }

    static func inputFill(for colorScheme: ColorScheme) -> Color {
        .white
    }

    static func insetSurfacePrimaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x0141A2) : color(hex: 0x004391)
    }

    static func insetSurfaceSecondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x1F4C91) : color(hex: 0x2F5692)
    }

    static func insetSurfaceTertiaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x27518D) : color(hex: 0x355179)
    }

    static func insetSurfaceBorder(for colorScheme: ColorScheme, selected: Bool) -> Color {
        if selected {
            return colorScheme == .dark ? color(hex: 0x0141A2) : color(hex: 0x004391)
        }

        return colorScheme == .dark ? color(hex: 0xA7C0E8) : color(hex: 0xB8D0EE)
    }

    static func insetSurfaceShadow(for colorScheme: ColorScheme, selected: Bool) -> Color {
        if colorScheme == .dark {
            return color(hex: 0x00163D).opacity(selected ? 0.24 : 0.12)
        }

        return color(hex: 0x00356F).opacity(selected ? 0.12 : 0.06)
    }

    static func questionTypeColor(_ type: QuestionType) -> Color {
        switch type {
        case .behavioral:   return Color(red: 0.250, green: 0.525, blue: 0.960)
        case .technical:    return Color(red: 0.498, green: 0.325, blue: 0.929)
        case .systemDesign: return Color(red: 0.980, green: 0.608, blue: 0.180)
        case .coding:       return Color(red: 0.196, green: 0.733, blue: 0.475)
        case .situational:  return Color(red: 0.110, green: 0.745, blue: 0.835)
        case .background:   return Color(uiColor: .systemGray)
        case .curveball:    return Color(red: 0.945, green: 0.286, blue: 0.620)
        case .followUp:     return Color(red: 0.855, green: 0.717, blue: 0.233)
        case .unknown:      return Color(uiColor: .systemGray2)
        }
    }

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32

    static let radiusSmall: CGFloat = 12
    static let radiusMedium: CGFloat = 20
    static let radiusLarge: CGFloat = 28
    static let radiusXL: CGFloat = 34
}
