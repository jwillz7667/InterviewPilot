import Foundation

@Observable
final class TranscriptAccumulator {
    private(set) var currentUtterance: String = ""
    private(set) var fullTranscript: [TranscriptSegment] = []
    private var partialBuffer: String = ""

    func updatePartial(_ text: String) {
        partialBuffer = text
        currentUtterance = accumulatedFinal + (accumulatedFinal.isEmpty ? "" : " ") + text
    }

    func commitFinal(_ text: String) {
        accumulatedFinal += (accumulatedFinal.isEmpty ? "" : " ") + text
        accumulatedFinal = accumulatedFinal.trimmingCharacters(in: .whitespaces)
        currentUtterance = accumulatedFinal
        partialBuffer = ""
    }

    func finalizeUtterance() {
        guard !currentUtterance.isEmpty else { return }
        fullTranscript.append(TranscriptSegment(
            speaker: .interviewer,
            text: currentUtterance,
            timestamp: Date()
        ))
    }

    func addResponse(_ text: String) {
        fullTranscript.append(TranscriptSegment(
            speaker: .aiResponse,
            text: text,
            timestamp: Date()
        ))
    }

    func reset() {
        currentUtterance = ""
        partialBuffer = ""
        accumulatedFinal = ""
    }

    private var accumulatedFinal: String = ""
}
