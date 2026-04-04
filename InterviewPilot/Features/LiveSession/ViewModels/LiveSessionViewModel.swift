import SwiftUI
import Observation

@MainActor
@Observable
final class LiveSessionViewModel {
    // Services
    let audioCapture: AudioCaptureService
    private let deepgram: DeepgramService
    let responseGenerator: ResponseGeneratorService
    private let answerBank: AnswerBankService
    private let classifier: QuestionClassifierService
    private let localStorage = SessionStorageService.shared
    private let remoteSync = RemoteSessionSyncService()

    // State
    var sessionState: SessionState = .idle
    var interviewerTranscript: String = ""
    var fullTranscript: [TranscriptSegment] = []
    var currentResponse: String = ""
    var responseTokens: [String] = []
    var questionType: QuestionClassification?
    var audioLevel: Float = 0.0
    var elapsedTime: TimeInterval = 0
    var exchangeCount: Int = 0
    var isResponseFromCache: Bool = false
    var errorMessage: String?
    var syncState: SyncState = .idle

    // Session config
    let sessionId: UUID
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let jobCategory: JobCategory
    let positionLevel: PositionLevel
    let responseFormat: ResponseFormat
    let responseBehavior: ResponseBehavior
    let responseTone: ResponseTone
    let responseEmphasis: ResponseEmphasis
    let responseQualityMode: ResponseQualityMode
    let preComputedAnswers: [PreComputedAnswer]
    let modelConfig: ModelConfig?
    let communicationStyle: String?

    // Private state
    private var accumulatedTranscript: String = ""  // Finalized segments only
    private var currentPartial: String = ""          // Current interim partial
    private let hasDeepgramAPIKey: Bool
    private let hasOpenAIAPIKey: Bool
    private var postResponseAccumulatedTranscript: String = ""
    private var postResponseCurrentPartial: String = ""
    private var responseReadyAt: Date?
    private var postResponseSpeechStartedAt: Date?
    private var hasFiredResponse: Bool = false
    private var sessionStartTime: Date?
    private var timer: Timer?
    private var currentExchangeStart: Date?
    private var exchanges: [Exchange] = []
    private var persistedSession: InterviewSession?
    private var modelsUsed: Set<String> = []
    private var syncTask: Task<Void, Never>?
    private var pendingExchangeMetrics = PendingExchangeMetrics()

    // Cached base prompt — built once at session start, reused for every question
    private var cachedBasePrompt: String = ""

    // Predictive buffering — generate in background while interviewer is still talking
    private var isPredictiveBuffering: Bool = false
    private var predictiveBuffer: String = ""
    private var predictiveTokenBuffer: [String] = []
    private var predictiveQuestion: String = ""
    private var predictiveResponseComplete: Bool = false
    private var predictiveFullResponse: String = ""
    private var speechEndedWhileBuffering: Bool = false

    private struct PendingExchangeMetrics {
        var questionStartedAt: Date?
        var questionEndedAt: Date?
        var responseStartedAt: Date?
        var firstTokenAt: Date?
        var cacheLookupMs: Int?
        var classificationMs: Int?
        var streamChunkCount: Int = 0
        var usedPredictiveFire = false
    }

    enum SessionState: Equatable {
        case idle
        case listening
        case interviewerSpeaking
        case generating
        case responseReady
        case postResponseSpeech
    }

    enum SyncState: Equatable {
        case idle
        case syncing
        case synced
        case failed

        var title: String {
            switch self {
            case .idle:
                return "Local"
            case .syncing:
                return "Syncing"
            case .synced:
                return "Synced"
            case .failed:
                return "Sync Pending"
            }
        }
    }

    init(
        sessionId: UUID,
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobCategory: JobCategory,
        positionLevel: PositionLevel,
        responseFormat: ResponseFormat,
        responseBehavior: ResponseBehavior,
        responseTone: ResponseTone,
        responseEmphasis: ResponseEmphasis,
        responseQualityMode: ResponseQualityMode,
        preComputedAnswers: [PreComputedAnswer],
        modelConfig: ModelConfig? = nil,
        communicationStyle: String? = nil,
        deepgramKey: String,
        openAIKey: String
    ) {
        self.sessionId = sessionId
        self.resume = resume
        self.jobDescription = jobDescription
        self.interviewType = interviewType
        self.jobCategory = jobCategory
        self.positionLevel = positionLevel
        self.responseFormat = responseFormat
        self.responseBehavior = responseBehavior
        self.responseTone = responseTone
        self.responseEmphasis = responseEmphasis
        self.responseQualityMode = responseQualityMode
        self.preComputedAnswers = preComputedAnswers
        self.modelConfig = modelConfig
        self.communicationStyle = communicationStyle
        self.hasDeepgramAPIKey = !deepgramKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.hasOpenAIAPIKey = !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        self.audioCapture = AudioCaptureService()
        self.deepgram = DeepgramService(apiKey: deepgramKey)
        self.responseGenerator = ResponseGeneratorService(apiKey: openAIKey)
        self.answerBank = AnswerBankService(answers: preComputedAnswers)
        self.classifier = QuestionClassifierService()

        setupCallbacks()
    }

    private func setupCallbacks() {
        // Audio → Deepgram
        let deepgram = self.deepgram
        audioCapture.onAudioBuffer = { data in
            Task { @MainActor in
                deepgram.sendAudio(data)
            }
        }

        // Deepgram → Transcript display
        deepgram.onPartialTranscript = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch self.sessionState {
                case .listening, .interviewerSpeaking:
                    self.currentPartial = text
                    self.interviewerTranscript = self.accumulatedTranscript.isEmpty
                        ? text
                        : self.accumulatedTranscript + " " + text
                    self.checkForPredictiveFire(fullText: self.interviewerTranscript)

                case .responseReady, .postResponseSpeech:
                    self.sessionState = .postResponseSpeech
                    self.postResponseCurrentPartial = text

                case .idle, .generating:
                    break
                }
            }
        }

        deepgram.onFinalTranscript = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch self.sessionState {
                case .listening, .interviewerSpeaking:
                    self.accumulatedTranscript += (self.accumulatedTranscript.isEmpty ? "" : " ") + text
                    self.accumulatedTranscript = self.accumulatedTranscript
                        .trimmingCharacters(in: .whitespaces)
                    self.currentPartial = ""
                    self.interviewerTranscript = self.accumulatedTranscript

                case .responseReady, .postResponseSpeech:
                    self.sessionState = .postResponseSpeech
                    self.postResponseAccumulatedTranscript +=
                        (self.postResponseAccumulatedTranscript.isEmpty ? "" : " ") + text
                    self.postResponseAccumulatedTranscript = self.postResponseAccumulatedTranscript
                        .trimmingCharacters(in: .whitespaces)
                    self.postResponseCurrentPartial = ""

                case .idle, .generating:
                    break
                }
            }
        }

        deepgram.onSpeechStarted = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let now = Date()

                if self.sessionState == .generating || self.sessionState == .idle {
                    return
                }

                if self.sessionState == .responseReady {
                    self.postResponseAccumulatedTranscript = ""
                    self.postResponseCurrentPartial = ""
                    self.postResponseSpeechStartedAt = Date()
                    self.sessionState = .postResponseSpeech
                    return
                }

                if self.sessionState == .listening {
                    self.sessionState = .interviewerSpeaking
                    if self.currentExchangeStart == nil {
                        self.currentExchangeStart = now
                    }
                    if self.pendingExchangeMetrics.questionStartedAt == nil {
                        self.pendingExchangeMetrics.questionStartedAt = self.currentExchangeStart ?? now
                    }
                }
            }
        }

        deepgram.onSpeechEnded = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let speechEndedAt = Date()
                self.pendingExchangeMetrics.questionEndedAt = self.pendingExchangeMetrics.questionEndedAt ?? speechEndedAt

                if self.sessionState == .postResponseSpeech {
                    self.handlePostResponseUtterance()
                    return
                }

                // If already generating (non-predictive), let it finish
                if self.sessionState == .generating && !self.isPredictiveBuffering {
                    return
                }

                guard self.sessionState == .interviewerSpeaking
                    || self.sessionState == .listening
                    || self.isPredictiveBuffering else {
                    return
                }

                let fullQuestion = self.interviewerTranscript.trimmingCharacters(in: .whitespaces)

                // Predictive generation is running in background — resolve it
                if self.isPredictiveBuffering {
                    self.speechEndedWhileBuffering = true
                    if self.predictiveResponseComplete {
                        self.resolvePredictiveResponse()
                    }
                    // else: onResponseComplete will call resolvePredictiveResponse
                    return
                }

                if !self.hasFiredResponse && !fullQuestion.isEmpty {
                    self.fireResponse(question: fullQuestion)
                }
            }
        }

        deepgram.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Only show error to user if reconnection has been exhausted.
                // During reconnection attempts, DeepgramService handles recovery silently.
                self.errorMessage = "Transcription issue: \(message)"
                if self.sessionState != .idle {
                    self.sessionState = .listening
                }
            }
        }

        deepgram.onReconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Clear any transcription error on successful reconnect
                if self.errorMessage?.hasPrefix("Transcription issue") == true {
                    self.errorMessage = nil
                }
            }
        }

        // Audio interruption handling — restart services after interruption ends
        audioCapture.onInterruption = { [weak self] interrupted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if interrupted {
                    self.errorMessage = "Audio interrupted — reconnecting..."
                } else {
                    // Interruption ended, audio engine auto-restarted by AudioCaptureService
                    if self.errorMessage == "Audio interrupted — reconnecting..." {
                        self.errorMessage = nil
                    }
                }
            }
        }

        audioCapture.onRouteChange = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Audio route changed (e.g., phone mic connected/disconnected).
                // AudioCaptureService auto-restarts the engine on the new route.
                // Brief flash to indicate route change.
                self.errorMessage = "Audio device changed — reconnected"
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if self.errorMessage == "Audio device changed — reconnected" {
                        self.errorMessage = nil
                    }
                }
            }
        }

        // Response generator errors
        responseGenerator.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.errorMessage = message
                self.sessionState = .responseReady
                // Keep hasFiredResponse = true to prevent auto-retry loop.
                // User taps "Next" to reset and try the next question.
                self.pendingExchangeMetrics.responseStartedAt = nil
                self.pendingExchangeMetrics.firstTokenAt = nil
                self.pendingExchangeMetrics.streamChunkCount = 0
            }
        }

        // Response generator → Display (or predictive buffer)
        responseGenerator.onTokenReceived = { [weak self] token in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.pendingExchangeMetrics.firstTokenAt == nil {
                    self.pendingExchangeMetrics.firstTokenAt = Date()
                }
                self.pendingExchangeMetrics.streamChunkCount += 1

                if self.isPredictiveBuffering {
                    self.predictiveBuffer += token
                    self.predictiveTokenBuffer.append(token)
                } else {
                    self.currentResponse += token
                    self.responseTokens.append(token)
                }
            }
        }

        responseGenerator.onResponseComplete = { [weak self] fullText in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isPredictiveBuffering {
                    self.predictiveFullResponse = fullText
                    self.predictiveResponseComplete = true
                    if self.speechEndedWhileBuffering {
                        self.resolvePredictiveResponse()
                    }
                } else {
                    self.completeExchange(with: fullText)
                }
            }
        }
    }

    // MARK: - Session Control

    func startSession() async throws {
        guard sessionState == .idle else { return }
        guard hasDeepgramAPIKey else {
            throw NSError(
                domain: "LiveSessionViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Deepgram API key not configured"]
            )
        }
        guard hasOpenAIAPIKey else {
            throw NSError(
                domain: "LiveSessionViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"]
            )
        }

        errorMessage = nil

        // Pre-build the session-constant system prompt and pre-warm the HTTP connection
        cachedBasePrompt = PromptBuilder.buildBasePrompt(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType.rawValue,
            jobCategory: jobCategory,
            positionLevel: positionLevel,
            format: responseFormat,
            behavior: responseBehavior,
            tone: responseTone,
            emphasis: responseEmphasis,
            qualityMode: responseQualityMode,
            includeResume: responseQualityMode != .free,
            communicationStyle: communicationStyle
        )
        responseGenerator.preWarmConnection()

        let keywords = JobDescriptionService.extractKeywords(from: jobDescription)

        do {
            try await deepgram.connect(keywords: keywords)
            try audioCapture.startCapture()
        } catch {
            audioCapture.stopCapture()
            deepgram.disconnect()
            sessionState = .idle
            throw error
        }

        let startedAt = Date()
        sessionStartTime = startedAt
        sessionState = .listening
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
        audioCapture.stopCapture()
        deepgram.disconnect()
        responseGenerator.cancelGeneration()
        syncTask?.cancel()
        timer?.invalidate()
        timer = nil
        persistSessionSnapshot(endedAt: endedAt)
        responseReadyAt = nil
        clearPostResponseBuffers()
        sessionState = .idle
    }

    // MARK: - Predictive Fire Logic

    private func checkForPredictiveFire(fullText: String) {
        guard !hasFiredResponse else { return }

        let wordCount = fullText.split(separator: " ").count
        guard wordCount >= APIConfig.predictiveFireMinWords else { return }

        // Run cache lookup and classification in parallel
        let cacheLookupStartedAt = Date()
        let cachedAnswer = answerBank.findMatch(
            query: fullText,
            threshold: APIConfig.cacheMatchThreshold
        )
        pendingExchangeMetrics.cacheLookupMs = elapsedMilliseconds(
            from: cacheLookupStartedAt,
            to: Date()
        )

        let classificationStartedAt = Date()
        let classification = classifier.classify(fullText)
        pendingExchangeMetrics.classificationMs = elapsedMilliseconds(
            from: classificationStartedAt,
            to: Date()
        )
        self.questionType = classification

        // Cache hit — use immediately
        if let cachedAnswer {
            pendingExchangeMetrics.usedPredictiveFire = true
            pendingExchangeMetrics.responseStartedAt = Date()
            hasFiredResponse = true
            isResponseFromCache = true
            isPredictiveBuffering = true
            predictiveQuestion = fullText
            speechEndedWhileBuffering = false
            currentExchangeStart = currentExchangeStart ?? Date()
            pendingExchangeMetrics.questionStartedAt = pendingExchangeMetrics.questionStartedAt ?? currentExchangeStart
            modelsUsed.insert(currentSessionModelName)
            bufferCachedAnswer(cachedAnswer)
            return
        }

        // Fire generation aggressively — classification confidence OR sufficient word count
        let hasConfidence = classification.confidence > APIConfig.predictiveFireConfidence
        let hasEnoughWords = wordCount >= APIConfig.predictiveFireMinWords + 2
        if hasConfidence || hasEnoughWords {
            startPredictiveGeneration(question: fullText)
        }
    }

    private func fireResponse(question: String, triggeredPredictively: Bool = false) {
        guard !hasFiredResponse else { return }
        hasFiredResponse = true
        isResponseFromCache = false
        sessionState = .generating
        let responseStartedAt = Date()
        currentExchangeStart = currentExchangeStart ?? responseStartedAt
        pendingExchangeMetrics.questionStartedAt = pendingExchangeMetrics.questionStartedAt ?? currentExchangeStart
        pendingExchangeMetrics.responseStartedAt = responseStartedAt
        pendingExchangeMetrics.usedPredictiveFire = pendingExchangeMetrics.usedPredictiveFire || triggeredPredictively

        // Classify if not already done
        if questionType == nil {
            let classificationStartedAt = Date()
            questionType = classifier.classify(question)
            pendingExchangeMetrics.classificationMs = elapsedMilliseconds(
                from: classificationStartedAt,
                to: Date()
            )
        }

        let classification = questionType
        let model = selectModel(for: classification)
        let normalizedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedQuestion.isEmpty {
            accumulatedTranscript = normalizedQuestion
            interviewerTranscript = normalizedQuestion
        }
        modelsUsed.insert(model)

        responseGenerator.generateResponse(
            question: question,
            cachedBasePrompt: cachedBasePrompt,
            questionType: classification?.type,
            format: responseFormat,
            emphasis: responseEmphasis,
            exchangeHistory: recentExchangeHistory(),
            qualityMode: responseQualityMode,
            tone: responseTone,
            model: model
        )
    }

    /// Build a summary of recent exchanges for conversation threading.
    /// Keeps the last 5 to avoid bloating the prompt while preventing project repetition.
    private func recentExchangeHistory() -> [PromptBuilder.ExchangeSummary] {
        exchanges.suffix(5).map { exchange in
            let firstSentence: String
            if let dotIndex = exchange.generatedResponse.firstIndex(of: ".") {
                firstSentence = String(exchange.generatedResponse[...dotIndex])
            } else {
                firstSentence = String(exchange.generatedResponse.prefix(120))
            }
            // Extract project name heuristic: look for capitalized multi-word sequences
            let projectRef = extractProjectReference(from: exchange.generatedResponse)
            return PromptBuilder.ExchangeSummary(
                question: String(exchange.questionTranscript.prefix(150)),
                responseSummary: firstSentence,
                projectReferenced: projectRef
            )
        }
    }

    /// Simple heuristic to extract project names from responses for diversity tracking.
    private func extractProjectReference(from response: String) -> String? {
        // Look for "on [ProjectName]" or "at [ProjectName]" patterns
        let patterns = ["on ", "at ", "for ", "in ", "called "]
        let words = response.split(separator: " ")
        for (i, word) in words.enumerated() {
            let lower = word.lowercased()
            if patterns.contains(lower + " ") || patterns.contains(String(lower)),
               i + 1 < words.count {
                let next = String(words[i + 1])
                if next.first?.isUppercase == true && next.count > 2 {
                    return next.trimmingCharacters(in: .punctuationCharacters)
                }
            }
        }
        return nil
    }

    private func selectModel(for classification: QuestionClassification?) -> String {
        // Use server-provided model config if available
        if let config = modelConfig {
            switch classification?.type {
            case .coding:
                return config.codingModel
            case .technical, .systemDesign:
                return config.technicalModel
            default:
                return config.defaultModel
            }
        }

        // Fallback to hardcoded config
        if responseQualityMode == .premium {
            switch classification?.type {
            case .coding:
                return APIConfig.premiumCodingResponseModel
            case .technical, .systemDesign:
                return APIConfig.premiumTechnicalResponseModel
            default:
                return APIConfig.premiumResponseModel
            }
        }

        if responseQualityMode == .free {
            return APIConfig.defaultResponseModel
        }

        switch classification?.type {
        case .technical, .systemDesign:
            return APIConfig.technicalResponseModel
        case .coding:
            return APIConfig.codingResponseModel
        default:
            return APIConfig.defaultResponseModel
        }
    }

    func resetForNewQuestion() {
        accumulatedTranscript = ""
        currentPartial = ""
        interviewerTranscript = ""
        currentResponse = ""
        responseTokens = []
        questionType = nil
        hasFiredResponse = false
        isResponseFromCache = false
        currentExchangeStart = nil
        errorMessage = nil
        responseReadyAt = nil
        responseGenerator.cancelGeneration()
        sessionState = .listening
        clearPostResponseBuffers()
        clearPredictiveBuffers()
        pendingExchangeMetrics = PendingExchangeMetrics()
    }

    func resumeListeningForNextQuestion() {
        resetForNewQuestion()

        if !audioCapture.isCapturing {
            try? audioCapture.startCapture()
        }
    }

    private func bufferCachedAnswer(_ answer: PreComputedAnswer) {
        let condensed = makeResponseInterviewLength(answer.response)
        predictiveBuffer = condensed
        predictiveTokenBuffer = condensed.split(separator: " ").enumerated().map { index, word in
            (index == 0 ? "" : " ") + word
        }
        predictiveFullResponse = condensed
        predictiveResponseComplete = true
        pendingExchangeMetrics.firstTokenAt = Date()
        pendingExchangeMetrics.streamChunkCount = predictiveTokenBuffer.count

        // If speech already ended, resolve immediately
        if speechEndedWhileBuffering {
            resolvePredictiveResponse()
        }
    }

    // MARK: - Predictive Buffering

    private func startPredictiveGeneration(question: String) {
        guard !hasFiredResponse else { return }
        hasFiredResponse = true
        isPredictiveBuffering = true
        predictiveQuestion = question
        predictiveBuffer = ""
        predictiveTokenBuffer = []
        predictiveFullResponse = ""
        predictiveResponseComplete = false
        speechEndedWhileBuffering = false
        isResponseFromCache = false

        let responseStartedAt = Date()
        currentExchangeStart = currentExchangeStart ?? responseStartedAt
        pendingExchangeMetrics.questionStartedAt = pendingExchangeMetrics.questionStartedAt ?? currentExchangeStart
        pendingExchangeMetrics.responseStartedAt = responseStartedAt
        pendingExchangeMetrics.usedPredictiveFire = true

        if questionType == nil {
            let classificationStartedAt = Date()
            questionType = classifier.classify(question)
            pendingExchangeMetrics.classificationMs = elapsedMilliseconds(
                from: classificationStartedAt,
                to: Date()
            )
        }

        let classification = questionType
        let model = selectModel(for: classification)
        modelsUsed.insert(model)

        // Start generation in background — tokens go to predictiveBuffer, not display
        responseGenerator.generateResponse(
            question: question,
            cachedBasePrompt: cachedBasePrompt,
            questionType: classification?.type,
            format: responseFormat,
            emphasis: responseEmphasis,
            exchangeHistory: recentExchangeHistory(),
            qualityMode: responseQualityMode,
            tone: responseTone,
            model: model
        )
    }

    private func resolvePredictiveResponse() {
        let fullQuestion = interviewerTranscript.trimmingCharacters(in: .whitespaces)
        guard !fullQuestion.isEmpty else {
            clearPredictiveState()
            return
        }

        let similarity = SimilarityMatchService.wordOverlapSimilarity(
            predictiveQuestion.lowercased(),
            fullQuestion.lowercased()
        )

        if similarity >= APIConfig.predictiveQuestionSimilarityThreshold {
            // Question core didn't change — flush the buffered response
            flushPredictiveBuffer(finalQuestion: fullQuestion)
        } else {
            // Question changed significantly — regenerate with the complete question
            clearPredictiveState()
            hasFiredResponse = false
            isResponseFromCache = false
            pendingExchangeMetrics = PendingExchangeMetrics()
            pendingExchangeMetrics.questionStartedAt = currentExchangeStart
            pendingExchangeMetrics.questionEndedAt = Date()
            fireResponse(question: fullQuestion)
        }
    }

    private func flushPredictiveBuffer(finalQuestion: String) {
        isPredictiveBuffering = false
        sessionState = .generating

        accumulatedTranscript = finalQuestion
        interviewerTranscript = finalQuestion

        if predictiveResponseComplete {
            // Response fully generated — display and complete
            currentResponse = predictiveBuffer
            responseTokens = predictiveTokenBuffer
            clearPredictiveBuffersOnly()
            completeExchange(with: currentResponse)
        } else {
            // Response still streaming — flush partial buffer and let remaining tokens flow to display
            currentResponse = predictiveBuffer
            responseTokens = predictiveTokenBuffer
            clearPredictiveBuffersOnly()
        }
    }

    private func clearPredictiveBuffers() {
        isPredictiveBuffering = false
        predictiveBuffer = ""
        predictiveTokenBuffer = []
        predictiveQuestion = ""
        predictiveResponseComplete = false
        predictiveFullResponse = ""
        speechEndedWhileBuffering = false
    }

    private func clearPredictiveBuffersOnly() {
        predictiveBuffer = ""
        predictiveTokenBuffer = []
        predictiveQuestion = ""
        predictiveResponseComplete = false
        predictiveFullResponse = ""
        speechEndedWhileBuffering = false
    }

    private func clearPredictiveState() {
        responseGenerator.cancelGeneration()
        clearPredictiveBuffers()
    }

    func getExchanges() -> [Exchange] {
        exchanges
    }

    private func handlePostResponseUtterance() {
        let utterance = normalizeTranscript(combinedPostResponseTranscript)
        let speechStartedAt = postResponseSpeechStartedAt
        clearPostResponseBuffers()

        guard !utterance.isEmpty else {
            sessionState = .responseReady
            return
        }

        if shouldTreatAsInterviewerQuestion(utterance, speechStartedAt: speechStartedAt) {
            beginNextQuestion(with: utterance, speechStartedAt: speechStartedAt)
        } else {
            sessionState = .responseReady
        }
    }

    private func beginNextQuestion(with question: String, speechStartedAt: Date? = nil) {
        resetForNewQuestion()
        interviewerTranscript = question
        accumulatedTranscript = question
        let endedAt = Date()
        let startedAt = speechStartedAt ?? endedAt
        currentExchangeStart = startedAt
        pendingExchangeMetrics.questionStartedAt = startedAt
        pendingExchangeMetrics.questionEndedAt = endedAt
        sessionState = .interviewerSpeaking
        checkForPredictiveFire(fullText: question)
        if !hasFiredResponse {
            fireResponse(question: question)
        }
    }

    private func clearPostResponseBuffers() {
        postResponseAccumulatedTranscript = ""
        postResponseCurrentPartial = ""
        postResponseSpeechStartedAt = nil
    }

    private var combinedPostResponseTranscript: String {
        let joined = [postResponseAccumulatedTranscript, postResponseCurrentPartial]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return joined.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }

    private func normalizeTranscript(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldTreatAsInterviewerQuestion(
        _ text: String,
        speechStartedAt: Date?
    ) -> Bool {
        let normalized = normalizeTranscript(text)
        let lower = normalized.lowercased()
        let wordCount = lower.split(separator: " ").count
        guard wordCount > 1 else { return false }

        let questionStarters = [
            "what", "how", "why", "when", "where", "who", "can", "could",
            "would", "will", "do", "did", "are", "is", "have", "tell",
            "walk", "describe", "explain"
        ]
        let interviewerPhrases = [
            "tell me", "walk me through", "can you", "could you", "how would",
            "what is", "what's", "why did", "describe", "explain", "give me",
            "and what about", "what about", "suppose", "let's say",
            "tell me more", "can you elaborate", "go deeper", "expand on",
            "and then", "then what", "how so"
        ]
        let answerPhrases = [
            "i think", "i would", "i've", "i have", "i am", "i'm", "my",
            "we", "our", "in my", "for me", "personally", "one time", "i led"
        ]

        let responseSimilarity = SimilarityMatchService.wordOverlapSimilarity(
            lower,
            currentResponse
        )
        if responseSimilarity >= APIConfig.postResponseEchoSimilarityThreshold {
            return false
        }

        let containsQuestionMark = lower.contains("?")
        let startsWithQuestionWord: Bool
        if let firstWord = lower.split(separator: " ").first {
            startsWithQuestionWord = questionStarters.contains(String(firstWord))
        } else {
            startsWithQuestionWord = false
        }

        let interviewerPhraseMatches = interviewerPhrases.filter { lower.contains($0) }.count
        let answerPhraseMatches = answerPhrases.filter { lower.contains($0) }.count
        let startedSoonAfterResponse = {
            guard let responseReadyAt, let speechStartedAt else { return false }
            return speechStartedAt.timeIntervalSince(responseReadyAt)
                <= APIConfig.postResponseGracePeriodSeconds
        }()

        var questionScore = 0
        var answerScore = 0

        if containsQuestionMark {
            questionScore += 3
        }

        if startsWithQuestionWord {
            questionScore += 2
        }

        questionScore += interviewerPhraseMatches * 2
        answerScore += answerPhraseMatches * 2

        let firstPersonTerms = [" i ", " my ", " we ", " our ", " me "]
        answerScore += firstPersonTerms.reduce(into: 0) { result, term in
            if lower.contains(term) {
                result += 1
            }
        }

        let classification = classifier.classify(lower)
        if classification.type == .followUp && classification.confidence >= 0.8 {
            questionScore += 2
        }

        let hasExplicitQuestionSignal = containsQuestionMark
            || startsWithQuestionWord
            || interviewerPhraseMatches > 0
            || (classification.type == .followUp && classification.confidence >= 0.8)

        if startedSoonAfterResponse {
            answerScore += 1

            // Immediately after surfacing an answer, default to "user is speaking"
            // unless the new utterance clearly looks like a fresh interviewer prompt.
            if !hasExplicitQuestionSignal {
                return false
            }
        }

        return questionScore >= APIConfig.postResponseMinimumQuestionScore
            && questionScore > answerScore
    }

    private func makeResponseInterviewLength(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return normalized }

        let activeQuestionType = questionType?.type
        let maxWords = responseFormat.maxWords(for: responseEmphasis, questionType: activeQuestionType)
        let maxSentences = responseFormat.maxSentences(for: responseEmphasis, questionType: activeQuestionType)
        let maxBullets = responseFormat.maxBullets(for: responseEmphasis)
        let maxBulletWords = responseFormat.maxBulletWords(for: responseEmphasis)

        if normalized.contains("•") {
            let bullets = normalized
                .components(separatedBy: "•")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(maxBullets)
                .map { "• " + shortenToWordLimit($0, maxWords: maxBulletWords) }

            if !bullets.isEmpty {
                return bullets.joined(separator: "\n")
            }
        }

        let sentences = normalized
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var selected: [String] = []
        var wordCount = 0

        for sentence in sentences {
            let sentenceWords = sentence.split(separator: " ").count
            if selected.isEmpty || (selected.count < maxSentences && wordCount + sentenceWords <= maxWords) {
                selected.append(sentence)
                wordCount += sentenceWords
            } else {
                break
            }
        }

        if !selected.isEmpty {
            return selected.joined(separator: ". ") + "."
        }

        return shortenToWordLimit(normalized, maxWords: maxWords)
    }

    private func shortenToWordLimit(_ text: String, maxWords: Int) -> String {
        let words = text.split(separator: " ")
        guard words.count > maxWords else { return text }
        return words.prefix(maxWords).joined(separator: " ") + "..."
    }

    private func completeExchange(with response: String) {
        let finalizedQuestion = currentQuestionTranscript
        let finalizedResponse = makeResponseInterviewLength(response)
        let completedAt = Date()

        currentResponse = finalizedResponse
        accumulatedTranscript = finalizedQuestion
        interviewerTranscript = finalizedQuestion
        sessionState = .responseReady
        responseReadyAt = completedAt
        clearPostResponseBuffers()
        exchangeCount += 1

        fullTranscript.append(TranscriptSegment(
            speaker: .interviewer,
            text: finalizedQuestion,
            timestamp: currentExchangeStart ?? Date()
        ))
        fullTranscript.append(TranscriptSegment(
            speaker: .aiResponse,
            text: finalizedResponse,
            timestamp: completedAt
        ))

        let latency = elapsedMilliseconds(
            from: pendingExchangeMetrics.questionStartedAt ?? currentExchangeStart ?? completedAt,
            to: completedAt
        )
        let telemetry = buildExchangeTelemetry(
            completedAt: completedAt,
            fallbackFirstTokenAt: finalizedResponse.isEmpty ? nil : completedAt
        )
        exchanges.append(Exchange(
            question: finalizedQuestion,
            response: finalizedResponse,
            type: questionType?.type ?? .unknown,
            latencyMs: latency,
            cached: isResponseFromCache,
            telemetry: telemetry
        ))

        persistSessionSnapshot()
    }

    private func buildExchangeTelemetry(
        completedAt: Date,
        fallbackFirstTokenAt: Date?
    ) -> ExchangeTelemetry {
        let firstTokenAt = pendingExchangeMetrics.firstTokenAt ?? fallbackFirstTokenAt

        return ExchangeTelemetry(
            questionDurationMs: optionalElapsedMilliseconds(
                from: pendingExchangeMetrics.questionStartedAt,
                to: pendingExchangeMetrics.questionEndedAt
            ),
            speechEndToFireMs: optionalElapsedMilliseconds(
                from: pendingExchangeMetrics.questionEndedAt,
                to: pendingExchangeMetrics.responseStartedAt
            ),
            timeToFirstTokenMs: optionalElapsedMilliseconds(
                from: pendingExchangeMetrics.responseStartedAt,
                to: firstTokenAt
            ),
            generationDurationMs: optionalElapsedMilliseconds(
                from: pendingExchangeMetrics.responseStartedAt,
                to: completedAt
            ),
            questionEndToCompletionMs: optionalElapsedMilliseconds(
                from: pendingExchangeMetrics.questionEndedAt,
                to: completedAt
            ),
            cacheLookupMs: pendingExchangeMetrics.cacheLookupMs,
            classificationMs: pendingExchangeMetrics.classificationMs,
            streamChunkCount: pendingExchangeMetrics.streamChunkCount,
            usedPredictiveFire: pendingExchangeMetrics.usedPredictiveFire
        )
    }

    private func elapsedMilliseconds(from start: Date?, to end: Date?) -> Int {
        guard let start, let end else { return 0 }
        return max(Int(end.timeIntervalSince(start) * 1000), 0)
    }

    private func optionalElapsedMilliseconds(from start: Date?, to end: Date?) -> Int? {
        guard let start, let end else { return nil }
        return max(Int(end.timeIntervalSince(start) * 1000), 0)
    }

    private var currentQuestionTranscript: String {
        let transcript = interviewerTranscript
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            return transcript
        }

        return accumulatedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentSessionModelName: String {
        switch modelsUsed.count {
        case 0:
            return APIConfig.defaultResponseModel
        case 1:
            return modelsUsed.first ?? APIConfig.defaultResponseModel
        default:
            return "mixed"
        }
    }

    private func createPersistedSession(startedAt: Date) {
        guard persistedSession == nil else { return }

        let session = InterviewSession(
            id: sessionId,
            resumeText: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            responseFormat: responseFormat
        )
        session.startedAt = startedAt
        session.modelUsed = currentSessionModelName
        session.setExchanges([])

        persistedSession = session
        localStorage.saveSession(session)
    }

    private func persistSessionSnapshot(endedAt: Date? = nil) {
        guard let session = persistedSession else { return }

        session.resumeText = resume
        session.jobDescription = jobDescription
        session.interviewType = interviewType.rawValue
        session.responseFormat = responseFormat.rawValue
        session.modelUsed = currentSessionModelName
        session.totalTokensUsed = estimatedTokenUsage()
        session.estimatedCost = 0
        session.setExchanges(exchanges)

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
            }
        )

        syncTask?.cancel()
        syncState = .syncing
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await self.remoteSync.syncSession(snapshot)
                self.syncState = .synced
            } catch {
                if !Task.isCancelled {
                    self.syncState = .failed
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
