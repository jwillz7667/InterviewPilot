import AVFoundation
import SwiftUI
import Observation

@Observable
final class PracticeInterviewViewModel {
    // Services
    let audioCapture: AudioCaptureService
    private let realtimeService: OpenAIRealtimeService
    private let audioPlayback: RealtimeAudioPlaybackService
    private let responseGenerator: ResponseGeneratorService
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
    var idealAnswer = ""
    var isGeneratingAnswer = false
    var deliveryVerdict: DeliveryVerdict?
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
    private var cachedBasePrompt = ""
    private var answerGenerationTask: Task<Void, Never>?

    enum DeliveryVerdict: Equatable {
        case natural(score: Int)
        case reading(score: Int)
        case incomplete

        var label: String {
            switch self {
            case .natural: return "Natural Delivery"
            case .reading: return "Sounds Like Reading"
            case .incomplete: return "Incomplete Answer"
            }
        }

        var score: Int {
            switch self {
            case .natural(let s), .reading(let s): return s
            case .incomplete: return 0
            }
        }

        var icon: String {
            switch self {
            case .natural: return "checkmark.circle.fill"
            case .reading: return "exclamationmark.triangle.fill"
            case .incomplete: return "xmark.circle.fill"
            }
        }
    }

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
        positionTitle: String?
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
        self.realtimeService = OpenAIRealtimeService()
        self.audioPlayback = RealtimeAudioPlaybackService()
        self.responseGenerator = ResponseGeneratorService()

        // Build the candidate-side prompt for generating ideal answers
        self.cachedBasePrompt = PromptBuilder.buildBasePrompt(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType.rawValue,
            jobCategory: .softwareEngineering,
            positionLevel: .seniorIndividualContributor,
            format: .fullAnswer,
            behavior: .direct,
            tone: .confident,
            emphasis: .technicalDepth,
            qualityMode: .premium,
            includeResume: true
        )

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

                    // Generate the ideal answer for this question
                    self.generateIdealAnswer(for: aiQuestion)
                }

                // Reset for next exchange cycle
                self.currentAIQuestion = ""
                self.interviewerTranscript = ""
                self.userTranscript = ""
                self.deliveryVerdict = nil
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

        answerGenerationTask?.cancel()
        responseGenerator.cancelGeneration()
        responseGenerator.tearDown()
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

        // Analyze delivery quality against the ideal answer
        if !idealAnswer.isEmpty {
            analyzeDelivery(userResponse: userAnswer, idealResponse: idealAnswer)
        }

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

    // MARK: - Ideal Answer Generation

    private func generateIdealAnswer(for question: String) {
        answerGenerationTask?.cancel()
        idealAnswer = ""
        isGeneratingAnswer = true

        let classifier = QuestionClassifierService()
        let classification = classifier.classify(question)
        let questionType = QuestionType(rawValue: classification.type.rawValue)
        let recentHistory = exchanges.suffix(5).map {
            PromptBuilder.ExchangeSummary(
                question: $0.questionTranscript,
                responseSummary: String($0.generatedResponse.prefix(100)),
                projectReferenced: nil
            )
        }

        let responseGenerator = self.responseGenerator
        responseGenerator.onTokenReceived = { [weak self] token in
            Task { @MainActor [weak self] in
                self?.idealAnswer += token
            }
        }
        responseGenerator.onResponseComplete = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isGeneratingAnswer = false
            }
        }

        answerGenerationTask = Task { [weak self] in
            guard self != nil else { return }
            responseGenerator.generateResponse(
                question: question,
                cachedBasePrompt: self!.cachedBasePrompt,
                questionType: questionType,
                format: .fullAnswer,
                emphasis: .technicalDepth,
                exchangeHistory: recentHistory,
                qualityMode: .premium,
                tone: .confident,
                model: APIConfig.premiumResponseModel
            )
        }
    }

    // MARK: - Delivery Analysis

    private func analyzeDelivery(userResponse: String, idealResponse: String) {
        guard !userResponse.isEmpty, !idealResponse.isEmpty else {
            deliveryVerdict = .incomplete
            return
        }

        let userWords = Set(userResponse.lowercased().split(separator: " ").map(String.init))
        let idealWords = Set(idealResponse.lowercased().split(separator: " ").map(String.init))

        // Content coverage: how much of the ideal answer's key points did the user hit?
        let commonWords = userWords.intersection(idealWords)
        let stopWords: Set<String> = ["the", "a", "an", "is", "was", "were", "are", "in", "on", "at", "to",
                                       "for", "of", "and", "or", "but", "i", "we", "my", "our", "that", "this",
                                       "it", "with", "from", "by", "as", "so", "if", "then", "than", "very"]
        let meaningfulIdeal = idealWords.subtracting(stopWords)
        let meaningfulCoverage = meaningfulIdeal.isEmpty ? 0.0 :
            Double(commonWords.subtracting(stopWords).count) / Double(meaningfulIdeal.count)

        // Length ratio: if user response is way shorter, they skipped key points
        let lengthRatio = min(Double(userWords.count) / max(Double(idealWords.count), 1.0), 1.5)

        // Reading detection heuristics:
        // 1. Very high overlap (>80%) suggests reading verbatim
        // 2. Similar sentence structure suggests reading
        let overlapRatio = idealWords.isEmpty ? 0.0 :
            Double(commonWords.count) / Double(idealWords.count)

        // Natural speech indicators: filler words, hedging, personal markers
        let naturalMarkers = ["um", "uh", "like", "basically", "actually", "honestly",
                              "i think", "i believe", "in my experience", "let me think",
                              "so basically", "you know"]
        let lowerResponse = userResponse.lowercased()
        let hasNaturalMarkers = naturalMarkers.contains { lowerResponse.contains($0) }

        // Score calculation
        var score: Int
        let isLikelyReading: Bool

        if overlapRatio > 0.75 && !hasNaturalMarkers {
            // Very high overlap + no natural speech markers = likely reading
            isLikelyReading = true
            score = Int(meaningfulCoverage * 60) // Cap at 60 for reading
        } else if meaningfulCoverage < 0.15 || lengthRatio < 0.2 {
            // Too little content covered
            deliveryVerdict = .incomplete
            return
        } else {
            isLikelyReading = false
            // Natural delivery score: coverage (60%) + length (20%) + naturalness (20%)
            let coverageScore = meaningfulCoverage * 60
            let lengthScore = min(lengthRatio, 1.0) * 20
            let naturalScore = hasNaturalMarkers ? 20.0 : 12.0
            score = Int(coverageScore + lengthScore + naturalScore)
        }

        score = max(0, min(100, score))

        if isLikelyReading {
            deliveryVerdict = .reading(score: score)
        } else {
            deliveryVerdict = .natural(score: score)
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
                let serverId = try await self.remoteSync.syncSession(snapshot)
                self.persistedSession?.serverId = serverId
                self.localStorage.saveChanges()
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
    case featureGated

    var errorDescription: String? {
        switch self {
        case .featureGated:
            return "Practice Interview requires an active subscription"
        }
    }
}
