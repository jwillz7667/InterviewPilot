import Foundation
import XCTest
@testable import InterviewPilotCore

final class DeepgramProtocolTests: XCTestCase, @unchecked Sendable {
    func testSettingsUseOnlyDeepgramManagedModelsAndPCM() throws {
        let text = try DeepgramProtocol.settings(prompt: "Candidate facts", history: [
            .init(role: .user, content: "Tell me about a project."),
            .init(role: .assistant, content: "I built a delivery application.")
        ])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let audio = try XCTUnwrap(root["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        XCTAssertEqual(input["encoding"] as? String, "linear16")
        XCTAssertEqual(input["sample_rate"] as? Int, 16_000)
        XCTAssertEqual(root["mip_opt_out"] as? Bool, true)
        let agent = try XCTUnwrap(root["agent"] as? [String: Any])
        XCTAssertNil(agent["greeting"], "Do not speak an unsolicited greeting at interview start")
        let think = try XCTUnwrap(agent["think"] as? [[String: Any]])
        XCTAssertEqual(think.count, 2)
        for provider in think {
            XCTAssertNil(provider["endpoint"], "Custom endpoints would require another provider key")
            XCTAssertEqual(provider["prompt"] as? String, "Candidate facts")
        }
        let context = try XCTUnwrap(agent["context"] as? [String: Any])
        let messages = try XCTUnwrap(context["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["type"] }, ["History", "History"])
        XCTAssertEqual(messages.map { $0["role"] }, ["user", "assistant"])
        XCTAssertFalse(text.contains("Authorization"))
        XCTAssertFalse(text.contains("api_key"))
    }

    func testPromptLimitRejectsRatherThanSilentlyRemovingCandidateFacts() {
        XCTAssertThrowsError(try DeepgramProtocol.settings(prompt: String(repeating: "a", count: 25_001), history: [])) {
            XCTAssertEqual($0 as? AgentClientError, .promptTooLong)
        }
        XCTAssertThrowsError(try DeepgramProtocol.settings(prompt: " \n ", history: [])) {
            XCTAssertEqual($0 as? AgentClientError, .emptyPrompt)
        }
    }

    func testHistoryKeepsRecentMessagesInOrderWithinMemoryBudget() {
        let original = (0..<80).map { index in
            AgentHistoryMessage(role: index.isMultiple(of: 2) ? .user : .assistant,
                                content: "Turn \(index) " + String(repeating: "x", count: 2_000))
        }
        let bounded = DeepgramProtocol.boundedHistory(original)
        XCTAssertLessThanOrEqual(bounded.count, DeepgramProtocol.maximumHistoryMessages)
        XCTAssertLessThanOrEqual(bounded.reduce(0) { $0 + $1.content.count }, DeepgramProtocol.maximumHistoryCharacters)
        XCTAssertTrue(bounded.last?.content.hasPrefix("Turn 79 ") == true)
        XCTAssertFalse(bounded.contains { $0.content.hasPrefix("Turn 0 ") })
        XCTAssertEqual(bounded.map(\.role).last, .assistant)
    }

    func testInjectionEscapesTextAndRejectsEmptyOrOversizedQuestion() throws {
        let input = "Explain \"quoted\" input\nwith a newline."
        let payload = try DeepgramProtocol.injectUser(input)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: String])
        XCTAssertEqual(object["type"], "InjectUserMessage")
        XCTAssertEqual(object["content"], input)
        XCTAssertThrowsError(try DeepgramProtocol.injectUser(" \n"))
        XCTAssertThrowsError(try DeepgramProtocol.injectUser(String(repeating: "x", count: 8_001)))
    }

    func testServerConversationAndHandshakeEvents() throws {
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"Welcome","request_id":"example"}"#), .welcome)
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"SettingsApplied"}"#), .settingsApplied)
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"ConversationText","role":"user","content":"Why this role?"}"#), .event(.userTranscript("Why this role?")))
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"ConversationText","role":"assistant","content":"It matches my experience."}"#), .event(.assistantText("It matches my experience.")))
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"UserStartedSpeaking"}"#), .event(.userStartedSpeaking))
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"AgentAudioDone"}"#), .event(.responseFinished))
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"FutureEvent","new_field":true}"#), .unknown)
        XCTAssertThrowsError(try DeepgramProtocol.decode("not json"))
    }

    func testLatencyHandlesMissingAndInvalidFields() throws {
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"LatencyReport","ttt_text_latency":0.25,"stt_latency":-1}"#),
                       .event(.latency(.init(transcription: nil, firstText: 0.25, total: nil))))
    }

    func testRefusedInjectionIsActionableAndDoesNotExposeProviderDetails() throws {
        let decoded = try DeepgramProtocol.decode(#"{"type":"InjectionRefused","message":"private request body"}"#)
        guard case .event(.inputRejected(let message)) = decoded else {
            return XCTFail("A refused input must not be silently discarded")
        }
        XCTAssertTrue(message.contains("submit it again"))
        XCTAssertFalse(message.contains("private request body"))
    }

    func testSpeechRaceWarningRejectsManualInputWithoutFailingConnection() throws {
        let decoded = try DeepgramProtocol.decode(#"{"type":"Warning","code":"INJECT_USER_MESSAGE_DURING_USER_SPEECH","description":"private request body"}"#)
        guard case .event(.inputRejected(let message)) = decoded else {
            return XCTFail("Speech races must return rejected manual input to the UI")
        }
        XCTAssertTrue(message.contains("speaker to finish"))
        XCTAssertFalse(message.contains("private request body"))
        XCTAssertEqual(try DeepgramProtocol.decode(#"{"type":"Warning","code":"THINK_REQUEST_FAILED"}"#),
                       .warning(code: "THINK_REQUEST_FAILED"))
    }

    func testDocumentedSessionLimitWarningSchedulesRenewal() throws {
        let decoded = try DeepgramProtocol.decode(#"{"type":"Warning","code":"MAXIMUM_SESSION_LENGTH_APPROACHING"}"#)
        XCTAssertEqual(decoded, .warning(code: "MAXIMUM_SESSION_LENGTH_APPROACHING"))
        XCTAssertTrue(DeepgramProtocol.warning(code: "MAXIMUM_SESSION_LENGTH_APPROACHING").contains("reconnect between turns"))
    }

    func testProviderSecretsAreNeverCopiedIntoUserFacingFailures() throws {
        let error = try DeepgramProtocol.decode(#"{"type":"Error","code":"INVALID_SETTINGS","description":"sensitive upstream credential and payload"}"#)
        guard case .error(let code) = error else { return XCTFail("Expected error") }
        let failure = DeepgramProtocol.failure(code: code)
        XCTAssertFalse(failure.canRetry)
        XCTAssertFalse(failure.message.contains("sensitive"))
        XCTAssertFalse(DeepgramProtocol.failure(code: "UNKNOWN", httpStatus: 401).canRetry)
        XCTAssertFalse(DeepgramProtocol.failure(code: "UNKNOWN", httpStatus: 402).canRetry)
        XCTAssertFalse(DeepgramProtocol.failure(code: "UNKNOWN", httpStatus: 429).canRetry)
        XCTAssertTrue(DeepgramProtocol.failure(code: "SERVER_GOING_AWAY").canRetry)
    }

    func testAudioIsDiscardedBeforeReadyAndAfterStop() {
        let queue = AgentAudioQueue(maximumBytes: 8)
        queue.push(Data([1, 1]))
        XCTAssertNil(queue.pop())
        _ = queue.start()
        queue.push(Data([2, 2]))
        XCTAssertEqual(queue.pop(), Data([2, 2]))
        queue.push(Data([3, 3]))
        queue.stop()
        XCTAssertEqual(queue.bufferedBytes, 0)
        queue.push(Data([4, 4]))
        XCTAssertNil(queue.pop())
    }

    func testSlowSocketCannotBuildUnboundedAudioDelay() {
        let queue = AgentAudioQueue(maximumBytes: 8)
        _ = queue.start()
        for byte in UInt8(0)..<UInt8(20) { queue.push(Data(repeating: byte, count: 4)) }
        XCTAssertLessThanOrEqual(queue.bufferedBytes, 8)
        XCTAssertTrue(queue.takeDroppedFlag())
        XCTAssertFalse(queue.takeDroppedFlag())
        XCTAssertEqual(queue.pop(), Data(repeating: 18, count: 4))
        XCTAssertEqual(queue.pop(), Data(repeating: 19, count: 4))
        XCTAssertNil(queue.pop())
    }

    func testMalformedAndOversizedPCMTriggersGap() {
        let queue = AgentAudioQueue(maximumBytes: 8)
        _ = queue.start()
        queue.push(Data([1]))
        XCTAssertTrue(queue.takeDroppedFlag())
        queue.push(Data(repeating: 1, count: 10))
        XCTAssertTrue(queue.takeDroppedFlag())
        XCTAssertEqual(queue.bufferedBytes, 0)
    }

    func testReconnectCreatesNewAudioStreamAndNeverReplaysOldAudio() async {
        let queue = AgentAudioQueue(maximumBytes: 8)
        let first = queue.start()
        queue.push(Data([1, 1]))
        queue.stop()
        let second = queue.start()
        queue.push(Data([2, 2]))
        var iterator = second.makeAsyncIterator()
        _ = await iterator.next()
        XCTAssertEqual(queue.pop(), Data([2, 2]))
        XCTAssertNil(queue.pop())
        queue.stop()
        // Keep the original stream alive through reconnect, as a retiring
        // sender task can be. It must not consume the new connection's signal.
        _ = first
    }
}
