import SwiftUI

struct SessionReviewLoaderView: View {
    let item: SessionHistoryItem

    @State private var reviewViewModel: SessionReviewViewModel?
    @State private var errorMessage: String?

    private let remoteService = RemoteSessionsService.shared
    private let previewViewModel: SessionReviewViewModel?
    private let previewErrorMessage: String?

    init(
        item: SessionHistoryItem,
        previewViewModel: SessionReviewViewModel? = nil,
        previewErrorMessage: String? = nil
    ) {
        self.item = item
        self.previewViewModel = previewViewModel
        self.previewErrorMessage = previewErrorMessage
    }

    var body: some View {
        Group {
            if let previewViewModel {
                SessionReviewView(viewModel: previewViewModel)
            } else if let previewErrorMessage {
                unavailableView(message: previewErrorMessage)
            } else if let reviewViewModel {
                SessionReviewView(viewModel: reviewViewModel)
            } else if let errorMessage {
                unavailableView(message: errorMessage)
            } else {
                ZStack {
                    IAAppBackground()

                    IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                        HStack(spacing: 14) {
                            ProgressView()
                                .tint(IATheme.accent)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Loading session review")
                                    .font(IATypography.headlineSmall)
                                    .foregroundStyle(IATheme.textPrimary)

                                Text("Preparing the post-interview report and exchange timeline.")
                                    .font(IATypography.bodySmall)
                                    .foregroundStyle(IATheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, IATheme.spacing20)
                }
            }
        }
        .task(id: item.id) {
            guard previewViewModel == nil, previewErrorMessage == nil else { return }
            await load()
        }
    }

    private func unavailableView(message: String) -> some View {
        ZStack {
            IAAppBackground()

            VStack(spacing: 16) {
                IAEmptyState(
                    title: "Review unavailable",
                    subtitle: message,
                    symbol: "exclamationmark.triangle"
                )

                Button("Retry") {
                    Task { await load() }
                }
                .buttonStyle(IASecondaryButtonStyle())
                .disabled(previewErrorMessage != nil)
            }
            .padding(.horizontal, IATheme.spacing20)
        }
    }

    @MainActor
    private func load() async {
        if let exchanges = item.exchanges {
            reviewViewModel = SessionReviewViewModel(
                exchanges: exchanges,
                transcript: [],
                duration: item.duration,
                interviewType: item.reviewInterviewType,
                telemetrySummary: item.effectiveTelemetrySummary,
                serverId: item.serverId
            )
            errorMessage = nil
            return
        }

        guard let serverId = item.serverId else {
            errorMessage = "This session is only available locally and does not include a detailed review payload."
            return
        }

        do {
            let detail = try await remoteService.fetchSessionDetail(id: serverId)
            reviewViewModel = SessionReviewViewModel(
                exchanges: detail.exchanges ?? [],
                transcript: [],
                duration: detail.duration,
                interviewType: detail.reviewInterviewType,
                telemetrySummary: detail.effectiveTelemetrySummary,
                serverId: serverId
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Review Unavailable") {
    SessionReviewLoaderView(
        item: SessionHistoryItem(
            id: UUID().uuidString,
            serverId: nil,
            clientId: UUID(),
            source: .local,
            sessionMode: .liveInterview,
            startedAt: .now,
            endedAt: .now,
            interviewType: InterviewType.behavioral.rawValue,
            responseFormat: ResponseFormat.hybrid.rawValue,
            modelUsed: "gpt-5",
            totalTokensUsed: 0,
            estimatedCost: 0,
            exchangeCount: 0,
            exchanges: nil,
            telemetrySummary: nil,
            jobDescription: nil,
            overallScore: nil
        ),
        previewErrorMessage: "This session report is unavailable because the detailed payload was removed."
    )
}
