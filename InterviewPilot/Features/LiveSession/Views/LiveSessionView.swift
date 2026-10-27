import SwiftUI
import UIKit

struct LiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: LiveSessionViewModel
    @State private var question = ""
    @State private var showingTranscript = false
    @State private var closing = false
    @State private var confirmCloseWithoutSave = false

    init(configuration: InterviewConfiguration, store: LocalInterviewStore) {
        _model = State(initialValue: LiveSessionViewModel(configuration: configuration, store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    status
                    contextCard
                    if let notice = model.notice {
                        Label(notice, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("sessionNotice")
                    }
                    if let error = model.saveError {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            ShareLink(item: model.transcriptText) { Label("Export transcript", systemImage: "square.and.arrow.up") }
                        }
                    }
                    answerCard
                    controls
                    typedQuestion
                    if !model.messages.isEmpty {
                        DisclosureGroup("Conversation (\(model.messages.count) messages)", isExpanded: $showingTranscript) {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(model.messages) { message in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.role == .user ? "INPUT" : (model.configuration.mode == .practice ? "INTERVIEWER" : "SUGGESTION"))
                                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                        Text(message.content).textSelection(.enabled)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }.padding(.top, 12)
                        }
                    }
                    Text("Audio comes from this device’s microphone. Place it where it can hear the interviewer. In assist mode, mute the mic while you answer to avoid treating your speech as another question.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(model.configuration.mode == .practice ? "Practice interview" : "Live interview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { Task { await close() } }.disabled(closing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: model.transcriptText) { Image(systemName: "square.and.arrow.up") }
                        .disabled(model.messages.isEmpty)
                }
            }
            .task { await model.start() }
            .onChange(of: model.rejectedQuestion) { _, text in
                if !text.isEmpty { question = text; model.rejectedQuestion = "" }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.pause(reason: "Session paused while the app is in the background. Resume when ready.") }
            }
            .onDisappear { model.pause() }
            .confirmationDialog("The transcript has not been saved. Export it before closing.", isPresented: $confirmCloseWithoutSave, titleVisibility: .visible) {
                Button("Keep session open", role: .cancel) {}
                Button("Close without saving", role: .destructive) { dismiss() }
            }
        }
        .interactiveDismissDisabled()
    }

    private var status: some View {
        HStack {
            Circle().fill(model.audio.isCapturing ? Color.green : Color.orange).frame(width: 9, height: 9)
            Text(model.connectionLabel).font(.subheadline.weight(.semibold))
            Spacer()
            Text(Duration.seconds(model.elapsedSeconds).formatted(.time(pattern: .minuteSecond)))
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("connectionStatus")
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.configuration.role.isEmpty ? "Interview context" : model.configuration.role)
                .font(.headline)
            if !model.configuration.company.isEmpty { Text(model.configuration.company).foregroundStyle(.secondary) }
            HStack(spacing: 16) {
                Label(model.configuration.resume.isEmpty ? "No resume" : "Resume included", systemImage: "doc.text")
                Label(model.configuration.jobDescription.isEmpty ? "No job description" : "Role context included", systemImage: "briefcase")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.configuration.mode == .practice ? "INTERVIEWER" : "YOUR RESPONSE")
                    .font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                if model.isThinking { ProgressView().controlSize(.small).accessibilityLabel("Generating response") }
            }
            if !model.latestQuestion.isEmpty {
                Text(model.latestQuestion).font(.subheadline).foregroundStyle(.secondary).lineLimit(5)
            }
            Text(model.latestAnswer.isEmpty
                 ? "Your response will appear here as soon as Deepgram returns it."
                 : model.latestAnswer)
                .font(.title3).lineSpacing(5).textSelection(.enabled)
                .foregroundStyle(model.latestAnswer.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                .accessibilityIdentifier("latestAnswer")
            if let latency = model.currentResponseLatencyMS {
                Text(String(format: "First text: %.2f s after the confirmed input", latency / 1_000))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if model.isRunning {
                HStack {
                    Button {
                        Task { await model.setMicrophoneEnabled(!model.microphoneEnabled) }
                    } label: {
                        Label(model.microphoneEnabled ? "Mute mic" : "Enable mic",
                              systemImage: model.microphoneEnabled ? "mic.slash" : "mic")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.isReady)
                    Button { model.pause(reason: "Paused. Resume keeps your interview context.") } label: {
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                }
                Button("Answer now") { Task { await model.answerNow() } }
                    .disabled(!model.isReady || model.isThinking)
                ProgressView(value: Double(model.audio.audioLevel), total: 1)
                    .tint(.green).accessibilityLabel("Microphone input level")
            } else {
                HStack {
                    Button { Task { await model.start(useMicrophone: true) } } label: {
                        Label("Resume listening", systemImage: "mic.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                    Button { Task { await model.start(useMicrophone: false) } } label: {
                        Text("Text only").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                }.disabled(model.isStarting)
            }
        }
    }

    private var typedQuestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.configuration.mode == .practice ? "Type your answer or request feedback" : "Type a question")
                .font(.subheadline.weight(.semibold))
            TextField("Enter text…", text: $question, axis: .vertical)
                .lineLimit(2...6).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("manualQuestion")
            Button {
                let submitted = question
                Task {
                    if await model.sendQuestion(submitted), question == submitted { question = "" }
                }
            } label: {
                Label("Send", systemImage: "arrow.up.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!model.isReady || model.isThinking || model.userIsSpeaking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func close() async {
        closing = true
        await model.finish()
        closing = false
        if model.saveError != nil { confirmCloseWithoutSave = true }
        else { dismiss() }
    }
}
