import Foundation

struct UserProfile: Codable, Sendable {
    let id: String
    let email: String
    var displayName: String?
    var avatarUrl: String?
    var linkedinUrl: String?
    var primaryGoal: String?
    var resumeFileUrl: String?
    var resumeText: String?
    var currentRole: String?
    var currentCompany: String?
    var yearsInRole: Int?
    var onboardingCompleted: Bool
    var workExperiences: [WorkExperienceEntry]
    var skills: [SkillEntry]
}

struct WorkExperienceEntry: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var title: String
    var company: String
    var startYear: Int
    var endYear: Int?

    init(id: String = UUID().uuidString, title: String, company: String, startYear: Int, endYear: Int? = nil) {
        self.id = id
        self.title = title
        self.company = company
        self.startYear = startYear
        self.endYear = endYear
    }
}

struct SkillEntry: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}
