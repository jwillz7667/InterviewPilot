import SwiftUI

enum IPTheme {
    static let accent = Color(red: 0.157, green: 0.482, blue: 0.973)
    static let accentSecondary = Color(red: 0.114, green: 0.357, blue: 0.804)
    static let accentWarm = Color(red: 0.984, green: 0.706, blue: 0.349)

    static let brand = accent
    static let brandLight = accentSecondary
    static let brandDark = Color(red: 0.114, green: 0.271, blue: 0.690)

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
                ? UIColor(red: 0.041, green: 0.047, blue: 0.067, alpha: 1)
                : UIColor(red: 0.959, green: 0.969, blue: 0.984, alpha: 1)
        }
    )

    static let backgroundBottom = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.067, green: 0.078, blue: 0.110, alpha: 1)
                : UIColor(red: 0.923, green: 0.941, blue: 0.969, alpha: 1)
        }
    )

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundTop : groupedBackground
    }

    static func meshColors(for colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.070, green: 0.136, blue: 0.255),
                accent.opacity(0.95),
                Color(red: 0.104, green: 0.333, blue: 0.420),
                Color(red: 0.067, green: 0.137, blue: 0.215),
                accentWarm.opacity(0.68),
                Color(red: 0.102, green: 0.239, blue: 0.392),
                Color(red: 0.031, green: 0.067, blue: 0.129),
                accentSecondary.opacity(0.85),
                Color(red: 0.043, green: 0.094, blue: 0.173)
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
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.112, green: 0.180, blue: 0.322).opacity(0.94 + boost),
                        Color(red: 0.075, green: 0.129, blue: 0.251).opacity(0.98),
                        Color(red: 0.047, green: 0.086, blue: 0.180).opacity(0.99)
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
                        fillTint.opacity(0.24),
                        accentSecondary.opacity(0.20),
                        Color(red: 0.050, green: 0.094, blue: 0.188).opacity(0.98)
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
                            accent.opacity(0.34),
                            accentSecondary.opacity(0.28),
                            Color(red: 0.053, green: 0.098, blue: 0.188).opacity(0.98)
                        ]
                        : [
                            Color(red: 0.102, green: 0.152, blue: 0.271).opacity(0.92),
                            Color(red: 0.062, green: 0.102, blue: 0.196).opacity(0.96),
                            Color(red: 0.048, green: 0.078, blue: 0.149).opacity(0.98)
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
                    accent.opacity(0.98),
                    accentSecondary.opacity(0.96),
                    brandDark.opacity(0.98)
                ]
                : [
                    Color(red: 0.262, green: 0.600, blue: 1.000),
                    accent.opacity(0.98),
                    accentSecondary.opacity(0.94)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func secondaryButtonGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    accent.opacity(0.42),
                    accentSecondary.opacity(0.34),
                    brandDark.opacity(0.30)
                ]
                : [
                    Color(red: 0.650, green: 0.826, blue: 1.000).opacity(0.92),
                    accent.opacity(0.34),
                    accentSecondary.opacity(0.24)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
