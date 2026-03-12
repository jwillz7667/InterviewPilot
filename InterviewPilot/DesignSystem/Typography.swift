import SwiftUI

enum IPTypography {
    static let displayLarge = Font.system(size: 44, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 34, weight: .bold, design: .rounded)

    static let headlineLarge = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let headlineMedium = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headlineSmall = Font.system(.title3, design: .rounded, weight: .semibold)

    static let bodyLarge = Font.system(.body, design: .rounded, weight: .medium)
    static let bodyMedium = Font.system(.callout, design: .rounded, weight: .regular)
    static let bodySmall = Font.system(.footnote, design: .rounded, weight: .regular)

    static let responseText = Font.system(size: 19, weight: .medium, design: .rounded)

    static let labelLarge = Font.system(.subheadline, design: .rounded, weight: .semibold)
    static let labelMedium = Font.system(.footnote, design: .rounded, weight: .semibold)
    static let labelSmall = Font.system(.caption, design: .rounded, weight: .semibold)

    static let timer = Font.system(size: 14, weight: .semibold, design: .monospaced)
}
