import Foundation
import SwiftData

@Observable
final class InsightsViewModel {
    var insights: SessionInsights = SessionInsights()
    var sessionCount: Int = 0
    var latestSessionDate: Date?
    var isLoading = false

    var hasData: Bool {
        insights.overallScore != nil
    }

    var overallScoreLabel: String {
        guard let score = insights.overallScore else { return "--" }
        return "\(score)"
    }

    var performanceLabel: String {
        guard let score = insights.overallScore else { return "No data yet" }
        if score >= 85 { return "Excellent Session!" }
        if score >= 70 { return "Great Session!" }
        if score >= 50 { return "Good Progress" }
        return "Keep Practicing"
    }

    func loadData(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        let descriptor = FetchDescriptor<InterviewSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        guard let sessions = try? modelContext.fetch(descriptor) else { return }
        sessionCount = sessions.count

        if let latest = sessions.first {
            latestSessionDate = latest.startedAt

            let exchanges = latest.exchanges
            let count = exchanges.count
            guard count > 0 else { return }

            let technicalScore = computeTechnicalDepthScore(exchanges)
            let communicationScore = computeCommunicationScore(exchanges)
            let confidenceScore = computeConfidenceScore(exchanges)

            insights = SessionInsights(
                technicalAccuracyScore: technicalScore,
                communicationScore: communicationScore,
                confidenceScore: confidenceScore,
                aiStrengths: computeStrengths(exchanges: exchanges),
                aiImprovements: computeImprovements(exchanges: exchanges),
                overallScore: Int((technicalScore * 0.4 + communicationScore * 0.35 + confidenceScore * 0.25))
            )
        }
    }

    // MARK: - Technical Depth Score (0-100)
    // Evaluates: response length, presence of specific technical terms,
    // named technologies/tools, quantified metrics, and structured reasoning

    private func computeTechnicalDepthScore(_ exchanges: [Exchange]) -> Double {
        guard !exchanges.isEmpty else { return 0 }

        var totalScore: Double = 0

        for exchange in exchanges {
            let response = exchange.generatedResponse
            let wordCount = response.split(separator: " ").count
            var exchangeScore: Double = 0

            // Response substance (0-25): adequate length for interview answers
            let lengthScore: Double
            if wordCount >= 80 {
                lengthScore = 25
            } else if wordCount >= 50 {
                lengthScore = 20
            } else if wordCount >= 30 {
                lengthScore = 15
            } else {
                lengthScore = Double(wordCount) / 30.0 * 10
            }
            exchangeScore += lengthScore

            // Technical specificity (0-25): named technologies, patterns, tools
            let techTerms = countTechnicalTerms(in: response)
            exchangeScore += min(Double(techTerms) * 5.0, 25)

            // Quantified claims (0-25): percentages, latency, metrics, numbers with context
            let quantifiedClaims = countQuantifiedClaims(in: response)
            exchangeScore += min(Double(quantifiedClaims) * 8.0, 25)

            // Structured reasoning (0-25): clear cause-effect, tradeoffs, decision rationale
            let structureScore = evaluateStructure(response)
            exchangeScore += structureScore

            totalScore += min(exchangeScore, 100)
        }

        return totalScore / Double(exchanges.count)
    }

    // MARK: - Communication Score (0-100)
    // Evaluates: response clarity, conciseness, directness,
    // sentence structure, and conversational tone

    private func computeCommunicationScore(_ exchanges: [Exchange]) -> Double {
        guard !exchanges.isEmpty else { return 0 }

        var totalScore: Double = 0

        for exchange in exchanges {
            let response = exchange.generatedResponse
            let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let wordCount = response.split(separator: " ").count
            var exchangeScore: Double = 0

            // Direct opening (0-30): starts with a clear answer, not filler
            let firstSentence = sentences.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let startsWithFiller = firstSentence.hasPrefix("well,") || firstSentence.hasPrefix("so,")
                || firstSentence.hasPrefix("um,") || firstSentence.hasPrefix("that's a great question")
            exchangeScore += startsWithFiller ? 10 : 30

            // Sentence clarity (0-25): average sentence length in reasonable range (10-25 words)
            if !sentences.isEmpty {
                let avgSentenceWords = Double(wordCount) / Double(sentences.count)
                if avgSentenceWords >= 10 && avgSentenceWords <= 25 {
                    exchangeScore += 25
                } else if avgSentenceWords >= 7 && avgSentenceWords <= 35 {
                    exchangeScore += 18
                } else {
                    exchangeScore += 8
                }
            }

            // First-person ownership (0-20): uses "I", "my", "we" (shows ownership)
            let firstPersonCount = response.components(separatedBy: " ")
                .filter { ["i", "i've", "i'd", "my", "we", "we'd", "we've"].contains($0.lowercased()) }
                .count
            let firstPersonRatio = Double(firstPersonCount) / Double(max(wordCount, 1))
            exchangeScore += min(firstPersonRatio * 400, 20)

            // Avoids banned phrases (0-25): no filler, no cliches
            let bannedPhrases = ["it's worth noting", "i'm passionate about", "leverage", "innovative",
                                 "synergy", "at the end of the day", "in terms of"]
            let hasBanned = bannedPhrases.contains { response.lowercased().contains($0) }
            exchangeScore += hasBanned ? 5 : 25

            totalScore += min(exchangeScore, 100)
        }

        return totalScore / Double(exchanges.count)
    }

    // MARK: - Confidence Score (0-100)
    // Evaluates: response speed, consistency, question coverage,
    // and preparedness indicators

    private func computeConfidenceScore(_ exchanges: [Exchange]) -> Double {
        guard !exchanges.isEmpty else { return 0 }

        var totalScore: Double = 0

        // Response speed (0-30): faster first-token = more prepared
        let avgLatency = exchanges.map { $0.responseLatencyMs }.reduce(0, +) / exchanges.count
        let speedScore: Double
        if avgLatency < 1000 {
            speedScore = 30
        } else if avgLatency < 2000 {
            speedScore = 25
        } else if avgLatency < 4000 {
            speedScore = 18
        } else {
            speedScore = 10
        }
        totalScore += speedScore

        // Consistency (0-25): similar response quality across questions
        let lengths = exchanges.map { Double($0.generatedResponse.split(separator: " ").count) }
        let avgLength = lengths.reduce(0, +) / Double(lengths.count)
        let variance = lengths.map { ($0 - avgLength) * ($0 - avgLength) }.reduce(0, +) / Double(lengths.count)
        let coeffOfVariation = avgLength > 0 ? sqrt(variance) / avgLength : 1.0
        totalScore += coeffOfVariation < 0.3 ? 25 : (coeffOfVariation < 0.5 ? 18 : 10)

        // Question type coverage (0-25): handles different question types
        let uniqueTypes = Set(exchanges.map { $0.questionType.lowercased() })
            .filter { $0 != "unknown" }
        let diversityScore = min(Double(uniqueTypes.count) * 8.0, 25)
        totalScore += diversityScore

        // Preparedness (0-20): cache hits and predictive fire usage
        let cachedCount = exchanges.filter { $0.wasPreComputed }.count
        let cachedRatio = Double(cachedCount) / Double(exchanges.count)
        totalScore += cachedRatio * 20

        return min(totalScore, 100)
    }

    // MARK: - Scoring Helpers

    private func countTechnicalTerms(in text: String) -> Int {
        let lower = text.lowercased()
        let techPatterns = [
            "api", "rest", "graphql", "grpc", "websocket", "http", "tcp",
            "react", "swift", "python", "typescript", "javascript", "java", "go", "rust", "kotlin",
            "aws", "gcp", "azure", "docker", "kubernetes", "k8s", "terraform", "ci/cd",
            "postgresql", "mysql", "mongodb", "redis", "elasticsearch", "dynamodb",
            "microservice", "monolith", "serverless", "lambda", "cdn", "load balancer",
            "oauth", "jwt", "ssl", "tls", "cors", "csrf", "xss",
            "git", "github", "jenkins", "datadog", "grafana", "sentry",
            "b-tree", "hash map", "queue", "stack", "linked list", "binary search",
            "o(n)", "o(log n)", "o(1)", "big o", "time complexity",
            "caching", "sharding", "replication", "partitioning", "indexing",
            "unit test", "integration test", "e2e", "tdd", "coverage",
        ]
        return techPatterns.filter { lower.contains($0) }.count
    }

    private func countQuantifiedClaims(in text: String) -> Int {
        var count = 0
        let patterns = ["%", "ms", "seconds", "minutes", "requests per", "qps", "tps",
                        "latency", "throughput", "uptime", "99.", "p95", "p99",
                        "reduced by", "increased by", "improved by", "decreased by",
                        "x faster", "x slower", "million", "thousand", "billion"]
        let lower = text.lowercased()
        for pattern in patterns {
            if lower.contains(pattern) { count += 1 }
        }
        // Count numbers with context (e.g., "40% reduction", "200ms", "3 services")
        let words = text.split(separator: " ")
        for word in words {
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            if trimmed.first?.isNumber == true && trimmed.count <= 10 {
                count += 1
            }
        }
        return count
    }

    private func evaluateStructure(_ text: String) -> Double {
        var score: Double = 0
        let lower = text.lowercased()

        // Cause-effect reasoning
        let causalTerms = ["because", "so that", "which led to", "as a result",
                           "this meant", "the tradeoff", "the reason", "decided to"]
        let causalCount = causalTerms.filter { lower.contains($0) }.count
        score += min(Double(causalCount) * 4.0, 10)

        // Specific project/system references
        let hasProjectRef = lower.contains("built") || lower.contains("designed")
            || lower.contains("implemented") || lower.contains("migrated")
            || lower.contains("refactored") || lower.contains("deployed")
        score += hasProjectRef ? 8 : 0

        // Tradeoff awareness
        let tradeoffTerms = ["tradeoff", "trade-off", "downside", "limitation",
                             "alternative", "instead of", "versus", "compared to"]
        let hasTradeoff = tradeoffTerms.contains { lower.contains($0) }
        score += hasTradeoff ? 7 : 0

        return min(score, 25)
    }

    // MARK: - Strengths & Improvements

    private func computeStrengths(exchanges: [Exchange]) -> [String] {
        var strengths: [String] = []

        let avgLength = exchanges.map { $0.generatedResponse.split(separator: " ").count }.reduce(0, +) / max(exchanges.count, 1)

        if exchanges.count >= 5 {
            strengths.append("Sustained engagement across \(exchanges.count) questions")
        }

        if avgLength >= 60 {
            strengths.append("Detailed responses with strong depth")
        }

        let techExchanges = exchanges.filter {
            ["technical", "coding", "systemDesign"].contains($0.questionType)
        }
        if techExchanges.count >= 2 {
            strengths.append("Handled \(techExchanges.count) technical questions effectively")
        }

        let avgLatency = exchanges.map { $0.responseLatencyMs }.reduce(0, +) / max(exchanges.count, 1)
        if avgLatency < 2000 {
            strengths.append("Fast, confident response delivery")
        }

        let cachedCount = exchanges.filter { $0.wasPreComputed }.count
        if cachedCount > 0 {
            strengths.append("Prep work paid off — \(cachedCount) answers from answer bank")
        }

        let uniqueTypes = Set(exchanges.map { $0.questionType }).filter { $0 != "unknown" }
        if uniqueTypes.count >= 3 {
            strengths.append("Versatile across \(uniqueTypes.count) question categories")
        }

        if strengths.isEmpty {
            strengths.append("Completed a full interview session")
        }

        return Array(strengths.prefix(4))
    }

    private func computeImprovements(exchanges: [Exchange]) -> [String] {
        var improvements: [String] = []

        let avgLength = exchanges.map { $0.generatedResponse.split(separator: " ").count }.reduce(0, +) / max(exchanges.count, 1)

        if avgLength < 40 {
            improvements.append("Expand responses with specific examples and project references")
        }

        if exchanges.count < 3 {
            improvements.append("Practice answering more questions to build stamina")
        }

        let avgLatency = exchanges.map { $0.responseLatencyMs }.reduce(0, +) / max(exchanges.count, 1)
        if avgLatency > 4000 {
            improvements.append("Pre-generate answers to reduce response time")
        }

        // Check for technical term density
        let avgTechTerms = exchanges.map { countTechnicalTerms(in: $0.generatedResponse) }.reduce(0, +) / max(exchanges.count, 1)
        if avgTechTerms < 2 {
            improvements.append("Include more specific technologies, tools, and patterns")
        }

        // Check for quantified claims
        let avgQuantified = exchanges.map { countQuantifiedClaims(in: $0.generatedResponse) }.reduce(0, +) / max(exchanges.count, 1)
        if avgQuantified < 2 {
            improvements.append("Add quantified impact — percentages, latency, scale numbers")
        }

        let uniqueTypes = Set(exchanges.map { $0.questionType }).filter { $0 != "unknown" }
        if uniqueTypes.count <= 1 {
            improvements.append("Practice different question types (behavioral, technical, system design)")
        }

        if improvements.isEmpty {
            improvements.append("Continue practicing to maintain consistency")
        }

        return Array(improvements.prefix(4))
    }
}
