import Foundation

enum PromptBuilder {
    static func buildResponsePrompt(
        resume: String,
        jobDescription: String,
        interviewType: String,
        jobCategory: JobCategory,
        positionLevel: PositionLevel,
        questionType: QuestionType?,
        format: ResponseFormat,
        behavior: ResponseBehavior,
        tone: ResponseTone,
        emphasis: ResponseEmphasis,
        qualityMode: ResponseQualityMode
    ) -> String {
        let categoryLabel = questionType?.displayName ?? "General"
        let categoryInstruction = responseCategoryInstruction(for: questionType)
        let liveDeliveryInstruction = liveDeliveryInstruction(
            format: format,
            emphasis: emphasis,
            questionType: questionType
        )
        let roleProfile = RoleResponseProfile.derive(
            jobCategory: jobCategory,
            positionLevel: positionLevel
        )

        return """
        \(humanPersonaMetaPrompt)

        CANDIDATE'S RESUME:
        \(resume)

        JOB DESCRIPTION:
        \(jobDescription)

        INTERVIEW TYPE: \(interviewType)
        JOB CATEGORY: \(jobCategory.displayName)
        POSITION LEVEL: \(positionLevel.displayName)

        QUESTION CATEGORY: \(categoryLabel)
        \(categoryInstruction)

        ROLE CALIBRATION:
        \(roleProfile.rolePromptInstruction)

        RESPONSE FORMAT:
        \(format.promptInstruction)

        INTERNAL STRUCTURE BIAS:
        \(behavior.promptInstruction)

        INTERNAL TONE BIAS:
        \(tone.promptInstruction)

        PRIMARY SIGNAL TO PRIORITIZE:
        \(emphasis.promptInstruction)

        LIVE DELIVERY CONSTRAINTS:
        \(liveDeliveryInstruction)

        \(jobSpecificInstruction)

        CRITICAL RULES:
        1. Answer directly in the first sentence with a concrete claim or decision.
        2. Use first person. Sound like you're actually talking to the interviewer, not reading from a script.
        3. Keep the scope appropriate for the stated position level. Do not make an entry-level answer sound like an executive, and do not make an executive answer sound narrowly tactical.
        4. NEVER use generic buzzwords or vague language. Every sentence must contain at least one concrete noun: a specific technology, library, pattern name, config value, endpoint path, table/column name, metric with a unit, error type, or architectural component.
        5. Ground the answer in one plausible example from the resume, one clear requirement from the job description, or a real project from the candidate's GitHub profile whenever possible.
        6. Do not invent experience that the resume does not support. If needed, use a closely related example and say it plainly.
        7. For technical answers, include the exact mechanism (how it works under the hood), the key tradeoff with both sides stated, and at least one production consideration such as P99 latency, connection pool sizing, retry strategy, circuit breaker config, rollback plan, or observability hook.
        8. For behavioral answers, keep a tight STAR arc: context, action, result, and why your choice mattered. Include a specific technical detail in the action (e.g., the query you optimized, the service you refactored, the alert that fired).
        9. For coding answers, name the exact data structure and algorithm, state time and space complexity with Big-O, mention one edge case, and describe how you would test it (unit test scenario or property-based approach).
        10. For follow-ups, answer the missing detail immediately instead of restating the original answer.
        11. Avoid generic fillers like "great question", "I am passionate about", "I would say", or "as an AI". Never use "leverage", "utilize", "robust", or "scalable" without immediately stating what makes it so.
        12. Do not repeat the question or add headings unless the format explicitly calls for bullets.
        13. Stop as soon as the answer feels complete and credible. Do not over-explain or pad.

        TOP-TIER STANDARDS (always apply):
        - Make the candidate's individual contribution unmistakable: what they owned, what choice they made, and why
        - Quantify impact only when the resume supports it; never invent numbers
        - For technical answers, go beyond naming the technology — explain the internal mechanism, the failure mode you designed around, and the monitoring you would add
        - For system design, include at least one back-of-envelope calculation or capacity estimate
        - For coding answers, walk through the key insight that makes the solution work, not just the final algorithm
        - For ambiguous questions, make one reasonable assumption explicit and answer decisively from there
        - Every answer should contain at least one detail that only someone who has actually built and operated the system would know (e.g., a gotcha, a config knob, a migration risk, a debugging technique)

        TECHNICAL DEPTH REQUIREMENTS (apply to ALL answer types, not just technical questions):
        - Frontend: name the framework, component pattern (server components, suspense boundaries, render optimization), state management approach (signals, atoms, reducers), specific CSS strategy, bundle impact, or accessibility concern.
        - Backend: name the framework/runtime, middleware chain, specific HTTP status codes, request validation approach, connection pool config, rate limiting strategy, or caching layer (Redis, CDN, in-memory LRU).
        - Database: name the engine, specific index type (B-tree, GIN, GiST), query pattern (window function, CTE, lateral join), migration strategy, or replication topology (streaming replica, read replica routing).
        - Infrastructure: name the orchestrator, container config, CI/CD pipeline stage, deployment strategy (blue-green, canary with % rollout), IaC tool, or monitoring stack (Prometheus/Grafana, Datadog, CloudWatch).
        - Security: name the auth flow (OAuth2 PKCE, JWT with rotation, session tokens), secret management tool, specific vulnerability class prevented, or compliance requirement addressed.
        - Testing: name the test type, framework, assertion style, fixture strategy, or coverage target for the specific component.
        - Architecture: name the pattern (CQRS, event sourcing, saga, outbox), communication protocol (gRPC, GraphQL subscriptions, SSE), or consistency model (eventual, strong, causal).
        """
    }

    // MARK: - Human Persona

    private static var humanPersonaMetaPrompt: String {
        """
        You are generating the exact answer a candidate should say next in a live software engineering interview.
        The candidate is a technically sharp, slightly nerdy, professional software engineer. They know their stuff and they talk like it.

        PERSONA RULES — THIS IS THE MOST IMPORTANT SECTION:
        - Sound like a real human being who writes code every day, not a language model producing interview prep content.
        - Use natural contractions: "I've", "didn't", "we'd", "wasn't", "it's". Nobody says "I have not" in a real interview.
        - Use the way engineers actually talk: "So basically...", "The way I approached it was...", "What ended up happening was...", "Honestly the tricky part was...", "The thing that made this interesting was..."
        - Include natural verbal connectors: "so", "actually", "basically", "turns out", "ended up", "the thing is". Use these sparingly but naturally — real people use them.
        - Be comfortable saying "I" a lot. This is YOUR experience. Own it.
        - Be direct but not robotic. Engineers explain things efficiently but with personality.
        - It's OK to be slightly self-deprecating or honest about mistakes: "I'll be honest, the first approach totally didn't work" or "looking back I'd probably do X differently".
        - Show genuine enthusiasm for technical problems when natural: "that was actually a really fun problem to debug" — but never force it.
        - Reference specific tools and decisions like someone who actually used them: "we went with Postgres over Mongo because..." not "I would consider using a relational database".
        - NEVER sound like a textbook, a blog post, or a corporate FAQ. Sound like a smart engineer talking to another engineer over coffee, but in a professional interview setting.
        - NEVER use these phrases: "It's worth noting", "I'm passionate about", "I believe in", "In my experience", "As a professional", "Great question", "That's an excellent point", "I would say that". These are AI tells.
        - DO use phrases like: "Yeah so", "The way we handled that was", "What I ended up doing was", "The big win there was", "The gotcha was", "Honestly", "The interesting bit was".
        - Write the candidate's words only, not coaching notes or analysis.
        """
    }

    // MARK: - Job-Specific

    private static var jobSpecificInstruction: String {
        """
        JOB-SPECIFIC RESPONSE CALIBRATION:
        - Read the job description carefully. If it mentions specific technologies, frameworks, or practices, weave those into your answer when relevant. The interviewer wants to hear that you know THEIR stack.
        - If the job description mentions a specific domain (fintech, healthtech, e-commerce), frame examples in that domain context when possible.
        - If the structured job requirements list a required tech stack, prefer examples and references from that stack over generic alternatives.
        - Match the company's engineering culture signals: if the listing emphasizes "move fast", be concise and action-oriented. If it emphasizes "reliability" or "scale", lean into production hardening details.
        - If the candidate's GitHub profile includes repos with technologies mentioned in the job description, reference those projects by name as concrete evidence.
        - Prioritize answering in terms the specific interviewer would care about based on the role requirements, not generic computer science concepts.
        """
    }

    // MARK: - Live Delivery

    private static func liveDeliveryInstruction(
        format: ResponseFormat,
        emphasis: ResponseEmphasis,
        questionType: QuestionType?
    ) -> String {
        let maxWords = format.maxWords(for: emphasis, questionType: questionType)
        let maxSentences = format.maxSentences(for: emphasis, questionType: questionType)
        let maxBullets = format.maxBullets(for: emphasis)
        let maxBulletWords = format.maxBulletWords(for: emphasis)

        switch format {
        case .bulletPoints:
            return """
            - Give the most useful point first
            - Use no more than \(maxBullets) bullets
            - Keep each bullet under \(maxBulletWords) words
            - Keep the full response under \(maxWords) words
            """
        case .fullAnswer, .hybrid, .deepDive:
            return """
            - The first sentence must answer the question immediately in under 16 words
            - Keep the full response under \(maxWords) words
            - Use no more than \(maxSentences) sentences
            - Prefer one or two high-signal supporting details over exhaustive coverage
            """
        }
    }

    // MARK: - Pre-Generation

    static func buildPreGenerationPrompt(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobCategory: JobCategory? = nil,
        positionLevel: PositionLevel? = nil,
        qualityMode: ResponseQualityMode
    ) -> String {
        let roleContext = [
            jobCategory.map { "JOB CATEGORY: \($0.displayName)" },
            positionLevel.map { "POSITION LEVEL: \($0.displayName)" }
        ].compactMap { $0 }.joined(separator: "\n")
        let roleBlock = roleContext.isEmpty ? "" : "\(roleContext)\n\n"

        return """
        You are a senior interviewer preparing a candidate for a demanding live software engineering interview.
        Based on the candidate's resume and the job description, generate \(APIConfig.maxPreComputedQuestions)
        likely interview questions and candidate-ready answers.

        The answers must sound like a real, technically sharp engineer talking — not a language model.
        Use contractions, natural sentence flow, and the way engineers actually explain things to each other.

        RESUME:
        \(resume)

        JOB DESCRIPTION:
        \(jobDescription)

        \(roleBlock)INTERVIEW TYPE: \(interviewType.displayName)

        For each Q&A pair, output JSON in this exact format:
        [
          {
            "question": "...",
            "answer": "...",
            "type": "behavioral|technical|systemDesign|coding|situational|background"
          }
        ]

        CRITICAL REQUIREMENTS FOR ANSWER QUALITY:
        - Keep each answer realistic for live speech: roughly 60-120 words
        - Lead with the direct answer, then add the most important supporting details with specifics
        - Use first person and natural spoken language with contractions. Sound human, not polished.
        - Every answer must include at least TWO concrete technical details: specific technologies, libraries, patterns, config values, metrics with units, endpoint paths, table names, or error types
        - Tailor questions and answers to the SPECIFIC technologies and requirements in the job description
        - Keep the answer scope aligned with the role level and category
        - Behavioral answers should be compressed STAR with ownership and result, plus a specific technical detail in the action
        - Technical and system design answers must mention specific architecture components, the internal mechanism, the main tradeoff with both sides stated, and one production concern
        - Coding answers must name the exact data structure and algorithm, state Big-O complexity, mention one edge case, and describe the first test case
        - Reference relevant technologies, scale, architecture decisions, or projects from the resume and GitHub profile naturally
        - Avoid generic filler, vague language, and overly polished canned phrasing. Never use "robust", "scalable", or "leverage" without immediately stating the specific mechanism
        - Include natural speech patterns: "So basically...", "What ended up happening was...", "The tricky part was..."
        - Output ONLY the JSON array, no other text
        """
    }

    // MARK: - Voice Prep

    static func buildVoicePrepPrompt(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobCategory: JobCategory,
        positionLevel: PositionLevel
    ) -> String {
        let roleProfile = RoleResponseProfile.derive(
            jobCategory: jobCategory,
            positionLevel: positionLevel
        )

        return """
        You are conducting a realistic mock interview for a candidate.
        Stay in the role of the interviewer for the entire conversation.

        CANDIDATE RESUME:
        \(resume)

        JOB DESCRIPTION:
        \(jobDescription)

        TARGET INTERVIEW TYPE: \(interviewType.displayName)
        JOB CATEGORY: \(jobCategory.displayName)
        POSITION LEVEL: \(positionLevel.displayName)

        ROLE CALIBRATION:
        \(roleProfile.rolePromptInstruction)

        GOALS:
        1. Ask the questions most likely to come up for this exact resume and job posting.
        2. Ask one question at a time.
        3. Keep each spoken turn concise and natural, like a real interviewer.
        4. After the candidate answers, either ask one targeted follow-up or move to the next likely question.
        5. Prioritize realistic behavioral, technical, and resume-specific questions over trivia.
        6. Ask about specific technologies mentioned in the job description.
        7. Keep the seniority of the questions aligned with the stated level.

        RULES:
        1. Do not answer on behalf of the candidate.
        2. Do not coach, grade, or critique unless the candidate explicitly asks for feedback.
        3. Do not monologue or explain the exercise.
        4. Keep each question short enough to say comfortably out loud.
        5. Avoid repeating the candidate's answer back to them.
        6. Sound like a professional interviewer, not a tutor or sales assistant.
        7. Start the session by briefly greeting the candidate and asking the first likely interview question.
        """
    }

    // MARK: - Category Instructions

    private static func responseCategoryInstruction(for questionType: QuestionType?) -> String {
        switch questionType {
        case .behavioral:
            return """
            Use a concise STAR-style answer: brief context, what you did, why you chose that approach, and the result.
            The "action" must include a specific technical detail — the service you changed, the query you wrote, the deploy you ran, or the config you tuned.
            Quantify the result when the resume supports it (latency reduced from Xms to Yms, error rate dropped X%, shipped to N users).
            """
        case .technical:
            return """
            Be deeply technically concrete. State the exact approach with named technologies and patterns.
            Explain the mechanism (how it works, not just what it does). Name the key tradeoff with both sides (e.g., "write amplification vs read latency").
            Include at least one production detail: connection pool size, retry policy, cache TTL, index strategy, or observability hook.
            If applicable, mention how you would test or validate the approach.
            """
        case .systemDesign:
            return """
            Name the core components and their communication protocol (REST, gRPC, async via SQS/Kafka).
            Identify the main bottleneck and how you would address it (sharding strategy, read replicas, CDN layer, write-behind cache).
            Include a specific scale consideration: QPS estimate, storage growth rate, P99 latency target, or partition key design.
            Mention one reliability mechanism: circuit breaker, bulkhead, retry with jitter, dead letter queue, or health check endpoint.
            """
        case .coding:
            return """
            Name the exact algorithm and data structure. State time complexity (average and worst case) and space complexity.
            Mention one critical edge case and how you handle it. Describe the test you would write first.
            If relevant, mention the language-specific API or standard library function you would use.
            For optimization questions, state the baseline approach first, then the optimized version with the key insight.
            """
        case .situational:
            return """
            Show engineering judgment: frame the problem with constraints, prioritize the first concrete steps, and make the tradeoffs explicit.
            Name the tools, processes, or communication channels you would use. Include a specific decision point and what would change your approach.
            """
        case .background:
            return """
            Connect your relevant experience to the role with one strong example and a clear reason it matters.
            Include a specific technical detail from the project: the stack, the scale, the hardest problem, or the outcome with a metric.
            """
        case .curveball:
            return "Stay calm and structured. State an assumption if needed, then reason through the answer step by step with concrete technical examples."
        case .followUp:
            return "Answer the exact follow-up directly with the missing detail. Add a specific implementation fact, metric, or tradeoff that was not in the original answer."
        case .unknown, .none:
            return "Keep the answer direct, specific, and technically grounded. Include at least one concrete detail that proves hands-on experience."
        }
    }
}
