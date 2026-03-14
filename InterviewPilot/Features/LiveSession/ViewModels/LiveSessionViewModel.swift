import SwiftUI
import Observation

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

    // Session config
    let sessionId: UUID
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let responseFormat: ResponseFormat
    let responseBehavior: ResponseBehavior
    let responseTone: ResponseTone
    let responseEmphasis: ResponseEmphasis
    let preComputedAnswers: [PreComputedAnswer]

    // Private state
    private var accumulatedTranscript: String = ""  // Finalized segments only
    private var currentPartial: String = ""          // Current interim partial
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

    enum SessionState: Equatable {
        case idle
        case listening
        case interviewerSpeaking
        case generating
        case responseReady
        case postResponseSpeech
    }

    init(
        sessionId: UUID,
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        responseFormat: ResponseFormat,
        responseBehavior: ResponseBehavior,
        responseTone: ResponseTone,
        responseEmphasis: ResponseEmphasis,
        preComputedAnswers: [PreComputedAnswer],
        deepgramKey: String,
        openAIKey: String
    ) {
        self.sessionId = sessionId
        self.resume = resume
        self.jobDescription = jobDescription
        self.interviewType = interviewType
        self.responseFormat = responseFormat
        self.responseBehavior = responseBehavior
        self.responseTone = responseTone
        self.responseEmphasis = responseEmphasis
        self.preComputedAnswers = preComputedAnswers

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

        deepgram.onFinalTranscript = { [weak self] text in
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

        deepgram.onSpeechStarted = { [weak self] in
            guard let self else { return }

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
                    self.currentExchangeStart = Date()
                }
            }
        }

        deepgram.onSpeechEnded = { [weak self] in
            guard let self else { return }

            if self.sessionState == .postResponseSpeech {
                self.handlePostResponseUtterance()
                return
            }

            guard self.sessionState == .interviewerSpeaking || self.sessionState == .listening else {
                return
            }

            let fullQuestion = self.interviewerTranscript.trimmingCharacters(in: .whitespaces)
            if !self.hasFiredResponse && !fullQuestion.isEmpty {
                self.fireResponse(question: fullQuestion)
            }
        }

        // Response generator errors
        responseGenerator.onError = { [weak self] message in
            guard let self else { return }
            self.errorMessage = message
            self.sessionState = .listening
            self.hasFiredResponse = false  // Allow retry
        }

        // Response generator → Display
        responseGenerator.onTokenReceived = { [weak self] token in
            guard let self else { return }
            self.currentResponse += token
            self.responseTokens.append(token)
        }

        responseGenerator.onResponseComplete = { [weak self] fullText in
            guard let self else { return }
            self.completeExchange(with: fullText)
        }
    }

    // MARK: - Session Control

    func startSession() async throws {
        let keywords = JobDescriptionService.extractKeywords(from: jobDescription)

        try await deepgram.connect(keywords: keywords)
        try audioCapture.startCapture()

        let startedAt = Date()
        sessionStartTime = startedAt
        sessionState = .listening
        createPersistedSession(startedAt: startedAt)
        persistSessionSnapshot()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    func stopSession() {
        let endedAt = Date()
        audioCapture.stopCapture()
        deepgram.disconnect()
        responseGenerator.cancelGeneration()
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

        // Check answer bank first
        if let cachedAnswer = answerBank.findMatch(
            query: fullText,
            threshold: APIConfig.cacheMatchThreshold
        ) {
            hasFiredResponse = true
            isResponseFromCache = true
            sessionState = .generating
            currentExchangeStart = currentExchangeStart ?? Date()
            accumulatedTranscript = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            interviewerTranscript = accumulatedTranscript
            modelsUsed.insert(currentSessionModelName)
            displayCachedAnswer(cachedAnswer)
            return
        }

        // Classify question type
        let classification = classifier.classify(fullText)
        self.questionType = classification

        // Fire if enough confidence — lowered word count threshold for faster triggering
        if classification.confidence > APIConfig.predictiveFireConfidence && wordCount >= 8 {
            fireResponse(question: fullText)
        }
    }

    private func fireResponse(question: String) {
        guard !hasFiredResponse else { return }
        hasFiredResponse = true
        isResponseFromCache = false
        sessionState = .generating
        currentExchangeStart = currentExchangeStart ?? Date()

        // Classify if not already done
        if questionType == nil {
            questionType = classifier.classify(question)
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
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType.rawValue,
            questionType: classification?.type,
            format: responseFormat,
            behavior: responseBehavior,
            tone: responseTone,
            emphasis: responseEmphasis,
            model: model
        )
    }

    private func selectModel(for classification: QuestionClassification?) -> String {
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
    }

    func resumeListeningForNextQuestion() {
        resetForNewQuestion()

        if !audioCapture.isCapturing {
            try? audioCapture.startCapture()
        }
    }

    private func displayCachedAnswer(_ answer: PreComputedAnswer) {
        let condensed = makeResponseInterviewLength(answer.response)
        let words = condensed.split(separator: " ").map(String.init)
        Task {
            for (index, word) in words.enumerated() {
                if Task.isCancelled { break }
                let token = (index == 0 ? "" : " ") + word
                self.currentResponse += token
                self.responseTokens.append(token)
                try? await Task.sleep(for: .milliseconds(20))
            }
            self.completeExchange(with: self.currentResponse)
        }
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
            beginNextQuestion(with: utterance)
        } else {
            sessionState = .responseReady
        }
    }

    private func beginNextQuestion(with question: String) {
        resetForNewQuestion()
        interviewerTranscript = question
        accumulatedTranscript = question
        currentExchangeStart = Date()
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

        let latency = Int((completedAt.timeIntervalSince(currentExchangeStart ?? completedAt)) * 1000)
        exchanges.append(Exchange(
            question: finalizedQuestion,
            response: finalizedResponse,
            type: questionType?.type ?? .unknown,
            latencyMs: latency,
            cached: isResponseFromCache
        ))

        persistSessionSnapshot()
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
            exchanges: exchanges.enumerated().map { index, exchange in
                ExchangeSyncSnapshot(
                    clientId: exchange.id,
                    timestamp: exchange.timestamp,
                    questionTranscript: exchange.questionTranscript,
                    questionType: exchange.questionType,
                    generatedResponse: exchange.generatedResponse,
                    responseLatencyMs: exchange.responseLatencyMs,
                    wasPreComputed: exchange.wasPreComputed,
                    sequenceOrder: index
                )
            }
        )

        Task {
            try? await self.remoteSync.syncSession(snapshot)
        }
    }

    private func estimatedTokenUsage() -> Int {
        exchanges.reduce(into: 0) { total, exchange in
            total += exchange.questionTranscript.split(separator: " ").count
            total += exchange.generatedResponse.split(separator: " ").count
        }
    }
}
