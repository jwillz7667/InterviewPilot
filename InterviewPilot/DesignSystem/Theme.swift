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

    static let accent = dynamicColor(lightHex: 0x0369E3, darkHex: 0xFFFFFF)
    static let accentForeground = dynamicColor(lightHex: 0x004391, darkHex: 0xFFFFFF)
    static let accentSecondary = dynamicColor(lightHex: 0x005BC4, darkHex: 0xD8E8FF)
    static let accentWarm = Color(red: 0.984, green: 0.706, blue: 0.349)

    static let brand = accent
    static let brandLight = dynamicColor(lightHex: 0x1D76E0, darkHex: 0xEEF5FF)
    static let brandDark = dynamicColor(lightHex: 0x003D84, darkHex: 0xBFD8FF)

    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)
    static let live = Color(red: 0.922, green: 0.267, blue: 0.329)

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let divider = Color(uiColor: .separator).opacity(0.22)

    static let surfacePrimary = Color(uiColor: .systemBackground)
    static let surfaceSecondary = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceTertiary = Color(uiColor: .tertiarySystemGroupedBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)

    static let interviewerBg = surfaceSecondary
    static let responseBg = surfacePrimary

    static let backgroundTop = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? uiColor(hex: 0x0141A2)
                : UIColor(red: 0.959, green: 0.969, blue: 0.984, alpha: 1)
        }
    )

    static let backgroundBottom = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? uiColor(hex: 0x012F79)
                : UIColor(red: 0.923, green: 0.941, blue: 0.969, alpha: 1)
        }
    )

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundTop : groupedBackground
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
        let boost = min(max(emphasis, 0), 0.12)

        if colorScheme == .dark {
            let leadingOpacity = min(1.0, 0.96 + boost)
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        color(hex: 0x0B4FB2).opacity(leadingOpacity),
                        color(hex: 0x083F9A).opacity(0.98),
                        color(hex: 0x022B6D).opacity(0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.946, green: 0.978, blue: 1.000).opacity(0.98),
                    Color(red: 0.885, green: 0.938, blue: 1.000).opacity(0.94 + boost),
                    Color(red: 0.820, green: 0.897, blue: 0.992).opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    static func elevatedFill(for colorScheme: ColorScheme, tint: Color? = nil) -> AnyShapeStyle {
        let fillTint = tint ?? accent

        if tint != nil {
            if colorScheme == .dark {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            color(hex: 0x0A52B7),
                            color(hex: 0x0847A7),
                            color(hex: 0x032E73)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }

            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        fillTint.opacity(colorScheme == .dark ? 0.34 : 0.22),
                        accentSecondary.opacity(colorScheme == .dark ? 0.24 : 0.18),
                        brandDark.opacity(colorScheme == .dark ? 0.16 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        color(hex: 0x063E9B),
                        color(hex: 0x03357F),
                        color(hex: 0x01245D)
                    ]
                    : [
                        Color(red: 0.940, green: 0.973, blue: 1.000),
                        fillTint.opacity(0.18),
                        Color(red: 0.806, green: 0.893, blue: 1.000).opacity(0.92)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    static func selectionFill(for colorScheme: ColorScheme, selected: Bool) -> AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: selected
                        ? [
                            color(hex: 0x0A52B7),
                            color(hex: 0x0847A7),
                            color(hex: 0x032E73)
                        ]
                        : [
                            color(hex: 0x063684).opacity(0.92),
                            color(hex: 0x022E73).opacity(0.96),
                            color(hex: 0x01245D).opacity(0.98)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: selected
                    ? [
                        Color(red: 0.914, green: 0.961, blue: 1.000),
                        accent.opacity(0.20),
                        Color(red: 0.806, green: 0.897, blue: 1.000).opacity(0.92)
                    ]
                    : [
                        Color(red: 0.950, green: 0.979, blue: 1.000),
                        Color(red: 0.894, green: 0.940, blue: 1.000),
                        Color(red: 0.846, green: 0.914, blue: 0.992).opacity(0.92)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    static func buttonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white,
                    color(hex: 0xF5F9FF),
                    color(hex: 0xDCE9FF)
                ]
                : [
                    color(hex: 0x0050AD),
                    color(hex: 0x004A9F),
                    color(hex: 0x003D84)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func secondaryButtonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    color(hex: 0x0A52B7),
                    color(hex: 0x0847A7),
                    color(hex: 0x032E73)
                ]
                : [
                    color(hex: 0xEEF4FF),
                    color(hex: 0xE3EDF9),
                    color(hex: 0xD4E3F7)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func primaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(hex: 0x0141A2) : .white
    }

    static func secondaryButtonLabelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : accentForeground
    }

    static func controlFill(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? .white : accentForeground
        }

        return colorScheme == .dark ? .white.opacity(0.10) : accentForeground.opacity(0.08)
    }

    static func controlForeground(for colorScheme: ColorScheme, isActive: Bool) -> Color {
        if isActive {
            return colorScheme == .dark ? color(hex: 0x0141A2) : .white
        }

        return textSecondary
    }

    static func borderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.14) : accentSecondary.opacity(0.18)
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.30) : accent.opacity(0.18)
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
