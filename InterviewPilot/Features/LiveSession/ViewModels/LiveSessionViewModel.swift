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
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let responseFormat: ResponseFormat
    let preComputedAnswers: [PreComputedAnswer]

    // Private state
    private var accumulatedTranscript: String = ""  // Finalized segments only
    private var currentPartial: String = ""          // Current interim partial
    private var hasFiredResponse: Bool = false
    private var sessionStartTime: Date?
    private var timer: Timer?
    private var currentExchangeStart: Date?
    private var exchanges: [Exchange] = []
    private var responseReadyTime: Date?             // When response finished displaying
    private var resetDebounceTask: Task<Void, Never>?

    // Minimum seconds to show response before allowing reset from new speech
    private let responseDisplayCooldown: TimeInterval = 5.0

    enum SessionState: Equatable {
        case idle
        case listening
        case interviewerSpeaking
        case generating
        case responseReady
    }

    init(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        responseFormat: ResponseFormat,
        preComputedAnswers: [PreComputedAnswer],
        deepgramKey: String,
        openAIKey: String
    ) {
        self.resume = resume
        self.jobDescription = jobDescription
        self.interviewType = interviewType
        self.responseFormat = responseFormat
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
        audioCapture.onAudioBuffer = { [weak self] data in
            Task { @MainActor in
                self?.deepgram.sendAudio(data)
            }
        }

        // Deepgram → Transcript display
        deepgram.onPartialTranscript = { [weak self] text in
            guard let self else { return }
            // Only process transcript when we're NOT generating/showing a response
            // (otherwise YOUR voice reading the answer gets transcribed and causes chaos)
            guard self.sessionState == .listening || self.sessionState == .interviewerSpeaking else {
                return
            }
            self.currentPartial = text
            // Show accumulated finals + current partial
            self.interviewerTranscript = self.accumulatedTranscript.isEmpty
                ? text
                : self.accumulatedTranscript + " " + text
            self.checkForPredictiveFire(fullText: self.interviewerTranscript)
        }

        deepgram.onFinalTranscript = { [weak self] text in
            guard let self else { return }
            // Only accumulate transcript during listening/speaking states
            guard self.sessionState == .listening || self.sessionState == .interviewerSpeaking else {
                return
            }
            self.accumulatedTranscript += (self.accumulatedTranscript.isEmpty ? "" : " ") + text
            self.accumulatedTranscript = self.accumulatedTranscript
                .trimmingCharacters(in: .whitespaces)
            self.currentPartial = ""
            self.interviewerTranscript = self.accumulatedTranscript
        }

        deepgram.onSpeechStarted = { [weak self] in
            guard let self else { return }

            // If we're generating or just showed a response, IGNORE new speech events
            // (it's the user's voice reading the answer)
            if self.sessionState == .generating {
                return
            }

            if self.sessionState == .responseReady {
                // Only reset if enough time has passed since response was displayed
                guard let readyTime = self.responseReadyTime,
                      Date().timeIntervalSince(readyTime) >= self.responseDisplayCooldown else {
                    return
                }
                // Debounce: wait a moment to confirm this is real new speech, not a blip
                self.resetDebounceTask?.cancel()
                self.resetDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    guard !Task.isCancelled else { return }
                    self.resetForNewQuestion()
                    self.sessionState = .interviewerSpeaking
                }
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
            // Only fire response if we're actually listening to the interviewer
            guard self.sessionState == .interviewerSpeaking || self.sessionState == .listening else {
                return
            }
            // Use full text (accumulated + any partial that wasn't finalized)
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
            self.sessionState = .responseReady
            self.responseReadyTime = Date()
            self.exchangeCount += 1
            self.fullTranscript.append(TranscriptSegment(
                speaker: .interviewer,
                text: self.accumulatedTranscript,
                timestamp: self.currentExchangeStart ?? Date()
            ))
            self.fullTranscript.append(TranscriptSegment(
                speaker: .aiResponse,
                text: fullText,
                timestamp: Date()
            ))

            let latency = Int((Date().timeIntervalSince(self.currentExchangeStart ?? Date())) * 1000)
            self.exchanges.append(Exchange(
                question: self.accumulatedTranscript,
                response: fullText,
                type: self.questionType?.type ?? .unknown,
                latencyMs: latency,
                cached: self.isResponseFromCache
            ))
        }
    }

    // MARK: - Session Control

    func startSession() async throws {
        let keywords = JobDescriptionService.extractKeywords(from: jobDescription)

        try await deepgram.connect(keywords: keywords)
        try audioCapture.startCapture()

        sessionStartTime = Date()
        sessionState = .listening

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.sessionStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    func stopSession() {
        audioCapture.stopCapture()
        deepgram.disconnect()
        responseGenerator.cancelGeneration()
        timer?.invalidate()
        timer = nil
        resetDebounceTask?.cancel()
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

        let model = selectModel(for: questionType)

        responseGenerator.generateResponse(
            question: question,
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType.rawValue,
            format: responseFormat,
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
        responseReadyTime = nil
        errorMessage = nil
        resetDebounceTask?.cancel()
        responseGenerator.cancelGeneration()
        sessionState = .listening
    }

    private func displayCachedAnswer(_ answer: PreComputedAnswer) {
        let words = answer.response.split(separator: " ").map(String.init)
        Task {
            for (index, word) in words.enumerated() {
                if Task.isCancelled { break }
                let token = (index == 0 ? "" : " ") + word
                self.currentResponse += token
                self.responseTokens.append(token)
                try? await Task.sleep(for: .milliseconds(20))
            }
            self.sessionState = .responseReady
            self.responseReadyTime = Date()
            self.exchangeCount += 1
        }
    }

    func getExchanges() -> [Exchange] {
        exchanges
    }
}
