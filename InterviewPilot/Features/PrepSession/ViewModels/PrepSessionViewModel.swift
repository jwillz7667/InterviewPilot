import AVFoundation
import Observation
import SwiftUI

@Observable
final class PrepSessionViewModel {
    enum SessionState: Equatable {
        case idle
        case connecting
        case aiSpeaking
        case listening
        case userSpeaking
        case thinking
    }

    let audioCapture: AudioCaptureService

    private let realtimeService: OpenAIRealtimePrepService
    private let playbackService = RealtimeAudioPlaybackService()

    let sessionId: UUID
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let jobCategory: JobCategory
    let positionLevel: PositionLevel

    var sessionState: SessionState = .idle
    var currentQuestion: String = ""
    var currentAnswerDraft: String = ""
    var lastAnswer: String = ""
    var elapsedTime: TimeInterval = 0
    var questionCount: Int = 0
    var errorMessage: String?
    var isConnected = false

    private let openAIKey: String
    private var sessionStartTime: Date?
    private var timer: Timer?
    private var hasRegisteredCurrentQuestion = false

    init(
        sessionId: UUID,
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobCategory: JobCategory,
        positionLevel: PositionLevel,
        openAIKey: String
    ) {
        self.sessionId = sessionId
        self.resume = resume
        self.jobDescription = jobDescription
        self.interviewType = interviewType
        self.jobCategory = jobCategory
        self.positionLevel = positionLevel
        self.openAIKey = openAIKey
        self.audioCapture = AudioCaptureService(
            targetSampleRate: Double(APIConfig.realtimePrepSampleRate),
            sessionMode: .voiceChat,
            categoryOptions: [
                .allowBluetoothHFP,
                .defaultToSpeaker
            ],
            bufferDurationSeconds: APIConfig.realtimePrepBufferDurationSeconds
        )
        self.realtimeService = OpenAIRealtimePrepService(apiKey: openAIKey)

        setupCallbacks()
    }

    var statusText: String {
        switch sessionState {
        case .idle:
            return "Ready"
        case .connecting:
            return "Connecting to OpenAI Realtime"
        case .aiSpeaking:
            return "AI interviewer is speaking"
        case .listening:
            return "Listening for your answer"
        case .userSpeaking:
            return "You are answering"
        case .thinking:
            return "Preparing the next question"
        }
    }

    func startSession() async throws {
        guard !openAIKey.isEmpty else {
            throw NSError(
                domain: "PrepSessionViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"]
            )
        }

        errorMessage = nil
        sessionState = .connecting
        currentQuestion = ""
        currentAnswerDraft = ""

        try audioCapture.startCapture()
        try playbackService.start()
        try await realtimeService.connect(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobCategory: jobCategory,
            positionLevel: positionLevel
        )

        let startedAt = Date()
        sessionStartTime = startedAt
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }

    func stopSession() {
        timer?.invalidate()
        timer = nil
        sessionStartTime = nil

        playbackService.stop()
        audioCapture.stopCapture()
        realtimeService.disconnect()

        isConnected = false
        sessionState = .idle
    }

    func requestNextQuestion() {
        guard isConnected else { return }

        if sessionState == .aiSpeaking {
            playbackService.stop()
        }

        currentAnswerDraft = ""
        sessionState = .thinking
        realtimeService.requestNextQuestion()
    }

    func toggleMicrophone() {
        if audioCapture.isCapturing {
            audioCapture.stopCapture()
        } else {
            try? audioCapture.startCapture()
        }
    }

    private func setupCallbacks() {
        let realtimeService = self.realtimeService

        audioCapture.onAudioBuffer = { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self, self.shouldSendMicrophoneAudio else { return }
                realtimeService.sendAudio(data)
            }
        }

        playbackService.onPlaybackStarted = { [weak self] in
            guard let self else { return }
            self.sessionState = .aiSpeaking
        }

        playbackService.onPlaybackFinished = { [weak self] in
            guard let self else { return }
            if self.sessionState != .idle {
                self.sessionState = .listening
            }
        }

        realtimeService.onReady = { [weak self] in
            guard let self else { return }
            self.isConnected = true
        }

        realtimeService.onAssistantResponseStarted = { [weak self] in
            guard let self else { return }
            self.currentQuestion = ""
            self.hasRegisteredCurrentQuestion = false
            self.sessionState = .thinking
        }

        realtimeService.onAssistantAudioStarted = { [weak self] in
            guard let self else { return }
            self.sessionState = .aiSpeaking
        }

        realtimeService.onAssistantAudioChunk = { [weak self] data in
            guard let self else { return }
            self.playbackService.enqueuePCM16(data)
        }

        realtimeService.onAssistantAudioFinished = { [weak self] in
            guard let self else { return }
            self.playbackService.markStreamFinished()
        }

        realtimeService.onAssistantTranscriptUpdated = { [weak self] transcript in
            guard let self else { return }
            self.currentQuestion = transcript
        }

        realtimeService.onAssistantTranscriptCompleted = { [weak self] transcript in
            guard let self else { return }
            self.currentQuestion = transcript

            guard !transcript.isEmpty, !self.hasRegisteredCurrentQuestion else { return }
            self.questionCount += 1
            self.hasRegisteredCurrentQuestion = true
        }

        realtimeService.onUserSpeechStarted = { [weak self] in
            guard let self, self.sessionState != .aiSpeaking else { return }
            self.currentAnswerDraft = ""
            self.sessionState = .userSpeaking
        }

        realtimeService.onUserSpeechStopped = { [weak self] in
            guard let self, self.sessionState != .aiSpeaking else { return }
            self.sessionState = .thinking
        }

        realtimeService.onUserTranscriptUpdated = { [weak self] transcript in
            guard let self else { return }
            self.currentAnswerDraft = transcript
        }

        realtimeService.onUserTranscriptCompleted = { [weak self] transcript in
            guard let self else { return }
            self.lastAnswer = transcript
            self.currentAnswerDraft = transcript
            self.sessionState = .thinking
        }

        realtimeService.onError = { [weak self] message in
            guard let self else { return }
            self.errorMessage = message
            if self.sessionState != .idle {
                self.sessionState = .listening
            }
        }
    }

    private var shouldSendMicrophoneAudio: Bool {
        audioCapture.isCapturing
            && isConnected
            && sessionState != .idle
            && !playbackService.isPlaying
    }
}
