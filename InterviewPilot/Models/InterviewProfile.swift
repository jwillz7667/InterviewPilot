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

struct UpdateProfileInput: Codable, Sendable {
    var name: String?
    var isDefault: Bool?
    var resumeText: String?
    var currentRole: String?
    var currentCompany: String?
    var yearsInRole: Int?
    var linkedinUrl: String?
    var summary: String?
    var communicationStyle: String?
}
