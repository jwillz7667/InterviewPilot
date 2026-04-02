import Foundation

struct ModelConfig: Codable, Sendable {
    let defaultModel: String
    let technicalModel: String
    let codingModel: String
    let maxTokens: Int
}
