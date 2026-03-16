import SwiftUI

enum IPSurfaceTone {
    case primary
    case secondary
    case accent(Color)
}

enum IPBrandLogoVariant {
    case surface
    case filled
}

struct IPAppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                IPTheme.appBackgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                if colorScheme == .dark {
                    darkAmbientLayers(size: geometry.size)
                } else {
                    lightAmbientLayers(size: geometry.size)
                }

                VStack {
                    HStack {
                        Spacer()
                        IPStarburst(size: 46, tint: IPTheme.accent.opacity(colorScheme == .dark ? 0.62 : 0.28))
                            .padding(.top, 62)
                            .padding(.trailing, 28)
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func lightAmbientLayers(size: CGSize) -> some View {
        Circle()
            .fill(IPTheme.accent.opacity(0.12))
            .frame(width: size.width * 0.9)
            .blur(radius: 70)
            .offset(x: size.width * 0.22, y: -size.height * 0.20)

        Ellipse()
            .fill(Color.white.opacity(0.55))
            .frame(width: size.width * 0.7, height: size.width * 0.38)
            .blur(radius: 24)
            .offset(x: -size.width * 0.18, y: size.height * 0.18)

        Circle()
            .fill(IPTheme.brandLight.opacity(0.58))
            .frame(width: size.width * 0.45)
            .blur(radius: 48)
            .offset(x: -size.width * 0.28, y: size.height * 0.34)
    }

    @ViewBuilder
    private func darkAmbientLayers(size: CGSize) -> some View {
        RadialGradient(
            colors: [
                Color.white.opacity(0.24),
                Color.white.opacity(0.07),
                .clear
            ],
            center: .topLeading,
            startRadius: 8,
            endRadius: size.width * 0.88
        )
        .frame(width: size.width * 1.18, height: size.height * 0.84)
        .blur(radius: 12)
        .offset(x: -size.width * 0.22, y: -size.height * 0.26)

        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.03),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width * 0.90, height: size.width * 0.42)
            .blur(radius: 34)
            .rotationEffect(.degrees(-11))
            .offset(x: -size.width * 0.06, y: -size.height * 0.02)

        Circle()
            .fill(IPTheme.accent.opacity(0.26))
            .frame(width: size.width * 0.94)
            .blur(radius: 116)
            .offset(x: size.width * 0.28, y: -size.height * 0.24)

        Circle()
            .fill(IPTheme.accentSecondary.opacity(0.18))
            .frame(width: size.width * 0.54)
            .blur(radius: 82)
            .offset(x: -size.width * 0.24, y: size.height * 0.40)

        RoundedRectangle(cornerRadius: 42, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .frame(width: size.width * 0.76, height: size.height * 0.16)
            .overlay {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .blur(radius: 6)
            .offset(x: size.width * 0.08, y: -size.height * 0.05)
    }
}

struct IPPanel<Content: View>: View {
    let tone: IPSurfaceTone
    let padding: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        tone: IPSurfaceTone = .primary,
        padding: CGFloat = IPTheme.spacing20,
        cornerRadius: CGFloat = IPTheme.radiusLarge,
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
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillStyle)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .shadow(color: IPTheme.shadowColor(for: colorScheme), radius: 14, y: 8)
            .scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.96)
                    .scaleEffect(phase.isIdentity ? 1 : 0.988)
                    .offset(y: phase.isIdentity ? 0 : phase.value * 12)
            }
    }

    private var fillStyle: AnyShapeStyle {
        switch tone {
        case .primary:
            return IPTheme.elevatedFill(for: colorScheme)
        case .secondary:
            return IPTheme.panelFill(for: colorScheme)
        case .accent(let tint):
            return IPTheme.elevatedFill(for: colorScheme, tint: tint)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .accent:
            return IPTheme.accent.opacity(colorScheme == .dark ? 0.24 : 0.18)
        case .primary, .secondary:
            return IPTheme.borderColor(for: colorScheme)
        }
    }
}

struct IPBrandLogo: View {
    var size: CGFloat = 60
    var cornerRadius: CGFloat? = nil
    var showShadow: Bool = true
    var variant: IPBrandLogoVariant = .surface
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundFill)

            HStack(alignment: .bottom, spacing: size * 0.05) {
                Circle()
                    .fill(glyphFill)
                    .frame(width: size * 0.18, height: size * 0.18)

                RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                    .fill(glyphFill)
                    .frame(width: size * 0.18, height: size * 0.42)

                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .fill(glyphFill)
                    .frame(width: size * 0.18, height: size * 0.58)
            }
            .padding(.bottom, size * 0.06)
        }
        .frame(width: size, height: size)
        .shadow(
            color: showShadow ? IPTheme.shadowColor(for: colorScheme).opacity(variant == .filled ? 0.34 : 0.18) : .clear,
            radius: showShadow ? size * 0.14 : 0,
            y: showShadow ? size * 0.08 : 0
        )
        .accessibilityLabel("Job Hopper logo")
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
                colors: [IPTheme.accentSecondary, IPTheme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var glyphFill: Color {
        switch variant {
        case .surface:
            return IPTheme.accent
        case .filled:
            return .white
        }
    }
}

struct IPStarburst: View {
    var size: CGFloat = 34
    var tint: Color = IPTheme.accent

    var body: some View {
        IPStarburstShape()
            .fill(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                IPStarburstShape()
                    .stroke(Color.black.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.18), radius: 12, y: 6)
    }
}

struct IPSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let symbol: String?
    var tint: Color = IPTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(IPTypography.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(IPTheme.textSecondary)
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
                        .font(IPTypography.headlineMedium)
                        .foregroundStyle(IPTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct IPStatusPill: View {
    let title: String
    let symbol: String
    var tint: Color = IPTheme.accent

    var body: some View {
        Label(title, systemImage: symbol)
            .font(IPTypography.labelSmall)
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

struct IPEmptyState: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        IPPanel(tone: .secondary, padding: IPTheme.spacing24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(IPTheme.accent.opacity(0.10))
                        .frame(width: 74, height: 74)
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(IPTheme.accent)
                }

                Text(title)
                    .font(IPTypography.headlineMedium)
                    .foregroundStyle(IPTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(IPTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct IPInputShell<Content: View>: View {
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
                    .fill(IPTheme.accent.opacity(0.10))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(IPTheme.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
    }
}

struct IPUtilityCircleButton: View {
    let symbol: String
    var filled: Bool = false
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? Color.white : IPTheme.textPrimary)
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
                .shadow(color: IPTheme.shadowColor(for: colorScheme).opacity(0.28), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var buttonFill: AnyShapeStyle {
        if filled {
            return AnyShapeStyle(IPTheme.buttonGradient(for: colorScheme))
        }

        return AnyShapeStyle(.regularMaterial)
    }
}

struct IPBottomDock<Content: View>: View {
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
                    .font(IPTypography.labelLarge)
                    .foregroundStyle(IPTheme.textPrimary)
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: IPTheme.radiusXL, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: IPTheme.radiusXL, style: .continuous)
                        .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
                }
        }
        .shadow(color: IPTheme.shadowColor(for: colorScheme).opacity(0.36), radius: 12, y: 6)
    }
}

struct IPScoreRing: View {
    let progress: Double
    let title: String
    let value: String
    var size: CGFloat = 132
    var tint: Color = IPTheme.accent

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
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Text(value)
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 18)
        }
        .frame(width: size, height: size)
    }
}

struct IPConversationBubble: View {
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
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text(roleLabel)
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                Spacer()

                if let trailingSymbol {
                    Image(systemName: trailingSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }

            Text(text)
                .font(IPTypography.bodyLarge)
                .foregroundStyle(IPTheme.textPrimary)
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
            color: colorScheme == .dark ? Color.black.opacity(0.18) : IPTheme.accent.opacity(0.08),
            radius: 14,
            y: 8
        )
    }

    private var avatar: some View {
        Group {
            switch role {
            case .assistant:
                IPBrandLogo(size: 28, showShadow: false, variant: .surface)
            case .interviewer:
                Circle()
                    .fill(IPTheme.accent.opacity(0.14))
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(IPTheme.accent)
                    }
            case .user:
                Circle()
                    .fill(IPTheme.accent)
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
            return IPTheme.surfaceSecondary
        case .interviewer:
            return IPTheme.interviewerBg
        case .user:
            return IPTheme.responseBg
        }
    }

    private var bubbleBorder: Color {
        switch role {
        case .assistant, .interviewer:
            return IPTheme.borderColor(for: colorScheme)
        case .user:
            return IPTheme.accent.opacity(0.18)
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

struct IPTimelineRow: View {
    let time: String
    let title: String
    let detail: String
    var tint: Color = IPTheme.accent

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
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.textSecondary)

                Text(title)
                    .font(IPTypography.labelLarge)
                    .foregroundStyle(IPTheme.textPrimary)

                Text(detail)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

struct IPPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var tint: Color = IPTheme.accent

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IPTypography.bodyLarge)
            .foregroundStyle(IPTheme.primaryButtonLabelColor(for: colorScheme).opacity(isEnabled ? 1 : 0.82))
            .frame(maxWidth: .infinity)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .padding(.vertical, 15)
            .background(
                isEnabled
                    ? IPTheme.buttonGradient(for: colorScheme)
                    : LinearGradient(
                        colors: [Color(uiColor: .systemGray4), Color(uiColor: .systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: isEnabled ? IPTheme.accent.opacity(0.16) : .clear, radius: 10, y: 6)
            .animation(IPAnimations.snappy, value: configuration.isPressed)
    }
}

struct IPSecondaryButtonStyle: ButtonStyle {
    var tint: Color = IPTheme.accent

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IPTypography.bodyMedium)
            .foregroundStyle(IPTheme.secondaryButtonLabelColor(for: colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                IPTheme.secondaryButtonGradient(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.16) : Color.black.opacity(0.03), radius: 6, y: 3)
            .animation(IPAnimations.snappy, value: configuration.isPressed)
    }
}

extension View {
    func ipScrollablePage() -> some View {
        scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
    }
}

struct IPTabAccessory: View {
    let selectedTab: Int
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if placement == .inline {
                HStack(spacing: 8) {
                    IPBrandLogo(size: 22, showShadow: false, variant: .filled)
                    Text(compactTitle)
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(accessoryPrimaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    IPBrandLogo(size: 38, showShadow: false, variant: .filled)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(IPTypography.labelLarge)
                            .foregroundStyle(accessoryPrimaryText)

                        Text(subtitle)
                            .font(IPTypography.bodySmall)
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
                .fill(IPTheme.tabAccessoryFill(for: colorScheme))
        }
        .overlay {
            Capsule()
                .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: IPTheme.shadowColor(for: colorScheme), radius: 14, y: 8)
        .animation(IPAnimations.snappy, value: selectedTab)
    }

    private var accessoryPrimaryText: Color {
        IPTheme.pageTextPrimary
    }

    private var accessorySecondaryText: Color {
        IPTheme.pageTextSecondary
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

private struct IPStarburstShape: Shape {
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
