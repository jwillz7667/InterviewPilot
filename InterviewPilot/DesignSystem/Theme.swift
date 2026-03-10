import SwiftUI

enum IPTheme {
    // MARK: - Colors

    static let brand = Color(red: 0.388, green: 0.400, blue: 0.945)         // Indigo 500
    static let brandLight = Color(red: 0.506, green: 0.549, blue: 0.973)    // Indigo 400
    static let brandDark = Color(red: 0.263, green: 0.220, blue: 0.792)     // Indigo 700

    static let interviewerBg = Color(red: 0.118, green: 0.161, blue: 0.231) // Slate 800
    static let responseBg = Color(red: 0.059, green: 0.090, blue: 0.165)    // Slate 900

    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let live = Color.red

    static let backgroundTop = Color(red: 0.059, green: 0.090, blue: 0.165)    // #0F172A
    static let backgroundBottom = Color(red: 0.118, green: 0.106, blue: 0.294) // #1E1B4B

    // Question type badge colors
    static func questionTypeColor(_ type: QuestionType) -> Color {
        switch type {
        case .behavioral:   return .blue
        case .technical:    return .purple
        case .systemDesign: return .orange
        case .coding:       return .green
        case .situational:  return .cyan
        case .background:   return .gray
        case .curveball:    return .pink
        case .followUp:     return .yellow
        case .unknown:      return .gray
        }
    }

    // MARK: - Spacing

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24

    // MARK: - Corner Radii

    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 24
    static let radiusXL: CGFloat = 32
}
