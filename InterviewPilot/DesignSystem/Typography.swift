import SwiftUI

enum IPTypography {
    // Display — Timer, big numbers
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)

    // Headings
    static let headlineLarge = Font.system(.title, design: .default, weight: .bold)
    static let headlineMedium = Font.system(.title2, design: .default, weight: .semibold)
    static let headlineSmall = Font.system(.title3, design: .default, weight: .semibold)

    // Body — Transcript and response text
    static let bodyLarge = Font.system(.body, design: .default, weight: .regular)
    static let bodyMedium = Font.system(.callout, design: .default, weight: .regular)

    // Response text — slightly larger for readability at a glance
    static let responseText = Font.system(size: 18, weight: .medium, design: .default)

    // Labels
    static let labelMedium = Font.system(.footnote, design: .default, weight: .medium)
    static let labelSmall = Font.system(.caption, design: .default, weight: .medium)

    // Timer
    static let timer = Font.system(size: 14, weight: .medium, design: .monospaced)
}
