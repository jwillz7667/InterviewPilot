import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        IAConversationBubble(
                            role: segment.speaker == .interviewer ? .interviewer : .assistant,
                            title: segment.speaker == .interviewer ? "Interviewer" : "AI Response",
                            text: segment.text,
                            symbol: segment.speaker == .interviewer ? "person.fill" : "sparkles",
                            trailingSymbol: "speaker.wave.2"
                        )
                        .id(segment.id)
                    }
                }
                .padding(.horizontal, IATheme.spacing16)
                .padding(.vertical, IATheme.spacing8)
            }
            .iaScrollablePage()
            .onChange(of: segments.count) {
                if let last = segments.last {
                    withAnimation(IAAnimations.gentle) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
