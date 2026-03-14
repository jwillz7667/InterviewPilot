import Foundation

enum PromptBuilder {
    static func buildResponsePrompt(
        resume: String,
        jobDescription: String,
        interviewType: String,
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

        return """
        You are generating the exact answer a candidate should say next in a live interview.
        Sound like a strong senior engineer speaking naturally under pressure.
        Write the candidate's words only, not coaching notes or analysis.

        CANDIDATE'S RESUME:
        \(resume)

        JOB DESCRIPTION:
        \(jobDescription)

        INTERVIEW TYPE: \(interviewType)

        QUESTION CATEGORY: \(categoryLabel)
        \(categoryInstruction)

        RESPONSE FORMAT:
        \(format.promptInstruction)

        RESPONSE BEHAVIOR:
        \(behavior.promptInstruction)

        RESPONSE TONE:
        \(tone.promptInstruction)

        PRIMARY EMPHASIS:
        \(emphasis.promptInstruction)

        RESPONSE QUALITY MODE:
        \(qualityMode.promptInstruction)

        \(premiumQualityStandards(for: qualityMode))

        LIVE DELIVERY CONSTRAINTS:
        \(liveDeliveryInstruction)

        CRITICAL RULES:
        1. Answer directly in the first sentence.
        2. Use first person and sound spoken, conversational, and human. Contractions are good when natural.
        3. Prefer concrete nouns over generic buzzwords: name the system, tool, tradeoff, failure mode, metric, or customer impact when relevant.
        4. Ground the answer in one plausible example from the resume or one clear requirement from the job description whenever possible.
        5. Do not invent experience that the resume does not support. If needed, use a closely related example and say it plainly.
        6. For technical answers, include the mechanism, the key tradeoff, and one production consideration such as latency, reliability, observability, security, or rollback.
        7. For behavioral answers, keep a tight STAR arc: context, action, result, and why your choice mattered.
        8. For coding answers, mention the approach, data structure, complexity, and one edge case or test.
        9. For follow-ups, answer the missing detail immediately instead of restating the original answer.
        10. Avoid generic fillers like "great question", "I am passionate about", "I would say", or "as an AI".
        11. Do not repeat the question or add headings unless the format explicitly calls for bullets.
        12. Stop as soon as the answer feels complete and credible. Do not spend extra words polishing.
        """
    }

    private static func premiumQualityStandards(for qualityMode: ResponseQualityMode) -> String {
        guard qualityMode == .premium else { return "" }

        return """
        TOP-TIER INTERVIEW STANDARDS:
        - For behavioral questions, implicitly use STAR/R: minimal setup, action-heavy middle, concrete result, and brief reflection or lesson when it adds signal
        - Make the candidate's individual contribution unmistakable: what they owned, what choice they made, and why
        - Quantify impact only when the resume or prompt supports it; never invent numbers
        - For technical answers, state the mechanism, tradeoff, and production risk or safeguard clearly
        - For ambiguous questions, make one reasonable assumption explicit and answer decisively from there
        - Make the answer feel like a strong real candidate, not a memorized template
        """
    }

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
            - The first sentence must answer the question immediately in under 14 words
            - Keep the full response under \(maxWords) words
            - Use no more than \(maxSentences) sentences
            - Prefer one or two high-signal supporting details over exhaustive coverage
            """
        }
    }

    static func buildPreGenerationPrompt(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        qualityMode: ResponseQualityMode
    ) -> String {
        return """
        You are a senior engineering interviewer preparing a candidate for a demanding live interview.
        Based on the candidate's resume and the job description, generate \(APIConfig.maxPreComputedQuestions)
        likely interview questions and candidate-ready answers that sound human, specific, and technically credible.

        RESUME:
        \(resume)

        JOB DESCRIPTION:
        \(jobDescription)

        INTERVIEW TYPE: \(interviewType.displayName)

        RESPONSE QUALITY MODE:
        \(qualityMode.preGenerationInstruction)

        For each Q&A pair, output JSON in this exact format:
        [
          {
            "question": "...",
            "answer": "...",
            "type": "behavioral|technical|systemDesign|coding|situational|background"
          }
        ]

        CRITICAL REQUIREMENTS FOR ANSWER QUALITY:
        - Keep each answer realistic for live speech: roughly 45-85 words
        - Lead with the direct answer, then add the most important supporting detail
        - Use first person and natural spoken language, not textbook prose
        - Make answers specific: include one concrete technical detail, tradeoff, metric, or implementation choice when relevant
        - Behavioral answers should be compressed STAR with ownership and result
        - In premium mode, make the answer feel interviewer-caliber: strong headline, action-heavy evidence, real judgment, and meaningful impact
        - Technical and system design answers should mention architecture or mechanism, the main tradeoff, and one production concern
        - Coding answers should mention the approach, complexity, and one edge case
        - Reference relevant technologies, scope, or projects from the resume naturally
        - Avoid generic filler and avoid overly polished canned phrasing
        - Output ONLY the JSON array, no other text
        """
    }

    static func buildVoicePrepPrompt(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType
    ) -> String {
        """
        You are conducting a realistic mock interview for a candidate.
        Stay in the role of the interviewer for the entire conversation.

        CANDIDATE RESUME:
        \(resume)

        JOB DESCRIPTION:
        \(jobDescription)

        TARGET INTERVIEW TYPE: \(interviewType.displayName)

        GOALS:
        1. Ask the questions most likely to come up for this exact resume and job posting.
        2. Ask one question at a time.
        3. Keep each spoken turn concise and natural, like a real interviewer.
        4. After the candidate answers, either ask one targeted follow-up or move to the next likely question.
        5. Prioritize realistic behavioral, technical, and resume-specific questions over trivia.

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

    private static func responseCategoryInstruction(for questionType: QuestionType?) -> String {
        switch questionType {
        case .behavioral:
            return "Use a concise STAR-style answer: brief context, what you did, why you chose that approach, and the result."
        case .technical:
            return "Be technically concrete: state the approach, name the tradeoff, and mention one implementation or production detail."
        case .systemDesign:
            return "Explain the architecture at a high level, identify the main bottleneck or tradeoff, and mention scale, reliability, or observability."
        case .coding:
            return "Describe the algorithm, the data structure, time and space complexity, and one edge case you would test."
        case .situational:
            return "Show judgment: describe how you would frame the problem, prioritize the first steps, and make the tradeoffs explicit."
        case .background:
            return "Connect your relevant experience to the role with one strong example and a clear reason it matters."
        case .curveball:
            return "Stay calm and structured. State an assumption if needed, then reason through the answer clearly."
        case .followUp:
            return "Answer the exact follow-up directly with the missing detail, not a full reset of the prior answer."
        case .unknown, .none:
            return "Keep the answer balanced: direct, specific, and easy to say out loud."
        }
    }
}
