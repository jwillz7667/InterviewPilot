import Foundation

/// In-memory similarity index over the user's pre-generated answer bank.
/// Generation itself runs server-side via `AnswerBankAPIService` — this type
/// is purely a runtime cache that powers the live-session prep-bank lookup.
@Observable
final class AnswerBankService {
    private(set) var answers: [PreComputedAnswer]

    init(answers: [PreComputedAnswer] = []) {
        self.answers = answers
    }

    func findMatch(query: String, threshold: Float) -> PreComputedAnswer? {
        var bestMatch: PreComputedAnswer?
        var bestScore: Float = 0

        for answer in answers {
            let score = SimilarityMatchService.wordOverlapSimilarity(query, answer.question)
            if score > bestScore && score >= threshold {
                bestScore = score
                bestMatch = answer
            }
        }

        return bestMatch
    }
}
