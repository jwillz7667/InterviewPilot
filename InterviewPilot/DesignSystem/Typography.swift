import SwiftUI

enum IATypography {
    // MARK: - Font Family Names (variable fonts)

    private static let publicSans = "Public Sans"
    private static let sourceSans3 = "Source Sans 3"
    private static let plusJakarta = "Plus Jakarta Sans"

    // MARK: - Display — Public Sans ExtraBold/Bold

    static let displayXL = Font.custom(publicSans, size: 48).weight(.heavy)
    static let displayLarge = Font.custom(publicSans, size: 36).weight(.heavy)
    static let displayMedium = Font.custom(publicSans, size: 28).weight(.bold)

    // MARK: - Headlines — Public Sans Bold/SemiBold

    static let headlineLarge = Font.custom(publicSans, size: 28).weight(.bold)
    static let headlineMedium = Font.custom(publicSans, size: 22).weight(.bold)
    static let headlineSmall = Font.custom(publicSans, size: 17).weight(.semibold)

    // MARK: - Body — Source Sans 3 Regular

    static let bodyLarge = Font.custom(sourceSans3, size: 18).weight(.regular)
    static let bodyMedium = Font.custom(sourceSans3, size: 15).weight(.regular)
    static let bodySmall = Font.custom(sourceSans3, size: 14).weight(.regular)

    // MARK: - Response Text — Source Sans 3

    static let responseText = Font.custom(sourceSans3, size: 17).weight(.regular)

    // MARK: - Labels — Plus Jakarta Sans SemiBold

    static let labelLarge = Font.custom(plusJakarta, size: 14).weight(.semibold)
    static let labelMedium = Font.custom(plusJakarta, size: 12).weight(.semibold)
    static let labelSmall = Font.custom(plusJakarta, size: 11).weight(.semibold)

    // MARK: - Utility

    static let timer = Font.system(.footnote, design: .monospaced, weight: .medium)

    // MARK: - System Fallback Helper

    static func fallback(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
