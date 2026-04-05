import AVFoundation
import SwiftUI
import Observation

@Observable
final class PracticeInterviewViewModel {
    // Services
    let audioCapture: AudioCaptureService
    private let realtimeService: OpenAIRealtimeService
    private let audioPlayback: RealtimeAudioPlaybackService
    private let localStorage = SessionStorageService.shared
    private let remoteSync = RemoteSessionSyncService()

    // Session state
    enum PracticeState: Equatable {
        case idle
        case connecting
        case aiSpeaking
        case userSpeaking
        case processing
        case ended
    }

    var sessionState: PracticeState = .idle
    var interviewerTranscript = ""
    var userTranscript = ""
    var fullTranscript: [TranscriptSegment] = []
    var questionNumber = 0
    var elapsedTime: TimeInterval = 0
    var errorMessage: String?
    var isMuted = false

    // Session config (passed from launch view)
    let sessionId: UUID
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let jobListingUrl: String?
    let profileId: String?
    let companyName: String?
    let positionTitle: String?

    // Private
    private var exchanges: [Exchange] = []
    nonisolated(unsafe) private var timer: Timer?
    private var sessionStartTime: Date?
    private var isAISpeaking = false
    private var currentAIQuestion = ""
    private var currentUserResponse = ""
    private var persistedSession: InterviewSession?
    private var syncTask: Task<Void, Never>?
    private var hasReceivedFirstAudioDelta = false
    private var pendingUserTranscriptForExchange = ""

    deinit {
        timer?.invalidate()
    }

    init(
        sessionId: UUID,
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobListingUrl: String?,
        profileId: String?,
        companyName: String?,
        positionTitle: String?,
        openAIKey: String
    ) {
        self.sessionId = sessionId
        self.resume = resume
        self.jobDescription = jobDescription
        self.interviewType = interviewType
        self.jobListingUrl = jobListingUrl
        self.profileId = profileId
        self.companyName = companyName
        self.positionTitle = positionTitle

        self.audioCapture = AudioCaptureService(
            targetSampleRate: Double(APIConfig.realtimeSampleRate),
            sessionMode: .voiceChat,
            categoryOptions: [.allowBluetoothHFP, .defaultToSpeaker]
        )
        self.realtimeService = OpenAIRealtimeService(apiKey: openAIKey)
        self.audioPlayback = RealtimeAudioPlaybackService()

        setupCallbacks()
    }

    // MARK: - Callback Wiring

    private func setupCallbacks() {
        // Mic audio -> Realtime API (with echo prevention)
        let realtimeService = self.realtimeService
        audioCapture.onAudioBuffer = { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self, !self.isAISpeaking, !self.isMuted else { return }
                realtimeService.sendAudio(data)
            }
        }

        // Realtime audio delta -> speaker playback
        realtimeService.onAudioDelta = { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.hasReceivedFirstAudioDelta {
                    self.hasReceivedFirstAudioDelta = true
                    self.isAISpeaking = true
                    self.sessionState = .aiSpeaking
                }
                self.audioPlayback.enqueueAudio(data)
            }
        }

        // AI transcript delta -> streaming display
        realtimeService.onTranscriptDelta = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.interviewerTranscript += text
                self.currentAIQuestion += text
            }
        }

        // User speech transcription (full text, arrives after user finishes speaking)
        realtimeService.onInputTranscript = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.userTranscript = text
                self.currentUserResponse = text
                self.pendingUserTranscriptForExchange = text
            }
        }

        // VAD: user started speaking
        realtimeService.onSpeechStarted = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sessionState = .userSpeaking
                // Interrupt AI playback if user starts speaking
                self.audioPlayback.flush()
                self.isAISpeaking = false
                self.hasReceivedFirstAudioDelta = false
            }
        }

        // VAD: user stopped speaking
        realtimeService.onSpeechStopped = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sessionState = .processing
            }
        }

        // AI finished a complete response turn
        realtimeService.onResponseDone = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAISpeaking = false
                self.hasReceivedFirstAudioDelta = false

                // Record the exchange: AI question + user's previous answer
                self.recordExchangeIfNeeded()

                // Increment question number for the question AI just asked
                self.questionNumber += 1

                // Add AI question to full transcript
                let aiQuestion = self.currentAIQuestion
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !aiQuestion.isEmpty {
                    self.fullTranscript.append(TranscriptSegment(
                        speaker: .interviewer,
                        text: aiQuestion,
                        timestamp: Date()
                    ))
                }

                // Reset for next exchange cycle
                self.currentAIQuestion = ""
                self.interviewerTranscript = ""
                self.userTranscript = ""
                self.sessionState = .userSpeaking
            }
        }

        // Session created -> ready
        realtimeService.onSessionCreated = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.sessionState == .connecting {
                    self.sessionState = .aiSpeaking
                }
            }
        }

        // Error handling
        realtimeService.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.errorMessage = message
            }
        }

        // Reconnection
        realtimeService.onReconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.errorMessage != nil {
                    self.errorMessage = nil
                }
            }
        }

        // Audio interruption handling
        audioCapture.onInterruption = { [weak self] interrupted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if interrupted {
                    self.errorMessage = "Audio interrupted — reconnecting..."
                } else {
                    if self.errorMessage == "Audio interrupted — reconnecting..." {
                        self.errorMessage = nil
                    }
                }
            }
        }

        audioCapture.onRouteChange = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.errorMessage = "Audio device changed — reconnected"
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if self.errorMessage == "Audio device changed — reconnected" {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }

    // MARK: - Session Control

    func startSession() async throws {
        guard sessionState == .idle else { return }

        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""
        guard !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PracticeSessionError.missingAPIKey
        }

        errorMessage = nil
        sessionState = .connecting

        let instructions = InterviewerPromptBuilder.buildInstructions(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            companyName: companyName,
            positionTitle: positionTitle
        )

        do {
            try audioPlayback.start()
            try await realtimeService.connect(instructions: instructions)
            try audioCapture.startCapture()
        } catch {
            audioCapture.stopCapture()
            audioPlayback.stop()
            realtimeService.disconnect()
            sessionState = .idle
            throw error
        }

        let startedAt = Date()
        sessionStartTime = startedAt
        createPersistedSession(startedAt: startedAt)
        persistSessionSnapshot()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.sessionStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    func stopSession() {
        let endedAt = Date()

        // Record any pending exchange before stopping
        recordExchangeIfNeeded()

        realtimeService.disconnect()
        audioCapture.stopCapture()
        audioPlayback.stop()
        syncTask?.cancel()
        timer?.invalidate()
        timer = nil

        persistSessionSnapshot(endedAt: endedAt)
        sessionState = .ended
    }

    // MARK: - Mute Toggle

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            audioCapture.stopCapture()
        } else {
            try? audioCapture.startCapture()
        }
    }

    // MARK: - Skip Question

    func skipQuestion() {
        guard realtimeService.isConnected else { return }

        // Flush current playback
        audioPlayback.flush()
        isAISpeaking = false
        hasReceivedFirstAudioDelta = false

        // Send a response.create to make AI move to the next question.
        // This triggers a new AI turn, which makes the API generate the next question.
        realtimeService.sendResponseCreate()
    }

    // MARK: - Exchange Recording

    private func recordExchangeIfNeeded() {
        let userAnswer = pendingUserTranscriptForExchange
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !userAnswer.isEmpty else {
            pendingUserTranscriptForExchange = ""
            return
        }

        // Find the last AI question from transcript
        let lastAIQuestion = fullTranscript
            .last(where: { $0.speaker == .interviewer })?.text ?? ""

        // Add user response to full transcript
        fullTranscript.append(TranscriptSegment(
            speaker: .user,
            text: userAnswer,
            timestamp: Date()
        ))

        let exchange = Exchange(
            question: lastAIQuestion,
            response: userAnswer,
            type: mapInterviewTypeToQuestionType(),
            latencyMs: 0,
            cached: false
        )
        exchanges.append(exchange)

        persistSessionSnapshot()
        pendingUserTranscriptForExchange = ""
    }

    private func mapInterviewTypeToQuestionType() -> QuestionType {
        switch interviewType {
        case .behavioral: return .behavioral
        case .technical: return .technical
        case .systemDesign: return .systemDesign
        case .caseStudy: return .situational
        case .hrScreen: return .background
        case .general: return .unknown
        }
    }

    // MARK: - Persistence

    private func createPersistedSession(startedAt: Date) {
        guard persistedSession == nil else { return }

        let session = InterviewSession(
            id: sessionId,
            resumeText: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            responseFormat: .fullAnswer
        )
        session.startedAt = startedAt
        session.modelUsed = APIConfig.realtimeModel
        session.jobListingUrl = jobListingUrl
        session.profileId = profileId
        session.setExchanges([])

        persistedSession = session
        localStorage.saveSession(session)
    }

    private func persistSessionSnapshot(endedAt: Date? = nil) {
        guard let session = persistedSession else { return }

        session.resumeText = resume
        session.jobDescription = jobDescription
        session.interviewType = interviewType.rawValue
        session.responseFormat = ResponseFormat.fullAnswer.rawValue
        session.modelUsed = APIConfig.realtimeModel
        session.totalTokensUsed = estimatedTokenUsage()
        session.estimatedCost = 0
        session.setExchanges(exchanges)
        session.jobListingUrl = jobListingUrl
        session.profileId = profileId

        if let endedAt {
            session.endedAt = endedAt
        }

        localStorage.saveChanges()

        let snapshot = SessionSyncSnapshot(
            clientId: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            resumeText: session.resumeText,
            jobDescription: session.jobDescription,
            interviewType: session.interviewType,
            responseFormat: session.responseFormat,
            modelUsed: session.modelUsed,
            totalTokensUsed: session.totalTokensUsed,
            estimatedCost: session.estimatedCost,
            telemetrySummary: SessionTelemetrySummary.build(from: exchanges),
            exchanges: exchanges.enumerated().map { index, exchange in
                ExchangeSyncSnapshot(
                    clientId: exchange.id,
                    timestamp: exchange.timestamp,
                    questionTranscript: exchange.questionTranscript,
                    questionType: exchange.questionType,
                    generatedResponse: exchange.generatedResponse,
                    responseLatencyMs: exchange.responseLatencyMs,
                    wasPreComputed: exchange.wasPreComputed,
                    telemetry: exchange.telemetry,
                    sequenceOrder: index
                )
            },
            jobListingUrl: session.jobListingUrl,
            profileId: session.profileId
        )

        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.remoteSync.syncSession(snapshot)
            } catch {
                if !Task.isCancelled {
                    SyncRetryQueue.shared.enqueue(snapshot)
                }
            }
        }
    }

    private func estimatedTokenUsage() -> Int {
        exchanges.reduce(into: 0) { total, exchange in
            total += exchange.questionTranscript.split(separator: " ").count
            total += exchange.generatedResponse.split(separator: " ").count
        }
    }
}

// MARK: - Error Types

enum PracticeSessionError: LocalizedError {
    case missingAPIKey
    case featureGated

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not configured"
        case .featureGated:
            return "Practice Interview requires an active subscription"
        }
    }
}
