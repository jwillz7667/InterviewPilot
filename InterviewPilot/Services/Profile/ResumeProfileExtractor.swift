import Foundation

struct ExtractedProfile: Sendable {
    let currentRole: String?
    let currentCompany: String?
    let yearsInRole: Int?
    let summary: String?
    let skills: [ExtractedSkill]
    let workExperiences: [ExtractedExperience]
    let education: [ExtractedEducation]
    let certifications: [ExtractedCertification]
    let projects: [ExtractedProject]
    let achievements: [ExtractedAchievement]
}

extension ExtractedProfile: Decodable {
    private enum CodingKeys: String, CodingKey {
        case currentRole, currentCompany, yearsInRole, summary
        case skills, workExperiences, education, certifications, projects, achievements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentRole = try container.decodeIfPresent(String.self, forKey: .currentRole)
        currentCompany = try container.decodeIfPresent(String.self, forKey: .currentCompany)
        yearsInRole = try container.decodeIfPresent(Int.self, forKey: .yearsInRole)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        skills = (try? container.decodeIfPresent([ExtractedSkill].self, forKey: .skills)) ?? []
        workExperiences = (try? container.decodeIfPresent([ExtractedExperience].self, forKey: .workExperiences)) ?? []
        education = (try? container.decodeIfPresent([ExtractedEducation].self, forKey: .education)) ?? []
        certifications = (try? container.decodeIfPresent([ExtractedCertification].self, forKey: .certifications)) ?? []
        projects = (try? container.decodeIfPresent([ExtractedProject].self, forKey: .projects)) ?? []
        achievements = (try? container.decodeIfPresent([ExtractedAchievement].self, forKey: .achievements)) ?? []
    }
}

struct ExtractedSkill: Codable, Sendable {
    let name: String
    let category: String?
}

struct ExtractedExperience: Codable, Sendable {
    let title: String
    let company: String
    let startYear: Int
    let endYear: Int?
    let description: String?
}

struct ExtractedEducation: Codable, Sendable {
    let institution: String
    let degree: String
    let field: String?
    let startYear: Int?
    let endYear: Int?
}

struct ExtractedCertification: Codable, Sendable {
    let name: String
    let issuer: String?
    let year: Int?
}

struct ExtractedProject: Codable, Sendable {
    let name: String
    let description: String?
    let techStack: String?
    let year: Int?
}

struct ExtractedAchievement: Codable, Sendable {
    let description: String
    let metric: String?
    let year: Int?
}

enum ResumeProfileExtractor {
    static func extract(from resumeText: String, apiKey: String) async throws -> ExtractedProfile {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let systemPrompt = """
        Extract a complete professional profile from the following resume. Return ONLY valid JSON with this exact schema:
        {
          "currentRole": "most recent job title or null",
          "currentCompany": "most recent company or null",
          "yearsInRole": approximate years in most recent role as integer or null,
          "summary": "2-3 sentence professional summary capturing the candidate's key strengths and focus areas",
          "skills": [
            {"name": "Swift", "category": "language"},
            {"name": "SwiftUI", "category": "framework"},
            {"name": "Docker", "category": "tool"},
            {"name": "Team Leadership", "category": "soft"}
          ],
          "workExperiences": [
            {
              "title": "Job Title",
              "company": "Company Name",
              "startYear": 2020,
              "endYear": 2024,
              "description": "Led team of 8 engineers to migrate 200k LOC UIKit app to SwiftUI, reducing UI crashes by 73%. Built real-time data pipeline processing 50k events/sec."
            }
          ],
          "education": [
            {
              "institution": "Stanford University",
              "degree": "B.S.",
              "field": "Computer Science",
              "startYear": 2012,
              "endYear": 2016
            }
          ],
          "certifications": [
            {"name": "AWS Solutions Architect", "issuer": "Amazon", "year": 2023}
          ],
          "projects": [
            {
              "name": "Project Name",
              "description": "What it does and the impact it had",
              "techStack": "Swift, Python, PostgreSQL",
              "year": 2024
            }
          ],
          "achievements": [
            {
              "description": "Reduced app cold start time from 3.2s to 0.8s through lazy loading and prewarming",
              "metric": "75% faster launch",
              "year": 2023
            }
          ]
        }

        CRITICAL RULES:
        - Extract ALL work experiences with DETAILED descriptions of key accomplishments, quantified impact, and technologies used for each role
        - For work experience descriptions: combine ALL bullet points from that role into a dense paragraph with specific numbers, metrics, and outcomes
        - Categorize EVERY skill: "language" for programming languages, "framework" for frameworks/libraries, "tool" for devops/tools/platforms, "soft" for leadership/communication
        - Extract ALL education entries including degrees in progress
        - Extract certifications, professional courses, and relevant training
        - Extract standalone projects (side projects, open source, hackathons) separately from work experience
        - For achievements: extract specific quantified accomplishments that stand out (promotions, awards, performance records, metrics improvements)
        - The summary should read like an elevator pitch, not a resume objective
        - endYear is null if the position/degree is current
        - If a field cannot be determined, use null
        - Return ONLY the JSON object, no markdown, no explanation
        """

        let body: [String: Any] = [
            "model": "gpt-4.1",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": resumeText]
            ],
            "max_tokens": 4000,
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
