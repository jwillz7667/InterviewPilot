import SwiftUI

struct SessionReviewLoaderView: View {
    let item: SessionHistoryItem

    @State private var reviewViewModel: SessionReviewViewModel?
    @State private var errorMessage: String?

    private let remoteService = RemoteSessionsService.shared

    var body: some View {
        Group {
            if let reviewViewModel {
                SessionReviewView(viewModel: reviewViewModel)
            } else if let errorMessage {
                ZStack {
                    IPAppBackground()

                    VStack(spacing: 16) {
                        IPEmptyState(
                            title: "Review unavailable",
                            subtitle: errorMessage,
                            symbol: "exclamationmark.triangle"
                        )

                        Button("Retry") {
                            Task {
                                await load()
                            }
                        }
                        .buttonStyle(IPSecondaryButtonStyle())
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                }
            } else {
                ZStack {
                    IPAppBackground()

                    ProgressView("Loading session review...")
                        .tint(IPTheme.accent)
                }
            }
        }
        .task(id: item.id) {
            await load()
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
                telemetrySummary: item.effectiveTelemetrySummary
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
                telemetrySummary: detail.effectiveTelemetrySummary
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
