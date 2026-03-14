import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        IPPanel(
                            tone: segment.speaker == .interviewer ? .secondary : .accent(IPTheme.accent),
                            padding: IPTheme.spacing16,
                            cornerRadius: IPTheme.radiusMedium
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: segment.speaker == .interviewer ? "person.fill" : "sparkles")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(segment.speaker == .interviewer ? IPTheme.accentForeground : IPTheme.accentWarm)

                                    Text(segment.speaker == .interviewer ? "Interviewer" : "AI Response")
                                        .font(IPTypography.labelSmall)
                                        .foregroundStyle(IPTheme.textSecondary)

                                    Spacer()

                                    Text(segment.timestamp, style: .time)
                                        .font(IPTypography.labelSmall)
                                        .foregroundStyle(IPTheme.textSecondary)
                                }

                                Text(segment.text)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.textPrimary)
                                    .lineSpacing(3)
                            }
                            .id(segment.id)
                        }
                    }
                }
                .padding(.horizontal, IPTheme.spacing16)
                .padding(.vertical, IPTheme.spacing8)
            }
            .ipScrollablePage()
            .onChange(of: segments.count) {
                if let last = segments.last {
                    withAnimation(IPAnimations.gentle) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
