import Foundation

// MARK: - Communication Style

enum CommunicationStyle: String, Codable, CaseIterable, Sendable {
    case concise
    case detailed
    case storyteller

    var displayName: String {
        switch self {
        case .concise: return "Concise"
        case .detailed: return "Detailed"
        case .storyteller: return "Storyteller"
        }
    }

    var description: String {
        switch self {
        case .concise: return "Short, direct answers that get to the point quickly"
        case .detailed: return "Thorough answers with context and explanation"
        case .storyteller: return "Narrative-driven answers using the STAR method"
        }
    }
}

// MARK: - Interview Profile

struct InterviewProfile: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var isDefault: Bool
    var resumeText: String?
    var currentRole: String?
    var currentCompany: String?
    var yearsInRole: Int?
    var linkedinUrl: String?
    var summary: String?
    var communicationStyle: String?
    var workExperiences: [ProfileWorkExperience]
    var skills: [ProfileSkillEntry]
    var education: [ProfileEducation]
    var certifications: [ProfileCertification]
    var projects: [ProfileProject]
    var achievements: [ProfileAchievement]
}

struct InterviewProfileSummary: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let isDefault: Bool
    let currentRole: String?
    let currentCompany: String?
    let skillCount: Int
    let workExperienceCount: Int
    let educationCount: Int
    let projectCount: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, isDefault, currentRole, currentCompany
        case _count
    }

    private struct CountFields: Decodable {
        let skills: Int?
        let workExperiences: Int?
        let education: Int?
        let projects: Int?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        currentRole = try container.decodeIfPresent(String.self, forKey: .currentRole)
        currentCompany = try container.decodeIfPresent(String.self, forKey: .currentCompany)

        let counts = try container.decodeIfPresent(CountFields.self, forKey: ._count)
        skillCount = counts?.skills ?? 0
        workExperienceCount = counts?.workExperiences ?? 0
        educationCount = counts?.education ?? 0
        projectCount = counts?.projects ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(currentRole, forKey: .currentRole)
        try container.encodeIfPresent(currentCompany, forKey: .currentCompany)
    }

    init(id: String, name: String, isDefault: Bool, currentRole: String?, currentCompany: String?, skillCount: Int = 0, workExperienceCount: Int = 0, educationCount: Int = 0, projectCount: Int = 0) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.currentRole = currentRole
        self.currentCompany = currentCompany
        self.skillCount = skillCount
        self.workExperienceCount = workExperienceCount
        self.educationCount = educationCount
        self.projectCount = projectCount
    }
}

// MARK: - Child Types

struct ProfileWorkExperience: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var title: String
    var company: String
    var startYear: Int
    var endYear: Int?
    var description: String?

    init(id: String = UUID().uuidString, title: String, company: String, startYear: Int, endYear: Int? = nil, description: String? = nil) {
        self.id = id
        self.title = title
        self.company = company
        self.startYear = startYear
        self.endYear = endYear
        self.description = description
    }
}

struct ProfileSkillEntry: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var category: String?

    init(id: String = UUID().uuidString, name: String, category: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
    }
}

struct ProfileEducation: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var institution: String
    var degree: String
    var field: String?
    var startYear: Int?
    var endYear: Int?

    init(id: String = UUID().uuidString, institution: String, degree: String, field: String? = nil, startYear: Int? = nil, endYear: Int? = nil) {
        self.id = id
        self.institution = institution
        self.degree = degree
        self.field = field
        self.startYear = startYear
        self.endYear = endYear
    }
}

struct ProfileCertification: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var issuer: String?
    var year: Int?

    init(id: String = UUID().uuidString, name: String, issuer: String? = nil, year: Int? = nil) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.year = year
    }
}

struct ProfileProject: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String?
    var techStack: String?
    var url: String?
    var year: Int?

    init(id: String = UUID().uuidString, name: String, description: String? = nil, techStack: String? = nil, url: String? = nil, year: Int? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.techStack = techStack
        self.url = url
        self.year = year
    }
}

struct ProfileAchievement: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var description: String
    var metric: String?
    var year: Int?

    init(id: String = UUID().uuidString, description: String, metric: String? = nil, year: Int? = nil) {
        self.id = id
        self.description = description
        self.metric = metric
        self.year = year
    }
}

// MARK: - Input Types

struct CreateProfileInput: Codable, Sendable {
    let name: String
    var resumeText: String?
}

/// Payload for `PUT /api/v1/profiles/:id/full` — the whole profile in one atomic
/// save (scalars + all six collections). The editor builds this from its current
/// state, so a `nil` scalar means "the user left this empty" and is encoded as an
/// explicit JSON null to clear that column server-side; `name` is the exception —
/// it's omitted when nil so the required profile name is never wiped. Child rows
/// are encoded directly; their client-side `id` is stripped by the (non-strict)
/// backend schema, which assigns its own ids.
struct FullProfileInput: Encodable, Sendable {
    var name: String?
    var resumeText: String?
    var currentRole: String?
    var currentCompany: String?
    var yearsInRole: Int?
    var linkedinUrl: String?
    var summary: String?
    var communicationStyle: String?
    var workExperiences: [ProfileWorkExperience]
    var skills: [ProfileSkillEntry]
    var education: [ProfileEducation]
    var certifications: [ProfileCertification]
    var projects: [ProfileProject]
    var achievements: [ProfileAchievement]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try encodeNullable(resumeText, forKey: .resumeText, into: &container)
        try encodeNullable(currentRole, forKey: .currentRole, into: &container)
        try encodeNullable(currentCompany, forKey: .currentCompany, into: &container)
        try encodeNullable(yearsInRole, forKey: .yearsInRole, into: &container)
        try encodeNullable(linkedinUrl, forKey: .linkedinUrl, into: &container)
        try encodeNullable(summary, forKey: .summary, into: &container)
        try encodeNullable(communicationStyle, forKey: .communicationStyle, into: &container)
        try container.encode(workExperiences, forKey: .workExperiences)
        try container.encode(skills, forKey: .skills)
        try container.encode(education, forKey: .education)
        try container.encode(certifications, forKey: .certifications)
        try container.encode(projects, forKey: .projects)
        try container.encode(achievements, forKey: .achievements)
    }

    private func encodeNullable<T: Encodable>(
        _ value: T?,
        forKey key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, resumeText, currentRole, currentCompany, yearsInRole
        case linkedinUrl, summary, communicationStyle
        case workExperiences, skills, education, certifications, projects, achievements
    }
}
