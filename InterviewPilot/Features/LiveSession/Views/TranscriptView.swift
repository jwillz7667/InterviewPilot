import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: IPTheme.spacing12) {
                    ForEach(segments) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: segment.speaker == .interviewer ? "person.fill" : "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundStyle(segment.speaker == .interviewer ? IPTheme.brandLight : .yellow)

                                Text(segment.speaker == .interviewer ? "Interviewer" : "AI Response")
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(.white.opacity(0.5))

                                Spacer()

                                Text(segment.timestamp, style: .time)
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(.white.opacity(0.3))
                            }

                            Text(segment.text)
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(segment.speaker == .interviewer ? .white.opacity(0.9) : .white)
                                .lineSpacing(3)
                        }
                        .padding(IPTheme.spacing12)
                        .background(
                            segment.speaker == .interviewer
                                ? Color.white.opacity(0.05)
                                : IPTheme.brand.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall)
                        )
                        .id(segment.id)
                    }
                }
                .padding(.horizontal, IPTheme.spacing16)
            }
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
