import Foundation

struct ExtractedProfile: Sendable {
    let displayName: String?
    let linkedinUrl: String?
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
        case displayName, linkedinUrl
        case currentRole, currentCompany, yearsInRole, summary
        case skills, workExperiences, education, certifications, projects, achievements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        linkedinUrl = try container.decodeIfPresent(String.self, forKey: .linkedinUrl)
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
    static func extract(from resumeText: String) async throws -> ExtractedProfile {
        try Task.checkCancellation()

        let systemPrompt = """
        Extract a complete professional profile from the following resume. Return ONLY valid JSON with this exact schema:
        {
          "displayName": "candidate's full name from the resume header (e.g., \\"Jane Doe\\") or null",
          "linkedinUrl": "candidate's LinkedIn URL exactly as it appears in the resume (e.g., \\"linkedin.com/in/janedoe\\") or null",
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
        - displayName must be ONLY the candidate's full personal name as it appears at the top of the resume — never a job title, company, or URL.
        - linkedinUrl must be COPIED VERBATIM from the resume text. Never invent a URL. If no LinkedIn URL is present, return null.
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

        let json: [String: Any]
        do {
            json = try await AIClient.shared.chat(body: body)
        } catch is CancellationError {
            throw ProfileExtractionError.cancelled
        } catch {
            throw ProfileExtractionError.apiError
        }

        try Task.checkCancellation()

        guard let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw ProfileExtractionError.parseError
        }

        do {
            return try JSONDecoder().decode(ExtractedProfile.self, from: contentData)
        } catch {
            throw ProfileExtractionError.parseError
        }
    }
}

enum ProfileExtractionError: LocalizedError {
    case apiError
    case parseError
    case noApiKey
    case cancelled

    var errorDescription: String? {
        switch self {
        case .apiError: "Failed to analyze resume. Please try again."
        case .parseError: "Could not parse resume data. Try editing your resume text."
        case .noApiKey: "API key not available. Start a session first to configure keys."
        case .cancelled: "Resume analysis was cancelled."
        }
    }
}
