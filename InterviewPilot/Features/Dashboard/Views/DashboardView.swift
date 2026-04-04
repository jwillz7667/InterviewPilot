import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var showPaywall = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        headerSection
                        UpgradeBannerView { showPaywall = true }
                        heroCTA
                        savedDraftsSection
                        recentActivitySection
                        dailyTipSection
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, IATheme.spacing16)
                    .padding(.bottom, 100)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
            }
            .task {
                viewModel.loadData(modelContext: modelContext)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Interview Ace")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.accent)

                Text(viewModel.displayGreeting)
                    .font(IATypography.headlineLarge)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Ready to ace your next interview?")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
            }

            Spacer()

            IABrandLogo(size: 42, showShadow: false, variant: .outlined)
        }
    }

    // MARK: - Hero CTA

    private var heroCTA: some View {
        NavigationLink(destination: SessionSetupView()) {
            GradientHeroCard(cornerRadius: IATheme.radiusLarge) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Live Interview")
                            .font(IATypography.headlineMedium)
                            .foregroundStyle(.white)

                        Text("Begin a real-time AI-assisted interview session")
                            .font(IATypography.bodyMedium)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Saved Drafts

    @ViewBuilder
    private var savedDraftsSection: some View {
        if !viewModel.savedDrafts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved Drafts")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                VStack(spacing: 8) {
                    ForEach(viewModel.savedDrafts) { draft in
                        NavigationLink {
                            SessionSetupView(
                                viewModel: Self.setupViewModel(from: draft),
                                loadDefaultsOnTask: true
                            )
                        } label: {
                            draftRow(draft)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func draftRow(_ draft: DraftSession) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(IATheme.warning.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "doc.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IATheme.warning)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.jobListingTitle.isEmpty ? "Untitled Draft" : draft.jobListingTitle)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let company = draft.companyName, !company.isEmpty {
                        Text(company)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)
                            .lineLimit(1)

                        Text("\u{2022}")
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textTertiary)
                    }

                    if let type = InterviewType(rawValue: draft.interviewType) {
                        Text(type.displayName)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }

                Text("Saved \(draft.savedAt.formatted(.relative(presentation: .named)))")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(IATheme.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.warning.opacity(0.25), lineWidth: 1)
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteDraft(draft)
            } label: {
                Label("Delete Draft", systemImage: "trash")
            }
        }
    }

    private static func setupViewModel(from draft: DraftSession) -> SessionSetupViewModel {
        let vm = SessionSetupViewModel()
        vm.loadDraft(draft)
        return vm
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Spacer()

                NavigationLink(destination: SessionHistoryView()) {
                    Text("See All")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.accent)
                }
            }

            if viewModel.recentSessions.isEmpty {
                IAEmptyState(
                    title: "No sessions yet",
                    subtitle: "Start your first interview to see activity here.",
                    symbol: "clock"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentSessions, id: \.id) { session in
                        NavigationLink {
                            SessionReviewLoaderView(item: session)
                        } label: {
                            recentSessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentSessionRow(_ session: SessionHistoryItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(IATheme.accent.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: sessionIcon(session))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(session.reviewInterviewType.displayName)
                        .font(IATypography.labelSmall)
                        .foregroundStyle(IATheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(IATheme.accent.opacity(0.10), in: Capsule())

                    Text(session.startedAt.formatted(.relative(presentation: .named)))
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if let score = session.overallScore {
                    dashboardScoreBadge(score)
                }

                Text("\(session.exchangeCount) Qs")
                    .font(IATypography.labelMedium)
                    .foregroundStyle(IATheme.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(IATheme.textTertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    private func dashboardScoreBadge(_ score: Int) -> some View {
        let color = dashboardScoreColor(for: score)
        return Text("\(score)")
            .font(IATypography.labelSmall)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func dashboardScoreColor(for score: Int) -> Color {
        if score >= 80 { return IATheme.success }
        if score >= 60 { return IATheme.accent }
        return IATheme.warning
    }

    private func sessionIcon(_ session: SessionHistoryItem) -> String {
        let type = InterviewType(rawValue: session.interviewType) ?? .general
        switch type {
        case .technical: return "terminal.fill"
        case .behavioral: return "person.2.fill"
        case .systemDesign: return "cpu.fill"
        case .caseStudy: return "doc.text.fill"
        case .hrScreen: return "bubble.left.and.bubble.right.fill"
        case .general: return "waveform"
        }
    }

    // MARK: - Daily Tip

    private var dailyTipSection: some View {
        let tip = dailyTip

        return HStack(spacing: 0) {
            Rectangle()
                .fill(tip.tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: tip.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tip.tint)

                    Text(tip.title)
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)
                }

                Text(tip.body)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
    }

    private var dailyTip: (title: String, body: String, icon: String, tint: Color) {
        let tips: [(String, String, String, Color)] = [
            ("STAR Method",
             "Structure behavioral answers: Situation, Task, Action, Result. This keeps responses focused and demonstrates measurable impact.",
             "star.fill", IATheme.accent),
            ("Own Your Story",
             "Use 'I' not 'we'. Interviewers want to hear YOUR contribution. Name the specific system you built, the decision you made, the metric you moved.",
             "person.fill", IATheme.tertiary),
            ("Quantify Impact",
             "Replace vague claims with numbers: 'reduced latency from 800ms to 120ms' beats 'improved performance significantly' every time.",
             "chart.bar.fill", IATheme.success),
            ("Name the Tech",
             "Don't say 'a database' — say 'PostgreSQL with a GIN index on the JSONB column'. Specificity signals depth and builds credibility.",
             "terminal.fill", IATheme.accent),
            ("Show the Tradeoff",
             "Strong answers acknowledge what you gave up: 'We chose eventual consistency over strong consistency because our SLA allowed 5s propagation delay.'",
             "scale.3d", IATheme.warning),
            ("Answer First",
             "Lead with your answer in the first sentence, then explain. 'I redesigned the auth flow to use JWTs — here's why...' beats a 30-second windup.",
             "bolt.fill", IATheme.primaryContainer),
            ("Prep Your Projects",
             "Have 3-4 go-to projects ready. For each, know: what you built, why, what went wrong, what you'd change, and the measurable outcome.",
             "folder.fill", IATheme.tertiary),
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let tip = tips[dayIndex % tips.count]
        return (title: tip.0, body: tip.1, icon: tip.2, tint: tip.3)
    }

}
