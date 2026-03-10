import Foundation

struct PreComputedAnswer: Identifiable, Codable {
    let id: UUID
    let question: String
    let response: String
    let questionType: QuestionType
    let embedding: [Float]?

    init(question: String, response: String, type: QuestionType, embedding: [Float]? = nil) {
        self.id = UUID()
        self.question = question
        self.response = response
        self.questionType = type
        self.embedding = embedding
    }
}
