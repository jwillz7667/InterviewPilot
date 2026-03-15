import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        IPConversationBubble(
                            role: segment.speaker == .interviewer ? .interviewer : .assistant,
                            title: segment.speaker == .interviewer ? "Interviewer" : "AI Response",
                            text: segment.text,
                            symbol: segment.speaker == .interviewer ? "person.fill" : "sparkles",
                            trailingSymbol: "speaker.wave.2"
                        )
                        .id(segment.id)
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
