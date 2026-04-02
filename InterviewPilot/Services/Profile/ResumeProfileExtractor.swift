import Foundation

struct ExtractedProfile: Codable, Sendable {
    let currentRole: String?
    let currentCompany: String?
    let yearsInRole: Int?
    let skills: [String]
    let workExperiences: [ExtractedExperience]
}

struct ExtractedExperience: Codable, Sendable {
    let title: String
    let company: String
    let startYear: Int
    let endYear: Int?
}

enum ResumeProfileExtractor {
    static func extract(from resumeText: String, apiKey: String) async throws -> ExtractedProfile {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let systemPrompt = """
        Extract structured profile information from the following resume text. Return ONLY valid JSON with this exact schema:
        {
          "currentRole": "most recent job title or null",
          "currentCompany": "most recent company or null",
          "yearsInRole": approximate years in most recent role as integer or null,
          "skills": ["skill1", "skill2", ...],
          "workExperiences": [
            {
              "title": "Job Title",
              "company": "Company Name",
              "startYear": 2020,
              "endYear": 2024 or null if current
            }
          ]
        }

        Rules:
        - Extract ALL work experiences, ordered most recent first
        - For skills, extract technical skills, programming languages, frameworks, tools, and soft skills mentioned
        - If a field cannot be determined, use null
        - For yearsInRole, calculate from the start date of the most recent position to now
        - Return ONLY the JSON object, no markdown, no explanation
        """

        let body: [String: Any] = [
            "model": APIConfig.defaultResponseModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": resumeText]
            ],
            "max_tokens": 1500,
            "temperature": 0.1,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProfileExtractionError.apiError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw ProfileExtractionError.parseError
        }

        return try JSONDecoder().decode(ExtractedProfile.self, from: contentData)
    }
}

enum ProfileExtractionError: LocalizedError {
    case apiError
    case parseError
    case noApiKey

    var errorDescription: String? {
        switch self {
        case .apiError: "Failed to analyze resume. Please try again."
        case .parseError: "Could not parse resume data. Try editing your resume text."
        case .noApiKey: "API key not available. Start a session first to configure keys."
        }
    }
}
