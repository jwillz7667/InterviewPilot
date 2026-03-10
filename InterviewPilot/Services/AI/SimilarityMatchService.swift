import Foundation

enum SimilarityMatchService {
    // Simple word-overlap based similarity for fast local matching
    // Used when embeddings are not available
    static func wordOverlapSimilarity(_ text1: String, _ text2: String) -> Float {
        let words1 = Set(text1.lowercased().split(separator: " ").map(String.init))
        let words2 = Set(text2.lowercased().split(separator: " ").map(String.init))

        guard !words1.isEmpty, !words2.isEmpty else { return 0 }

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        return Float(intersection.count) / Float(union.count)
    }

    // Cosine similarity for embedding vectors
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
