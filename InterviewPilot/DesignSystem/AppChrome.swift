import SwiftUI

enum IASurfaceTone {
    case primary
    case secondary
    case accent(Color)
}

enum IABrandLogoVariant {
    case surface
    case filled
}

struct IAAppBackground: View {
    var body: some View {
        Color.clear
            .background(.regularMaterial)
            .ignoresSafeArea()
    }
}

struct IAPanel<Content: View>: View {
    let tone: IASurfaceTone
    let padding: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(
        tone: IASurfaceTone = .primary,
        padding: CGFloat = IATheme.spacing20,
        cornerRadius: CGFloat = IATheme.radiusLarge,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background {
                panelBackground
            }
            .scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.96)
                    .scaleEffect(phase.isIdentity ? 1 : 0.988)
                    .offset(y: phase.isIdentity ? 0 : phase.value * 12)
            }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if case .accent(let tint) = tone {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.12))
                }
        } else if case .secondary = tone {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

struct IABrandLogo: View {
    var size: CGFloat = 60
    var cornerRadius: CGFloat? = nil
    var showShadow: Bool = true
    var variant: IABrandLogoVariant = .surface
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundFill)

            Text("A")
                .font(.system(size: size * 0.48, weight: .black, design: .rounded))
                .foregroundStyle(glyphFill)
        }
        .frame(width: size, height: size)
        .shadow(
            color: showShadow ? IATheme.shadowColor(for: colorScheme).opacity(variant == .filled ? 0.34 : 0.18) : .clear,
            radius: showShadow ? size * 0.14 : 0,
            y: showShadow ? size * 0.08 : 0
        )
        .accessibilityLabel("Interview Ace AI logo")
    }

    private var backgroundFill: LinearGradient {
        switch variant {
        case .surface:
            return LinearGradient(
                colors: [Color.white, Color.white.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .filled:
            return LinearGradient(
                colors: [IATheme.accentSecondary, IATheme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var glyphFill: Color {
        switch variant {
        case .surface:
            return IATheme.accent
        case .filled:
            return .white
        }
    }
}

struct IAStarburst: View {
    var size: CGFloat = 34
    var tint: Color = IATheme.accent

    var body: some View {
        IAStarburstShape()
            .fill(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                IAStarburstShape()
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.18), radius: 12, y: 6)
    }
}

struct IASectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let symbol: String?
    var tint: Color = IATheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(IATypography.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(IATheme.textSecondary)
            }

            HStack(alignment: .top, spacing: 12) {
                if let symbol {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(IATheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct IAStatusPill: View {
    let title: String
    let symbol: String
    var tint: Color = IATheme.accent

    var body: some View {
        Label(title, systemImage: symbol)
            .font(IATypography.labelSmall)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            }
    }
}

struct IAEmptyState: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        IAPanel(tone: .secondary, padding: IATheme.spacing24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(IATheme.accent.opacity(0.10))
                        .frame(width: 74, height: 74)
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

                Text(title)
                    .font(IATypography.headlineMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct IAInputShell<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(icon: String, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(IATheme.accent.opacity(0.10))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(IATheme.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
    }
}

struct IAUtilityCircleButton: View {
    let symbol: String
    var filled: Bool = false
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? Color.white : IATheme.textPrimary)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(buttonFill)
                )
                .overlay {
                    Circle()
                        .stroke(
                            filled ? Color.clear : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                }
                .shadow(color: IATheme.shadowColor(for: colorScheme).opacity(0.28), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var buttonFill: AnyShapeStyle {
        if filled {
            return AnyShapeStyle(IATheme.buttonGradient(for: colorScheme))
        }

        return AnyShapeStyle(.regularMaterial)
    }
}

struct IABottomDock<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: IATheme.radiusXL, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusXL, style: .continuous)
                        .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
                }
        }
        .shadow(color: IATheme.shadowColor(for: colorScheme).opacity(0.36), radius: 12, y: 6)
    }
}

struct IAScoreRing: View {
    let progress: Double
    let title: String
    let value: String
    var size: CGFloat = 132
    var tint: Color = IATheme.accent

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 12)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(title)
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .multilineTextAlignment(.center)

                Text(value)
                    .font(IATypography.displayMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 18)
        }
        .frame(width: size, height: size)
    }
}

struct IAConversationBubble: View {
    enum Role {
        case interviewer
        case user
        case assistant
    }

    let role: Role
    let title: String
    let text: String
    var symbol: String
    var trailingSymbol: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if role == .user {
                Spacer(minLength: 24)
            }

            bubble

            if role != .user {
                Spacer(minLength: 24)
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                avatar

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text(roleLabel)
                        .font(IATypography.labelSmall)
                        .foregroundStyle(IATheme.textSecondary)
                }

                Spacer()

                if let trailingSymbol {
                    Image(systemName: trailingSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Text(text)
                .font(IATypography.bodyLarge)
                .foregroundStyle(IATheme.textPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: role == .assistant ? 360 : 320, alignment: .leading)
        .padding(16)
        .background(bubbleFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(bubbleBorder, lineWidth: 1)
        }
        .shadow(
            color: colorScheme == .dark ? Color.black.opacity(0.18) : IATheme.accent.opacity(0.08),
            radius: 14,
            y: 8
        )
    }

    private var avatar: some View {
        Group {
            switch role {
            case .assistant:
                IABrandLogo(size: 28, showShadow: false, variant: .surface)
            case .interviewer:
                Circle()
                    .fill(IATheme.accent.opacity(0.14))
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(IATheme.accent)
                    }
            case .user:
                Circle()
                    .fill(IATheme.accent)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
            }
        }
        .frame(width: 28, height: 28)
    }

    private var bubbleFill: Color {
        switch role {
        case .assistant:
            return IATheme.surfaceSecondary
        case .interviewer:
            return IATheme.interviewerBg
        case .user:
            return IATheme.responseBg
        }
    }

    private var bubbleBorder: Color {
        switch role {
        case .assistant, .interviewer:
            return IATheme.borderColor(for: colorScheme)
        case .user:
            return IATheme.accent.opacity(0.18)
        }
    }

    private var roleLabel: String {
        switch role {
        case .assistant:
            return "Suggested response"
        case .interviewer:
            return "Transcript"
        case .user:
            return "Your voice"
        }
    }
}

struct IATimelineRow: View {
    let time: String
    let title: String
    let detail: String
    var tint: Color = IATheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 1)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(time)
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textSecondary)

                Text(title)
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text(detail)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

struct IAPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var tint: Color = IATheme.accent

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IATypography.bodyLarge)
            .foregroundStyle(IATheme.primaryButtonLabelColor(for: colorScheme).opacity(isEnabled ? 1 : 0.82))
            .frame(maxWidth: .infinity)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .padding(.vertical, 15)
            .background(
                isEnabled
                    ? IATheme.buttonGradient(for: colorScheme)
                    : LinearGradient(
                        colors: [Color(uiColor: .systemGray4), Color(uiColor: .systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: isEnabled ? IATheme.accent.opacity(0.16) : .clear, radius: 10, y: 6)
            .animation(IAAnimations.snappy, value: configuration.isPressed)
    }
}

struct IASecondaryButtonStyle: ButtonStyle {
    var tint: Color = IATheme.accent

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IATypography.bodyMedium)
            .foregroundStyle(IATheme.secondaryButtonLabelColor(for: colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                IATheme.secondaryButtonGradient(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.16) : Color.black.opacity(0.03), radius: 6, y: 3)
            .animation(IAAnimations.snappy, value: configuration.isPressed)
    }
}

extension View {
    func iaScrollablePage() -> some View {
        scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
    }
}

struct IATabAccessory: View {
    let selectedTab: Int
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if placement == .inline {
                HStack(spacing: 8) {
                    IABrandLogo(size: 22, showShadow: false, variant: .filled)
                    Text(compactTitle)
                        .font(IATypography.labelSmall)
                        .foregroundStyle(accessoryPrimaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    IABrandLogo(size: 38, showShadow: false, variant: .filled)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(IATypography.labelLarge)
                            .foregroundStyle(accessoryPrimaryText)

                        Text(subtitle)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(accessorySecondaryText)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background {
            Capsule()
                .fill(IATheme.tabAccessoryFill(for: colorScheme))
        }
        .overlay {
            Capsule()
                .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: IATheme.shadowColor(for: colorScheme), radius: 14, y: 8)
        .animation(IAAnimations.snappy, value: selectedTab)
    }

    private var accessoryPrimaryText: Color {
        IATheme.pageTextPrimary
    }

    private var accessorySecondaryText: Color {
        IATheme.pageTextSecondary
    }

    private var compactTitle: String {
        switch selectedTab {
        case 0:
            return "Prepare"
        case 1:
            return "History"
        default:
            return "Settings"
        }
    }

    private var title: String {
        switch selectedTab {
        case 0:
            return "Job-aligned interview setup"
        case 1:
            return "Past session reports"
        default:
            return "Preferences and billing"
        }
    }

    private var subtitle: String {
        switch selectedTab {
        case 0:
            return "Resume, listing, and launch controls"
        case 1:
            return "Latency, quality, and exchange review"
        default:
            return "Theme, defaults, and subscription status"
        }
    }
}

private struct IAStarburstShape: Shape {
    var points: Int = 8
    var innerRatio: CGFloat = 0.58

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        let angleStep = .pi / CGFloat(points)

        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) * angleStep - (.pi / 2)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
