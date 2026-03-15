import SwiftUI

enum IPTypography {
    // Apple-style semantic text hierarchy so the interface scales correctly with Dynamic Type.
    static let displayLarge = Font.system(.largeTitle, design: .default, weight: .bold)
    static let displayMedium = Font.system(.title, design: .default, weight: .bold)

    static let headlineLarge = Font.system(.title2, design: .default, weight: .bold)
    static let headlineMedium = Font.system(.title3, design: .default, weight: .semibold)
    static let headlineSmall = Font.system(.headline, design: .default, weight: .semibold)

    static let bodyLarge = Font.system(.body, design: .default, weight: .regular)
    static let bodyMedium = Font.system(.callout, design: .default, weight: .regular)
    static let bodySmall = Font.system(.subheadline, design: .default, weight: .regular)

    static let responseText = Font.system(.body, design: .default, weight: .regular)

    static let labelLarge = Font.system(.callout, design: .default, weight: .semibold)
    static let labelMedium = Font.system(.footnote, design: .default, weight: .semibold)
    static let labelSmall = Font.system(.caption, design: .default, weight: .semibold)

    static let timer = Font.system(.footnote, design: .monospaced, weight: .medium)
}
