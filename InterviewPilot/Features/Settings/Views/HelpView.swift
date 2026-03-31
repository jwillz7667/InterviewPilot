import SwiftUI

struct HelpView: View {
    var body: some View {
        ZStack {
            IAAppBackground()

            ScrollView {
                VStack(spacing: IATheme.spacing16) {
                    IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                        VStack(alignment: .leading, spacing: 12) {
                            IASectionHeader(
                                eyebrow: "Support",
                                title: "Help & FAQ",
                                subtitle: "Common questions about Interview Ace AI.",
                                symbol: "questionmark.circle.fill"
                            )
                        }
                    }

                    faqItem(
                        question: "How does the live interview mode work?",
                        answer: "Interview Ace AI captures audio through your microphone, transcribes the interviewer's questions using Deepgram Nova-3, and generates suggested responses via OpenAI in real-time. The interviewer transcript and your suggested answer appear in separate lanes."
                    )

                    faqItem(
                        question: "Does the app record or store my interviews?",
                        answer: "Audio is streamed for transcription and is never saved to disk. Post-session, only the text transcript and response data are stored in your account for review purposes."
                    )

                    faqItem(
                        question: "Why do I need to upload my resume?",
                        answer: "Your resume grounds the AI's responses in your actual experience. Without it, answers would be generic. With it, the AI references your specific projects, skills, and career trajectory."
                    )

                    faqItem(
                        question: "What's the difference between Plus and Pro?",
                        answer: "Plus unlocks unlimited live interviews with full history. Pro adds voice prep mode, Top Tier answer quality (stronger models), and priority response generation."
                    )

                    faqItem(
                        question: "Can the interviewer hear the AI responses?",
                        answer: "No. Responses appear as silent on-screen text. There is no audio output during live sessions — the guidance is visual only, designed for you to read and paraphrase naturally."
                    )

                    faqItem(
                        question: "What happens if I lose network during a session?",
                        answer: "The app requires an active network connection for transcription and response generation. If connectivity drops, the session pauses and resumes automatically when the connection returns."
                    )
                }
                .padding(.horizontal, IATheme.spacing20)
                .padding(.vertical, IATheme.spacing20)
            }
            .iaScrollablePage()
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faqItem(question: String, answer: String) -> some View {
        IAPanel(tone: .primary, padding: 18, cornerRadius: 24) {
            DisclosureGroup {
                Text(answer)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            } label: {
                Text(question)
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .tint(IATheme.accent)
        }
    }
}
