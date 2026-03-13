# Job Hopper — Real-Time AI Interview Assistant for iOS
## Final Technical Specification for Implementation

**Version:** 1.0 FINAL
**Date:** 2026-03-10
**Platform:** iOS 26+ (iPhone)
**Implementing Agent:** Claude Code
**Language:** Swift 6.x / SwiftUI

---

## IMPLEMENTATION INSTRUCTIONS FOR CLAUDE CODE

This spec defines a complete iOS application. Build it exactly as specified. The app captures audio from the iPhone microphone (picking up an interviewer's voice from nearby laptop speakers during a video call), streams it to Deepgram Nova-3 for real-time transcription, then sends the transcript to a fast OpenAI text model to generate interview responses displayed on screen.

Key constraints:
- iOS 26 SDK, SwiftUI only (no UIKit except where SwiftUI has no equivalent)
- Use iOS 26 Liquid Glass materials, SF Symbols 7, and the latest typography system
- All animations use SwiftUI spring physics — nothing appears or disappears instantly
- Offline-capable for pre-session setup; network required for live sessions
- No backend server needed — the app connects directly to Deepgram and OpenAI APIs
- API keys stored in iOS Keychain, never hardcoded

---

## 1. APP OVERVIEW

### 1.1 What It Does

1. User uploads resume (PDF) and pastes job description before the interview
2. App pre-generates 15-25 likely Q&A pairs using GPT-4.1
3. User starts a live session, places phone face-up on desk next to laptop
4. iPhone mic captures interviewer's voice from laptop speakers
5. Audio streams to Deepgram Nova-3 via WebSocket — real-time transcript appears on screen
6. At ~60% of question heard, app fires a request to GPT-4.1-nano for a response
7. Response text streams onto screen token-by-token BEFORE interviewer finishes
8. User glances at phone to reference the answer while speaking
9. After session: full transcript with performance review

### 1.2 Primary Use Case

Phone sits face-up on desk during a video interview (Zoom/Teams/Meet on laptop). Interviewer's voice plays through laptop speakers. iPhone mic captures that audio. User reads AI-generated responses from the phone screen while answering naturally.

---

## 2. PROJECT STRUCTURE

```
InterviewPilot/
├── InterviewPilotApp.swift                 # App entry point
├── Info.plist                              # Microphone usage description
│
├── Configuration/
│   ├── AppEnvironment.swift                # API keys, feature flags
│   ├── DependencyContainer.swift           # Service injection
│   └── Constants.swift                     # Timing thresholds, model names
│
├── Models/
│   ├── InterviewSession.swift              # Session data model
│   ├── Exchange.swift                      # Single Q&A pair
│   ├── PreComputedAnswer.swift             # Cached Q&A from pre-session
│   ├── TranscriptSegment.swift             # Deepgram transcript chunk
│   ├── InterviewType.swift                 # Behavioral, technical, etc.
│   ├── ResponseFormat.swift                # Full, bullets, hybrid
│   └── QuestionClassification.swift        # Question type + confidence
│
├── Services/
│   ├── Audio/
│   │   ├── AudioCaptureService.swift       # AVAudioEngine mic capture
│   │   └── AudioPlaybackService.swift      # TTS playback to AirPod
│   │
│   ├── Transcription/
│   │   ├── DeepgramService.swift           # WebSocket streaming to Deepgram
│   │   ├── DeepgramModels.swift            # Response parsing models
│   │   └── TranscriptAccumulator.swift     # Builds full transcript from partials
│   │
│   ├── AI/
│   │   ├── ResponseGeneratorService.swift  # Streams responses from OpenAI
│   │   ├── QuestionClassifierService.swift # Classifies question type
│   │   ├── AnswerBankService.swift         # Pre-computed Q&A management
│   │   ├── SimilarityMatchService.swift    # Cosine similarity for cache hits
│   │   └── PromptBuilder.swift             # System prompt construction
│   │
│   ├── Document/
│   │   ├── ResumeParserService.swift       # PDF text extraction
│   │   └── JobDescriptionService.swift     # URL extraction or paste
│   │
│   └── Storage/
│       ├── KeychainService.swift           # API key storage
│       └── SessionStorageService.swift     # SwiftData persistence
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── APIKeySetupView.swift
│   │
│   ├── SessionSetup/
│   │   ├── Views/
│   │   │   ├── SessionSetupView.swift      # Main setup screen
│   │   │   ├── ResumeInputView.swift       # PDF upload or paste
│   │   │   ├── JobDescriptionInputView.swift
│   │   │   ├── InterviewTypePickerView.swift
│   │   │   └── PreGenerationView.swift     # Shows Q&A bank generation progress
│   │   └── ViewModels/
│   │       └── SessionSetupViewModel.swift
│   │
│   ├── LiveSession/
│   │   ├── Views/
│   │   │   ├── LiveSessionView.swift       # Main interview screen
│   │   │   ├── TranscriptView.swift        # Top: what interviewer is saying
│   │   │   ├── ResponseView.swift          # Bottom: AI-generated answer
│   │   │   ├── SessionControlBar.swift     # Mute, read aloud, skip
│   │   │   ├── WaveformView.swift          # Audio level visualization
│   │   │   └── QuestionTypeBadge.swift     # [BEHAVIORAL] [TECHNICAL] tag
│   │   └── ViewModels/
│   │       └── LiveSessionViewModel.swift  # Orchestrates the full pipeline
│   │
│   ├── SessionReview/
│   │   ├── Views/
│   │   │   ├── SessionReviewView.swift
│   │   │   ├── ExchangeDetailView.swift
│   │   │   └── PerformanceView.swift
│   │   └── ViewModels/
│   │       └── SessionReviewViewModel.swift
│   │
│   ├── History/
│   │   ├── Views/
│   │   │   └── SessionHistoryView.swift
│   │   └── ViewModels/
│   │       └── SessionHistoryViewModel.swift
│   │
│   └── Settings/
│       ├── Views/
│       │   └── SettingsView.swift
│       └── ViewModels/
│           └── SettingsViewModel.swift
│
├── DesignSystem/
│   ├── Theme.swift                         # Colors, spacing, corner radii
│   ├── Typography.swift                    # iOS 26 type scale
│   ├── Animations.swift                    # Spring constants, durations
│   ├── GlassCard.swift                     # Liquid Glass card component
│   ├── AnimatedStatusBadge.swift           # Pulsing status indicators
│   ├── ShimmerModifier.swift               # Loading skeleton effect
│   ├── ConfettiView.swift                  # Celebration particles
│   ├── TypewriterText.swift                # Token-by-token text animation
│   └── PulsingDot.swift                    # Recording indicator
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings               # English + Spanish
```

---

## 3. CORE PIPELINE IMPLEMENTATION

### 3.1 Audio Capture (AudioCaptureService.swift)

```swift
import AVFoundation

@Observable
final class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0.0  // 0.0-1.0 for waveform display
    
    var onAudioBuffer: ((Data) -> Void)?
    
    // Target format for Deepgram: 16kHz, 16-bit PCM, mono
    private let targetSampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1600  // 100ms at 16kHz
    
    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [
            .allowBluetooth,
            .defaultToSpeaker,
            .mixWithOthers
        ])
        // Use measurement mode for cleanest capture of room audio
        // Don't use .voiceChat — it applies AGC that hurts far-field capture
        try session.setPreferredSampleRate(targetSampleRate)
        try session.setActive(true)
    }
    
    func startCapture() throws {
        try configureSession()
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap — convert to 16kHz PCM16 mono for Deepgram
        let converter = AVAudioConverter(
            from: inputFormat,
            to: AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: true
            )!
        )!
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }
            
            // Calculate audio level for waveform display
            let level = self.calculateRMS(buffer: buffer)
            Task { @MainActor in
                self.audioLevel = level
            }
            
            // Convert and send
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat,
                frameCapacity: AVAudioFrameCount(targetSampleRate * 0.1) // 100ms
            )!
            
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if let channelData = convertedBuffer.int16ChannelData {
                let data = Data(
                    bytes: channelData[0],
                    count: Int(convertedBuffer.frameLength) * 2  // 16-bit = 2 bytes
                )
                self.onAudioBuffer?(data)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isCapturing = true
    }
    
    func stopCapture() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false
    }
    
    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channelData[0][i]
            sum += sample * sample
        }
        return min(sqrt(sum / Float(frames)) * 3.0, 1.0)  // Scale for visibility
    }
}
```

### 3.2 Deepgram Streaming Transcription (DeepgramService.swift)

```swift
import Foundation

@Observable
final class DeepgramService {
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private(set) var isConnected = false
    
    // Callbacks
    var onPartialTranscript: ((String) -> Void)?    // Interim results (still speaking)
    var onFinalTranscript: ((String) -> Void)?       // Final results (utterance complete)
    var onSpeechStarted: (() -> Void)?
    var onSpeechEnded: (() -> Void)?
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func connect(keywords: [String] = []) async throws {
        // Build Deepgram streaming URL with parameters
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),          // Best model
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "smart_format", value: "true"),     // Punctuation, numbers
            URLQueryItem(name: "interim_results", value: "true"),  // Partial transcripts
            URLQueryItem(name: "utterance_end_ms", value: "1500"), // 1.5s silence = end
            URLQueryItem(name: "vad_events", value: "true"),       // Speech start/end events
            URLQueryItem(name: "encoding", value: "linear16"),     // PCM16
            URLQueryItem(name: "sample_rate", value: "16000"),     // 16kHz
            URLQueryItem(name: "channels", value: "1"),            // Mono
            URLQueryItem(name: "endpointing", value: "500"),       // 500ms endpoint detection
        ]
        
        // Add keyword boosting from job description
        for keyword in keywords.prefix(50) {  // Deepgram allows up to 50
            components.queryItems?.append(
                URLQueryItem(name: "keywords", value: "\(keyword):2.0")  // 2x boost
            )
        }
        
        var request = URLRequest(url: components.url!)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default)
        self.urlSession = session
        self.webSocket = session.webSocketTask(with: request)
        self.webSocket?.resume()
        self.isConnected = true
        
        // Start receiving messages
        Task { await receiveMessages() }
    }
    
    func sendAudio(_ data: Data) {
        guard isConnected else { return }
        webSocket?.send(.data(data)) { error in
            if let error {
                print("Deepgram send error: \(error)")
            }
        }
    }
    
    func disconnect() {
        // Send close message per Deepgram protocol
        let closeMessage = #"{"type": "CloseStream"}"#
        webSocket?.send(.string(closeMessage)) { [weak self] _ in
            self?.webSocket?.cancel(with: .normalClosure, reason: nil)
            self?.isConnected = false
        }
    }
    
    private func receiveMessages() async {
        guard let ws = webSocket else { return }
        
        do {
            while isConnected {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            isConnected = false
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        switch type {
        case "Results":
            // Parse transcript result
            guard let channel = (json["channel"] as? [String: Any]),
                  let alternatives = (channel["alternatives"] as? [[String: Any]]),
                  let first = alternatives.first,
                  let transcript = first["transcript"] as? String,
                  !transcript.isEmpty else { return }
            
            let isFinal = (json["is_final"] as? Bool) ?? false
            let speechFinal = (json["speech_final"] as? Bool) ?? false
            
            Task { @MainActor in
                if isFinal || speechFinal {
                    self.onFinalTranscript?(transcript)
                } else {
                    self.onPartialTranscript?(transcript)
                }
            }
            
        case "SpeechStarted":
            Task { @MainActor in self.onSpeechStarted?() }
            
        case "UtteranceEnd":
            Task { @MainActor in self.onSpeechEnded?() }
            
        default:
            break
        }
    }
}

// MARK: - Deepgram Response Models

struct DeepgramResponse: Codable {
    let type: String
    let channel: DeepgramChannel?
    let isFinal: Bool?
    let speechFinal: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type, channel
        case isFinal = "is_final"
        case speechFinal = "speech_final"
    }
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Double
    let words: [DeepgramWord]?
}

struct DeepgramWord: Codable {
    let word: String
    let start: Double
    let end: Double
    let confidence: Double
}
```

### 3.3 AI Response Generation (ResponseGeneratorService.swift)

```swift
import Foundation

@Observable
final class ResponseGeneratorService {
    private var currentTask: Task<Void, Never>?
    private(set) var isGenerating = false
    
    var onTokenReceived: ((String) -> Void)?
    var onResponseComplete: ((String) -> Void)?
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Generate a streaming response. Cancels any in-flight request.
    func generateResponse(
        question: String,
        resume: String,
        jobDescription: String,
        interviewType: String,
        format: ResponseFormat,
        model: String = "gpt-4.1-nano"  // Default: fastest + cheapest
    ) {
        // Cancel previous generation if still running
        currentTask?.cancel()
        
        let systemPrompt = buildSystemPrompt(
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            format: format
        )
        
        currentTask = Task { [weak self] in
            guard let self else { return }
            
            await MainActor.run { self.isGenerating = true }
            
            var fullResponse = ""
            
            do {
                // Build the request
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "model": model,
                    "stream": true,
                    "max_tokens": 800,  // Keep responses concise
                    "temperature": 0.7,
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": "Interview question: \"\(question)\"\n\nGenerate the ideal response."]
                    ]
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                // Stream the response using URLSession bytes
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                // Parse SSE stream
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    
                    guard line.hasPrefix("data: "),
                          line != "data: [DONE]" else { continue }
                    
                    let jsonString = String(line.dropFirst(6))
                    guard let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let delta = choices.first?["delta"] as? [String: Any],
                          let content = delta["content"] as? String else { continue }
                    
                    fullResponse += content
                    
                    await MainActor.run {
                        self.onTokenReceived?(content)
                    }
                }
                
                await MainActor.run {
                    self.onResponseComplete?(fullResponse)
                    self.isGenerating = false
                }
                
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { self.isGenerating = false }
                }
            }
        }
    }
    
    func cancelGeneration() {
        currentTask?.cancel()
        isGenerating = false
    }
    
    private func buildSystemPrompt(
        resume: String,
        jobDescription: String,
        interviewType: String,
        format: ResponseFormat
    ) -> String {
        let formatInstruction: String
        switch format {
        case .fullAnswer:
            formatInstruction = """
            Provide a complete, natural-sounding spoken response.
            Write exactly what the candidate should say, word for word.
            Keep it to 30-45 seconds when spoken aloud (roughly 80-120 words).
            """
        case .bulletPoints:
            formatInstruction = """
            Provide 3-5 bullet points with key talking points.
            Each bullet is a single concise sentence the candidate can reference.
            Use • as the bullet character.
            """
        case .hybrid:
            formatInstruction = """
            Provide a structured response with:
            - An opening sentence (say this verbatim)
            - 2-3 bullet points for the middle (key points to hit)
            - A closing sentence (say this verbatim)
            """
        }
        
        return """
        You are an expert interview coach generating real-time answer assistance.
        
        CANDIDATE'S RESUME:
        \(resume)
        
        JOB DESCRIPTION:
        \(jobDescription)
        
        INTERVIEW TYPE: \(interviewType)
        
        \(formatInstruction)
        
        CRITICAL RULES:
        1. Use STAR method for behavioral questions (Situation, Task, Action, Result)
        2. Reference SPECIFIC projects, metrics, and technologies from the resume
        3. Use first person ("I built...", "I led...", "My approach was...")
        4. Include 1-2 concrete numbers or outcomes per answer
        5. Sound confident and natural — not robotic or rehearsed
        6. Never say "As an AI" — you ARE the candidate
        7. For technical questions: approach → implementation → tradeoffs
        8. End with a natural transition or question back to the interviewer
        9. DO NOT repeat the question back — go straight to the answer
        10. Be concise. Interviewers respect candidates who don't ramble.
        """
    }
}
```

### 3.4 The Orchestrator (LiveSessionViewModel.swift)

This is the brain — it wires audio capture → Deepgram → question detection → response generation.

```swift
import SwiftUI
import Observation

@Observable
final class LiveSessionViewModel {
    // Services
    private let audioCapture: AudioCaptureService
    private let deepgram: DeepgramService
    private let responseGenerator: ResponseGeneratorService
    private let answerBank: AnswerBankService
    private let classifier: QuestionClassifierService
    
    // State
    var sessionState: SessionState = .idle
    var interviewerTranscript: String = ""              // What they're saying now
    var fullTranscript: [TranscriptSegment] = []        // Complete history
    var currentResponse: String = ""                    // AI response text
    var responseTokens: [String] = []                   // For typewriter animation
    var questionType: QuestionClassification?
    var audioLevel: Float = 0.0
    var elapsedTime: TimeInterval = 0
    var exchangeCount: Int = 0
    var isResponseFromCache: Bool = false
    
    // Session config
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let responseFormat: ResponseFormat
    let preComputedAnswers: [PreComputedAnswer]
    
    // Private state
    private var accumulatedTranscript: String = ""
    private var hasFiredResponse: Bool = false
    private var sessionStartTime: Date?
    private var timer: Timer?
    private var currentExchangeStart: Date?
    
    // Thresholds
    private let predictiveFireWordCount = 8         // Fire after 8+ words
    private let similarityThreshold: Float = 0.82   // Cache hit threshold
    
    enum SessionState {
        case idle
        case listening           // Mic active, waiting for speech
        case interviewerSpeaking // Deepgram detecting speech
        case generating          // AI generating response
        case responseReady       // Full response displayed
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
            self?.deepgram.sendAudio(data)
        }
        
        // Deepgram → Transcript display
        deepgram.onPartialTranscript = { [weak self] text in
            guard let self else { return }
            self.interviewerTranscript = text
            self.checkForPredictiveFire(partialText: text)
        }
        
        deepgram.onFinalTranscript = { [weak self] text in
            guard let self else { return }
            self.accumulatedTranscript += " " + text
            self.accumulatedTranscript = self.accumulatedTranscript
                .trimmingCharacters(in: .whitespaces)
            self.interviewerTranscript = self.accumulatedTranscript
        }
        
        deepgram.onSpeechStarted = { [weak self] in
            guard let self else { return }
            if self.sessionState == .responseReady || self.sessionState == .listening {
                // New question starting — reset
                self.resetForNewQuestion()
            }
            self.sessionState = .interviewerSpeaking
        }
        
        deepgram.onSpeechEnded = { [weak self] in
            guard let self else { return }
            // Interviewer stopped — fire response if we haven't already
            if !self.hasFiredResponse && !self.accumulatedTranscript.isEmpty {
                self.fireResponse(question: self.accumulatedTranscript)
            }
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
        }
        
        // Audio level for waveform
        // Updated via audioCapture.audioLevel (Observable)
    }
    
    // MARK: - Session Control
    
    func startSession() async throws {
        // Extract keywords from job description for Deepgram boosting
        let keywords = extractKeywords(from: jobDescription)
        
        try await deepgram.connect(keywords: keywords)
        try audioCapture.startCapture()
        
        sessionStartTime = Date()
        sessionState = .listening
        
        // Start elapsed time timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }
    
    func stopSession() {
        audioCapture.stopCapture()
        deepgram.disconnect()
        responseGenerator.cancelGeneration()
        timer?.invalidate()
        sessionState = .idle
    }
    
    // MARK: - Predictive Fire Logic
    
    private func checkForPredictiveFire(partialText: String) {
        guard !hasFiredResponse else { return }
        
        let wordCount = partialText.split(separator: " ").count
        
        // Don't fire too early
        guard wordCount >= predictiveFireWordCount else { return }
        
        // Check answer bank first (fastest path)
        if let cachedAnswer = answerBank.findMatch(
            query: partialText,
            threshold: similarityThreshold
        ) {
            hasFiredResponse = true
            isResponseFromCache = true
            sessionState = .generating
            currentExchangeStart = Date()
            
            // Display cached answer with typewriter effect
            displayCachedAnswer(cachedAnswer)
            
            // Background: refine with full question when available
            // (handled when onSpeechEnded fires)
            return
        }
        
        // Classify question type
        let classification = classifier.classify(partialText)
        self.questionType = classification
        
        // Fire if we have enough confidence
        if classification.confidence > 0.75 && wordCount >= 10 {
            fireResponse(question: partialText)
        }
    }
    
    private func fireResponse(question: String) {
        guard !hasFiredResponse else { return }
        hasFiredResponse = true
        isResponseFromCache = false
        sessionState = .generating
        currentExchangeStart = currentExchangeStart ?? Date()
        
        // Select model based on question type
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
            return "gpt-4.1-mini"   // Better reasoning
        case .coding:
            return "o4-mini"        // Reasoning model for code
        default:
            return "gpt-4.1-nano"   // Fastest for behavioral/general
        }
    }
    
    private func resetForNewQuestion() {
        accumulatedTranscript = ""
        interviewerTranscript = ""
        currentResponse = ""
        responseTokens = []
        questionType = nil
        hasFiredResponse = false
        isResponseFromCache = false
        currentExchangeStart = nil
        responseGenerator.cancelGeneration()
    }
    
    private func displayCachedAnswer(_ answer: PreComputedAnswer) {
        // Simulate typewriter effect for cached answer
        let words = answer.response.split(separator: " ").map(String.init)
        Task {
            for (index, word) in words.enumerated() {
                if Task.isCancelled { break }
                let token = (index == 0 ? "" : " ") + word
                await MainActor.run {
                    self.currentResponse += token
                    self.responseTokens.append(token)
                }
                try? await Task.sleep(for: .milliseconds(20))  // Fast typewriter
            }
            await MainActor.run {
                self.sessionState = .responseReady
                self.exchangeCount += 1
            }
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Extract technical terms, tools, frameworks from job description
        // for Deepgram keyword boosting
        let techPatterns = [
            "React", "Node", "TypeScript", "JavaScript", "Python", "AWS",
            "Docker", "Kubernetes", "PostgreSQL", "MongoDB", "Redis",
            "GraphQL", "REST", "CI/CD", "Terraform", "Swift", "SwiftUI"
            // Expand based on job description content
        ]
        return techPatterns.filter { text.localizedCaseInsensitiveContains($0) }
    }
}
```

---

## 4. iOS 26 UI IMPLEMENTATION

### 4.1 Design System

```swift
// Theme.swift

import SwiftUI

enum IPTheme {
    // MARK: - Colors
    
    static let brand = Color(hex: "6366F1")         // Indigo 500
    static let brandLight = Color(hex: "818CF8")     // Indigo 400
    static let brandDark = Color(hex: "4338CA")      // Indigo 700
    
    static let interviewerBg = Color(hex: "1E293B")  // Slate 800
    static let responseBg = Color(hex: "0F172A")     // Slate 900
    
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let live = Color.red
    
    // Question type badge colors
    static func questionTypeColor(_ type: QuestionType) -> Color {
        switch type {
        case .behavioral:   return .blue
        case .technical:    return .purple
        case .systemDesign: return .orange
        case .coding:       return .green
        case .situational:  return .cyan
        case .background:   return .gray
        case .curveball:    return .pink
        case .followUp:     return .yellow
        case .unknown:      return .gray
        }
    }
    
    // MARK: - Spacing
    
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    
    // MARK: - Corner Radii
    
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 24
    static let radiusXL: CGFloat = 32
}

// Typography.swift

enum IPTypography {
    // Display — Timer, big numbers
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
        .monospacedDigit()
    
    // Headings
    static let headlineLarge = Font.system(.title, design: .default, weight: .bold)
    static let headlineMedium = Font.system(.title2, design: .default, weight: .semibold)
    static let headlineSmall = Font.system(.title3, design: .default, weight: .semibold)
    
    // Body — Transcript and response text
    static let bodyLarge = Font.system(.body, design: .default, weight: .regular)
    static let bodyMedium = Font.system(.callout, design: .default, weight: .regular)
    
    // Response text — slightly larger for readability at a glance
    static let responseText = Font.system(size: 18, weight: .medium, design: .default)
    
    // Labels
    static let labelMedium = Font.system(.footnote, design: .default, weight: .medium)
    static let labelSmall = Font.system(.caption, design: .default, weight: .medium)
    
    // Timer
    static let timer = Font.system(size: 14, weight: .medium, design: .monospaced)
}

// Animations.swift

enum IPAnimations {
    // Standard spring for most transitions
    static let standard = Animation.spring(duration: 0.4, bounce: 0.2)
    
    // Snappy for button presses and quick feedback
    static let snappy = Animation.spring(duration: 0.25, bounce: 0.3)
    
    // Gentle for sheets and overlays
    static let gentle = Animation.spring(duration: 0.5, bounce: 0.1)
    
    // Typewriter token appearance
    static let tokenAppear = Animation.spring(duration: 0.2, bounce: 0.15)
    
    // Pulse for recording indicator
    static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    
    // Waveform
    static let waveform = Animation.linear(duration: 0.1)
}
```

### 4.2 Main Live Session Screen

```swift
// LiveSessionView.swift

import SwiftUI

struct LiveSessionView: View {
    @State var viewModel: LiveSessionViewModel
    @State private var showSettings = false
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "1E1B4B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Top Bar
                topBar
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.top, IPTheme.spacing8)
                
                // MARK: - Interviewer Transcript (Top Half)
                transcriptSection
                    .frame(maxHeight: .infinity)
                
                // MARK: - Divider with question type badge
                divider
                
                // MARK: - AI Response (Bottom Half)
                responseSection
                    .frame(maxHeight: .infinity)
                
                // MARK: - Control Bar
                controlBar
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.bottom, IPTheme.spacing8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { try? await viewModel.startSession() }
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { viewModel.stopSession() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Live indicator
            HStack(spacing: 6) {
                PulsingDot(color: IPTheme.live)
                    .frame(width: 8, height: 8)
                
                Text("LIVE")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.live)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            
            Spacer()
            
            // Timer
            Text(formatTime(viewModel.elapsedTime))
                .font(IPTypography.timer)
                .foregroundStyle(.white.opacity(0.6))
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.3), value: viewModel.elapsedTime)
        }
    }
    
    // MARK: - Transcript Section
    
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(IPTheme.brandLight)
                    .symbolEffect(
                        .variableColor.iterative,
                        isActive: viewModel.sessionState == .interviewerSpeaking
                    )
                
                Text("INTERVIEWER")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)
            }
            .padding(.horizontal, IPTheme.spacing20)
            .padding(.top, IPTheme.spacing16)
            
            // Transcript text
            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.interviewerTranscript.isEmpty
                         ? "Listening..."
                         : viewModel.interviewerTranscript)
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(viewModel.interviewerTranscript.isEmpty
                                        ? .white.opacity(0.3) : .white.opacity(0.9))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IPTheme.spacing20)
                        .id("transcript-bottom")
                        .animation(IPAnimations.tokenAppear, value: viewModel.interviewerTranscript)
                }
                .onChange(of: viewModel.interviewerTranscript) {
                    withAnimation(IPAnimations.gentle) {
                        proxy.scrollTo("transcript-bottom", anchor: .bottom)
                    }
                }
            }
            
            // Waveform visualization
            if viewModel.sessionState == .interviewerSpeaking || viewModel.sessionState == .listening {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 30)
                    .padding(.horizontal, IPTheme.spacing20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: IPTheme.radiusLarge)
                .fill(.ultraThinMaterial)
                .padding(.horizontal, IPTheme.spacing8)
        )
        .padding(.horizontal, IPTheme.spacing8)
        .padding(.top, IPTheme.spacing8)
    }
    
    // MARK: - Divider
    
    private var divider: some View {
        HStack {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
            
            if let questionType = viewModel.questionType {
                QuestionTypeBadge(classification: questionType)
                    .transition(.scale.combined(with: .opacity))
            }
            
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.horizontal, IPTheme.spacing20)
        .padding(.vertical, IPTheme.spacing4)
        .animation(IPAnimations.snappy, value: viewModel.questionType?.type)
    }
    
    // MARK: - Response Section
    
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: viewModel.isResponseFromCache ? "bolt.fill" : "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: viewModel.sessionState == .responseReady)
                
                Text("YOUR ANSWER")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)
                
                if viewModel.isResponseFromCache {
                    Text("INSTANT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                if viewModel.responseGenerator.isGenerating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(IPTheme.brandLight)
                }
            }
            .padding(.horizontal, IPTheme.spacing20)
            .padding(.top, IPTheme.spacing12)
            
            // Response text with typewriter effect
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.currentResponse.isEmpty && viewModel.sessionState != .generating {
                        Text("Response will appear here...")
                            .font(IPTypography.responseText)
                            .foregroundStyle(.white.opacity(0.2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, IPTheme.spacing20)
                    } else if viewModel.currentResponse.isEmpty && viewModel.sessionState == .generating {
                        // Shimmer loading state
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white.opacity(0.08))
                                    .frame(height: 16)
                                    .frame(maxWidth: i == 2 ? 200 : .infinity)
                                    .modifier(ShimmerModifier())
                            }
                        }
                        .padding(.horizontal, IPTheme.spacing20)
                        .transition(.opacity)
                    } else {
                        Text(viewModel.currentResponse)
                            .font(IPTypography.responseText)
                            .foregroundStyle(.white)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, IPTheme.spacing20)
                            .id("response-bottom")
                            .contentTransition(.numericText())
                    }
                }
                .onChange(of: viewModel.currentResponse) {
                    withAnimation(IPAnimations.gentle) {
                        proxy.scrollTo("response-bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: IPTheme.radiusLarge)
                .fill(.regularMaterial)
                .padding(.horizontal, IPTheme.spacing8)
        )
        .padding(.horizontal, IPTheme.spacing8)
        .padding(.bottom, IPTheme.spacing8)
    }
    
    // MARK: - Control Bar
    
    private var controlBar: some View {
        HStack(spacing: IPTheme.spacing24) {
            // Mute button
            ControlButton(
                icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
                label: viewModel.audioCapture.isCapturing ? "Mute" : "Unmute",
                isActive: viewModel.audioCapture.isCapturing
            ) {
                if viewModel.audioCapture.isCapturing {
                    viewModel.audioCapture.stopCapture()
                } else {
                    try? viewModel.audioCapture.startCapture()
                }
            }
            
            Spacer()
            
            // End session button
            Button(action: { viewModel.stopSession() }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(IPTheme.error.gradient, in: Circle())
                    .shadow(color: IPTheme.error.opacity(0.4), radius: 8, y: 4)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: false)
            
            Spacer()
            
            // Skip / Next question
            ControlButton(
                icon: "forward.fill",
                label: "Next",
                isActive: true
            ) {
                viewModel.resetForNewQuestion()
            }
        }
        .padding(.vertical, IPTheme.spacing12)
        .padding(.horizontal, IPTheme.spacing24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusXL))
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Components

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                    .symbolEffect(.bounce, value: isPressed)
                
                Text(label)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .onTapGesture { isPressed.toggle() }
    }
}

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(IPAnimations.pulse, value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

struct QuestionTypeBadge: View {
    let classification: QuestionClassification
    
    var body: some View {
        Text(classification.type.displayName.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                IPTheme.questionTypeColor(classification.type).opacity(0.8),
                in: Capsule()
            )
    }
}

struct WaveformView: View {
    let level: Float
    private let barCount = 30
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(IPTheme.brandLight.opacity(0.6))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(
                        .spring(duration: 0.15).delay(Double(i) * 0.01),
                        value: level
                    )
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let normalized = CGFloat(level)
        let randomFactor = CGFloat.random(in: 0.3...1.0)
        let centerBias = 1.0 - abs(CGFloat(index) - CGFloat(barCount) / 2) / (CGFloat(barCount) / 2)
        return max(3, min(28, normalized * 28 * randomFactor * (0.5 + centerBias * 0.5)))
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}
```

### 4.3 Session Setup Screen

```swift
// SessionSetupView.swift

import SwiftUI

struct SessionSetupView: View {
    @State private var viewModel = SessionSetupViewModel()
    @State private var showLiveSession = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "0F172A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: IPTheme.spacing24) {
                        // Header
                        VStack(spacing: IPTheme.spacing8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundStyle(IPTheme.brand.gradient)
                                .symbolEffect(.breathe.pulse)
                            
                            Text("Interview Prep")
                                .font(IPTypography.headlineLarge)
                                .foregroundStyle(.white)
                            
                            Text("Upload your resume and job description to get started")
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, IPTheme.spacing24)
                        
                        // Resume input card
                        SetupCard(
                            icon: "doc.text.fill",
                            title: "Resume",
                            subtitle: viewModel.hasResume ? "Uploaded" : "PDF or paste text"
                        ) {
                            if viewModel.hasResume {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(IPTheme.success)
                                    Text("Resume loaded")
                                        .font(IPTypography.bodyMedium)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    Button("Change") { viewModel.showResumeInput = true }
                                        .font(IPTypography.labelMedium)
                                        .foregroundStyle(IPTheme.brandLight)
                                }
                            } else {
                                Button(action: { viewModel.showResumeInput = true }) {
                                    Label("Add Resume", systemImage: "plus.circle.fill")
                                        .font(IPTypography.bodyMedium)
                                        .foregroundStyle(IPTheme.brandLight)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, IPTheme.spacing12)
                                        .background(IPTheme.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                                }
                            }
                        }
                        
                        // Job description input card
                        SetupCard(
                            icon: "briefcase.fill",
                            title: "Job Description",
                            subtitle: viewModel.hasJobDescription ? "Added" : "Paste or enter URL"
                        ) {
                            TextEditor(text: $viewModel.jobDescription)
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100, maxHeight: 200)
                                .padding(IPTheme.spacing8)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                        }
                        
                        // Interview type picker
                        SetupCard(
                            icon: "target",
                            title: "Interview Type",
                            subtitle: viewModel.interviewType.displayName
                        ) {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: IPTheme.spacing8) {
                                ForEach(InterviewType.allCases, id: \.self) { type in
                                    Button(action: {
                                        withAnimation(IPAnimations.snappy) {
                                            viewModel.interviewType = type
                                        }
                                    }) {
                                        Text(type.displayName)
                                            .font(IPTypography.labelMedium)
                                            .foregroundStyle(viewModel.interviewType == type ? .white : .white.opacity(0.5))
                                            .padding(.vertical, IPTheme.spacing8)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                viewModel.interviewType == type
                                                    ? IPTheme.brand.opacity(0.8)
                                                    : Color.white.opacity(0.05),
                                                in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall)
                                            )
                                    }
                                    .sensoryFeedback(.selection, trigger: viewModel.interviewType)
                                }
                            }
                        }
                        
                        // Response format picker
                        SetupCard(
                            icon: "text.alignleft",
                            title: "Response Format",
                            subtitle: "How answers appear on screen"
                        ) {
                            VStack(spacing: IPTheme.spacing8) {
                                ForEach(ResponseFormat.allCases, id: \.self) { format in
                                    Button(action: {
                                        withAnimation(IPAnimations.snappy) {
                                            viewModel.responseFormat = format
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: viewModel.responseFormat == format
                                                  ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(viewModel.responseFormat == format
                                                                ? IPTheme.brand : .white.opacity(0.3))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(format.displayName)
                                                    .font(IPTypography.bodyMedium)
                                                    .foregroundStyle(.white)
                                                Text(format.description)
                                                    .font(IPTypography.labelSmall)
                                                    .foregroundStyle(.white.opacity(0.4))
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(IPTheme.spacing12)
                                        .background(
                                            viewModel.responseFormat == format
                                                ? IPTheme.brand.opacity(0.1)
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall)
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Start button
                        Button(action: {
                            Task {
                                await viewModel.prepareSession()
                                showLiveSession = true
                            }
                        }) {
                            HStack(spacing: IPTheme.spacing8) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 18))
                                Text("Start Interview Session")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                viewModel.isReady
                                    ? IPTheme.brand.gradient
                                    : AnyGradient(Gradient(colors: [.gray.opacity(0.3)])),
                                in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium)
                            )
                            .shadow(color: viewModel.isReady ? IPTheme.brand.opacity(0.4) : .clear, radius: 12, y: 6)
                        }
                        .disabled(!viewModel.isReady)
                        .sensoryFeedback(.impact(weight: .heavy), trigger: showLiveSession)
                        .padding(.top, IPTheme.spacing8)
                        
                        // Pre-generation toggle
                        if viewModel.isReady {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                                Text("Pre-generate likely questions?")
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Toggle("", isOn: $viewModel.shouldPreGenerate)
                                    .tint(IPTheme.brand)
                            }
                            .padding(IPTheme.spacing16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.bottom, IPTheme.spacing24)
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: $showLiveSession) {
                LiveSessionView(viewModel: viewModel.createLiveViewModel())
            }
        }
    }
}

struct SetupCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            // Header
            Button(action: {
                withAnimation(IPAnimations.standard) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: IPTheme.spacing12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(IPTheme.brandLight)
                        .frame(width: 32, height: 32)
                        .background(IPTheme.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(IPTypography.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(IPTypography.labelSmall)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            
            // Content
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusLarge))
    }
}
```

---

## 5. DATA MODELS

```swift
// InterviewSession.swift
import SwiftData

@Model
final class InterviewSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var resumeText: String
    var jobDescription: String
    var interviewType: String         // InterviewType.rawValue
    var responseFormat: String        // ResponseFormat.rawValue
    var modelUsed: String
    var exchangesJSON: Data?          // [Exchange] encoded
    var totalTokensUsed: Int
    var estimatedCost: Double
    
    init(resumeText: String, jobDescription: String, interviewType: InterviewType, responseFormat: ResponseFormat) {
        self.id = UUID()
        self.startedAt = Date()
        self.resumeText = resumeText
        self.jobDescription = jobDescription
        self.interviewType = interviewType.rawValue
        self.responseFormat = responseFormat.rawValue
        self.modelUsed = "gpt-4.1-nano"
        self.totalTokensUsed = 0
        self.estimatedCost = 0
    }
}

// Exchange.swift

struct Exchange: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var questionTranscript: String
    var questionType: String
    var generatedResponse: String
    var responseLatencyMs: Int
    var wasPreComputed: Bool
    
    init(question: String, response: String, type: QuestionType, latencyMs: Int, cached: Bool) {
        self.id = UUID()
        self.timestamp = Date()
        self.questionTranscript = question
        self.questionType = type.rawValue
        self.generatedResponse = response
        self.responseLatencyMs = latencyMs
        self.wasPreComputed = cached
    }
}

// TranscriptSegment.swift

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let speaker: Speaker
    let text: String
    let timestamp: Date
    
    enum Speaker: String, Codable {
        case interviewer
        case aiResponse
        case user
    }
    
    init(speaker: Speaker, text: String, timestamp: Date) {
        self.id = UUID()
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
    }
}

// PreComputedAnswer.swift

struct PreComputedAnswer: Identifiable, Codable {
    let id: UUID
    let question: String
    let response: String
    let questionType: QuestionType
    let embedding: [Float]?  // For similarity matching
    
    init(question: String, response: String, type: QuestionType, embedding: [Float]? = nil) {
        self.id = UUID()
        self.question = question
        self.response = response
        self.questionType = type
        self.embedding = embedding
    }
}

// Enums

enum InterviewType: String, Codable, CaseIterable {
    case behavioral, technical, systemDesign, caseStudy, hrScreen, general
    
    var displayName: String {
        switch self {
        case .behavioral:   return "Behavioral"
        case .technical:    return "Technical"
        case .systemDesign: return "System Design"
        case .caseStudy:    return "Case Study"
        case .hrScreen:     return "HR Screen"
        case .general:      return "General"
        }
    }
}

enum ResponseFormat: String, Codable, CaseIterable {
    case fullAnswer, bulletPoints, hybrid
    
    var displayName: String {
        switch self {
        case .fullAnswer:    return "Full Answers"
        case .bulletPoints:  return "Bullet Points"
        case .hybrid:        return "Hybrid"
        }
    }
    
    var description: String {
        switch self {
        case .fullAnswer:    return "Complete spoken response, word for word"
        case .bulletPoints:  return "Key talking points to reference"
        case .hybrid:        return "Opening + bullet points + closing"
        }
    }
}

enum QuestionType: String, Codable {
    case behavioral, technical, systemDesign, coding
    case situational, background, curveball, followUp, unknown
    
    var displayName: String {
        switch self {
        case .behavioral:   return "Behavioral"
        case .technical:    return "Technical"
        case .systemDesign: return "System Design"
        case .coding:       return "Coding"
        case .situational:  return "Situational"
        case .background:   return "Background"
        case .curveball:    return "Curveball"
        case .followUp:     return "Follow-Up"
        case .unknown:      return "General"
        }
    }
}

struct QuestionClassification {
    let type: QuestionType
    let confidence: Float  // 0.0-1.0
}
```

---

## 6. API KEYS & CONFIGURATION

```swift
// Constants.swift

enum APIConfig {
    // Models
    static let defaultResponseModel = "gpt-4.1-nano"
    static let technicalResponseModel = "gpt-4.1-mini"
    static let codingResponseModel = "o4-mini"
    static let prepModel = "gpt-4.1"
    
    // Deepgram
    static let deepgramModel = "nova-3"
    static let deepgramSampleRate = 16000
    static let deepgramEncoding = "linear16"
    
    // Thresholds
    static let predictiveFireMinWords = 8
    static let predictiveFireConfidence: Float = 0.75
    static let cacheMatchThreshold: Float = 0.82
    static let utteranceEndMs = 1500
    static let endpointingMs = 500
    
    // Limits
    static let maxResponseTokens = 800
    static let maxPreComputedQuestions = 25
    static let responseTemperature = 0.7
}
```

The app requires two API keys entered by the user in Settings:
1. **Deepgram API key** — free tier gives 45,000 minutes/year
2. **OpenAI API key** — pay-as-you-go, ~$0.30 per interview

Store both in iOS Keychain via `KeychainService.swift`. Never persist in UserDefaults or files.

---

## 7. BUILD & RUN

```
Xcode 17+ (iOS 26 SDK)
Target: iPhone, iOS 26.0+
No CocoaPods/SPM dependencies required — all APIs are WebSocket/REST based
Capabilities required: Microphone
```

Info.plist keys:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Job Hopper needs microphone access to hear and transcribe the interviewer's questions in real-time.</string>
```

---

## 8. IMPLEMENTATION ORDER

Build in this exact order. Each step should compile and run before moving to the next.

1. **Project skeleton** — Create Xcode project, folder structure, all placeholder files
2. **Design system** — Theme, Typography, Animations, GlassCard, ShimmerModifier
3. **Session setup UI** — SessionSetupView with resume paste, job desc paste, type picker
4. **Audio capture** — AudioCaptureService with mic permissions and level metering
5. **Deepgram integration** — DeepgramService WebSocket streaming with transcript display
6. **Live session UI** — LiveSessionView showing real-time transcript + placeholder response
7. **OpenAI response generation** — ResponseGeneratorService with streaming text
8. **Pipeline orchestration** — LiveSessionViewModel wiring everything together
9. **Predictive fire logic** — Question classification + early trigger
10. **Pre-computed answer bank** — Pre-session Q&A generation + similarity matching
11. **Session storage** — SwiftData persistence for session history
12. **Session review** — Post-session transcript and exchange review
13. **Settings** — API key management, model selection, format preferences
14. **Polish** — Animations, haptics, edge cases, error handling
