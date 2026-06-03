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
        // Decode each collection element-by-element: a single malformed row
        // (e.g. a work experience missing `startYear`) is dropped rather than
        // collapsing the entire array to empty.
        skills = Self.lenientArray(ExtractedSkill.self, in: container, forKey: .skills)
        workExperiences = Self.lenientArray(ExtractedExperience.self, in: container, forKey: .workExperiences)
        education = Self.lenientArray(ExtractedEducation.self, in: container, forKey: .education)
        certifications = Self.lenientArray(ExtractedCertification.self, in: container, forKey: .certifications)
        projects = Self.lenientArray(ExtractedProject.self, in: container, forKey: .projects)
        achievements = Self.lenientArray(ExtractedAchievement.self, in: container, forKey: .achievements)
    }

    private static func lenientArray<T: Decodable>(
        _ type: T.Type,
        in container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [T] {
        guard let wrapped = try? container.decodeIfPresent([FailableDecodable<T>].self, forKey: key) else {
            return []
        }
        return wrapped.compactMap(\.value)
    }
}

/// Decodes to `nil` instead of throwing when its wrapped element is malformed,
/// so a bad element inside an array is skipped rather than aborting the whole
/// array decode.
private struct FailableDecodable<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(Wrapped.self)
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
    /// Extracts a structured profile from raw resume text. The prompt, model
    /// selection, token budget, and output validation/sanitization all live on
    /// the backend (`POST /api/v1/ai/extract-profile`); this client only carries
    /// the resume text up and decodes the sanitized result. Keeping the prompt
    /// server-side means it can be tuned without an app release, and the call no
    /// longer relies on the grant-gated `/ai/chat` proxy (which rejects a raw
    /// OpenAI body) that previously made autofill fail outright.
    static func extract(from resumeText: String) async throws -> ExtractedProfile {
        try Task.checkCancellation()

        do {
            let profile = try await AIClient.shared.extractProfile(resumeText: resumeText)
            try Task.checkCancellation()
            return profile
        } catch is CancellationError {
            throw ProfileExtractionError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw ProfileExtractionError.cancelled
        } catch let error as AIClientError {
            // The backend returns user-facing messages for known AppError codes;
            // pass them through so the editor can surface the real reason.
            throw ProfileExtractionError.upstream(error.errorDescription ?? "Failed to analyze resume.")
        } catch {
            throw ProfileExtractionError.apiError
        }
    }
}

enum ProfileExtractionError: LocalizedError {
    case apiError
    case parseError
    case noApiKey
    case cancelled
    case upstream(String)

    var errorDescription: String? {
        switch self {
        case .apiError: "Failed to analyze resume. Please try again."
        case .parseError: "Could not parse resume data. Try editing your resume text."
        case .noApiKey: "API key not available. Start a session first to configure keys."
        case .cancelled: "Resume analysis was cancelled."
        case .upstream(let message): message
        }
    }
}
