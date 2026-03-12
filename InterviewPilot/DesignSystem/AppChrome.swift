import SwiftUI

enum IPSurfaceTone {
    case primary
    case secondary
    case accent(Color)
}

struct IPAppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.4)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            ZStack {
                IPTheme.pageBackground(for: colorScheme)
                    .ignoresSafeArea()

                MeshGradient(
                    width: 3,
                    height: 3,
                    points: meshPoints(time: time),
                    colors: IPTheme.meshColors(for: colorScheme)
                )
                .opacity(colorScheme == .dark ? 0.96 : 0.86)
                .blur(radius: colorScheme == .dark ? 56 : 74)
                .saturation(colorScheme == .dark ? 1.08 : 0.95)
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.03 : 0.22),
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(IPTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.08))
                    .frame(width: 340, height: 340)
                    .blur(radius: 60)
                    .offset(x: 150, y: -260)

                Circle()
                    .fill(IPTheme.accentWarm.opacity(colorScheme == .dark ? 0.12 : 0.06))
                    .frame(width: 260, height: 260)
                    .blur(radius: 55)
                    .offset(x: -140, y: 320)
            }
        }
    }

    private func meshPoints(time: TimeInterval) -> [SIMD2<Float>] {
        [
            point(0.00, 0.00),
            point(0.52 + 0.05 * sin(time * 0.28), 0.02),
            point(1.00, 0.00),
            point(0.03, 0.48 + 0.05 * cos(time * 0.24)),
            point(0.50 + 0.04 * cos(time * 0.17), 0.52 + 0.05 * sin(time * 0.21)),
            point(0.98, 0.47 + 0.06 * sin(time * 0.23)),
            point(0.00, 1.00),
            point(0.50 + 0.03 * sin(time * 0.18), 0.98),
            point(1.00, 1.00)
        ]
    }

    private func point(_ x: Double, _ y: Double) -> SIMD2<Float> {
        SIMD2<Float>(Float(max(0, min(1, x))), Float(max(0, min(1, y))))
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
                            .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
                    }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: IPTheme.shadowColor(for: colorScheme), radius: 22, y: 16)
            .scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.94)
                    .scaleEffect(phase.isIdentity ? 1 : 0.985)
                    .offset(y: phase.isIdentity ? 0 : phase.value * 14)
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
}

struct IPSectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let symbol: String?
    var tint: Color = IPTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(IPTypography.labelSmall)
                    .tracking(1.1)
                    .foregroundStyle(IPTheme.textSecondary)
            }

            HStack(alignment: .top, spacing: 12) {
                if let symbol {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.14))
                            .frame(width: 44, height: 44)

                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(IPTypography.headlineMedium)
                        .foregroundStyle(IPTheme.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.textSecondary)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct IPEmptyState: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        IPPanel(tone: .secondary, padding: IPTheme.spacing24) {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(IPTheme.accent)
                    .symbolEffect(.breathe.pulse)

                Text(title)
                    .font(IPTypography.headlineMedium)
                    .foregroundStyle(IPTheme.textPrimary)

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
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IPTheme.accent)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }
                }
            }

            content
        }
    }
}

struct IPPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var tint: Color = IPTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IPTypography.bodyLarge)
            .foregroundStyle(Color.white.opacity(isEnabled ? 1 : 0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [tint, IPTheme.accentSecondary]
                        : [Color(uiColor: .systemGray3), Color(uiColor: .systemGray4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IPTheme.radiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.18 : 0), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: isEnabled ? tint.opacity(0.24) : .clear, radius: 16, y: 12)
            .animation(IPAnimations.snappy, value: configuration.isPressed)
    }
}

struct IPSecondaryButtonStyle: ButtonStyle {
    var tint: Color = IPTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IPTypography.bodyMedium)
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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

    var body: some View {
        Group {
            if placement == .inline {
                Label(compactTitle, systemImage: symbol)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(tint)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(IPTypography.labelLarge)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text(subtitle)
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(.thinMaterial, in: Capsule())
        .glassEffect(.regular, in: Capsule())
        .animation(IPAnimations.snappy, value: selectedTab)
    }

    private var compactTitle: String {
        switch selectedTab {
        case 0: return "Prepare"
        case 1: return "History"
        default: return "Settings"
        }
    }

    private var title: String {
        switch selectedTab {
        case 0: return "Build the interview workspace"
        case 1: return "Review previous sessions"
        default: return "Adjust appearance and account"
        }
    }

    private var subtitle: String {
        switch selectedTab {
        case 0: return "Add your resume, job post, and mode before you start."
        case 1: return "Open a session recap with latency and question analysis."
        default: return "Switch light or dark mode and manage sign-in."
        }
    }

    private var symbol: String {
        switch selectedTab {
        case 0: return "sparkles.rectangle.stack.fill"
        case 1: return "clock.arrow.circlepath"
        default: return "paintbrush.pointed.fill"
        }
    }

    private var tint: Color {
        switch selectedTab {
        case 0: return IPTheme.accent
        case 1: return IPTheme.accentWarm
        default: return IPTheme.accentSecondary
        }
    }
}
