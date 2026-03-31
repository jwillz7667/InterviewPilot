import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing20) {
                        headerSection
                        heroCTA
                        practiceByTopicSection
                        recentActivitySection
                        dailyTipSection
                        progressOverviewSection
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, IATheme.spacing16)
                    .padding(.bottom, 100)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Practice by Topic

    private var practiceByTopicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practice by Topic")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            HStack(spacing: 12) {
                topicCard(title: "Technical\nSkills", icon: "terminal.fill", tint: IATheme.accent)
                topicCard(title: "Behavioral", icon: "person.2.fill", tint: IATheme.tertiary)
                topicCard(title: "Soft\nSkills", icon: "bubble.left.and.bubble.right.fill", tint: IATheme.warning)
            }
        }
    }

    private func topicCard(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }

            Text(title)
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
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
                        recentSessionRow(session)
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
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.interviewType.capitalized)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Text(session.startedAt.formatted(.relative(presentation: .named)))
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }

            Spacer()

            Text("\(session.exchangeCount) Qs")
                .font(IATypography.labelMedium)
                .foregroundStyle(IATheme.textSecondary)
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

    // MARK: - Daily Tip

    private var dailyTipSection: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(IATheme.accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Tip: STAR Method")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Text("Structure behavioral answers with Situation, Task, Action, Result. This framework keeps responses focused and demonstrates impact.")
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

    // MARK: - Progress Overview

    private var progressOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Overview")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            IAProgressBar(progress: 0.72, label: "Response Clarity", tint: IATheme.accent)
            IAProgressBar(progress: 0.58, label: "Confidence", tint: IATheme.tertiary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .fill(IATheme.surfaceWhite)
        )
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }
}
