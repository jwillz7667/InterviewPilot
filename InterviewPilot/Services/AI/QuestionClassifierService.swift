import Foundation

@Observable
final class QuestionClassifierService {
    // Keyword-based classification for speed (no API call needed)
    private let behavioralPatterns = [
        "tell me about a time", "describe a situation", "give me an example",
        "how did you handle", "what would you do", "walk me through",
        "biggest challenge", "most difficult", "conflict", "disagreement",
        "leadership", "teamwork", "failure", "mistake", "proud of",
        "tell me about yourself", "why should we hire", "strengths", "weaknesses"
    ]

    private let technicalPatterns = [
        "how does", "explain", "difference between", "what is",
        "implement", "architecture", "optimize", "performance",
        "database", "api", "algorithm", "data structure", "framework",
        "react", "swift", "python", "javascript", "typescript",
        "rest", "graphql", "microservice", "cloud", "aws", "docker"
    ]

    private let systemDesignPatterns = [
        "design a system", "scale", "high availability", "distributed",
        "how would you design", "architecture for", "millions of users",
        "load balancer", "caching", "database design", "system that"
    ]

    private let codingPatterns = [
        "write a function", "code", "implement", "algorithm",
        "time complexity", "space complexity", "big o", "leetcode",
        "binary search", "sort", "tree", "graph", "dynamic programming",
        "write code", "coding", "program"
    ]

    func classify(_ text: String) -> QuestionClassification {
        let lower = text.lowercased()

        var scores: [(QuestionType, Float)] = []

        let behavioralScore = matchScore(lower, patterns: behavioralPatterns)
        let technicalScore = matchScore(lower, patterns: technicalPatterns)
        let designScore = matchScore(lower, patterns: systemDesignPatterns)
        let codingScore = matchScore(lower, patterns: codingPatterns)

        scores.append((.behavioral, behavioralScore))
        scores.append((.technical, technicalScore))
        scores.append((.systemDesign, designScore))
        scores.append((.coding, codingScore))

        // Check for follow-up patterns
        if lower.hasPrefix("and ") || lower.hasPrefix("what about") ||
           lower.hasPrefix("can you elaborate") || lower.hasPrefix("tell me more") {
            scores.append((.followUp, 0.85))
        }

        // Check for background/intro questions
        if lower.contains("tell me about yourself") || lower.contains("walk me through your resume") ||
           lower.contains("why are you interested") || lower.contains("why this company") {
            scores.append((.background, 0.9))
        }

        guard let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0.3 else {
            return QuestionClassification(type: .unknown, confidence: 0.5)
        }

        return QuestionClassification(type: best.0, confidence: best.1)
    }

    private func matchScore(_ text: String, patterns: [String]) -> Float {
        var matches = 0
        for pattern in patterns {
            if text.contains(pattern) {
                matches += 1
            }
        }
        guard matches > 0 else { return 0 }
        return min(Float(matches) / 2.0, 1.0)
    }
}
