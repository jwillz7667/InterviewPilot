import Foundation

enum JobCategory: String, Codable, CaseIterable, Identifiable {
    case softwareEngineering
    case dataAI
    case product
    case design
    case operations
    case salesCustomer
    case marketing
    case financeStrategy
    case peopleHR
    case generalBusiness

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .softwareEngineering: return "Software Engineering"
        case .dataAI: return "Data & AI"
        case .product: return "Product"
        case .design: return "Design"
        case .operations: return "Operations"
        case .salesCustomer: return "Sales & Customer"
        case .marketing: return "Marketing & Growth"
        case .financeStrategy: return "Finance & Strategy"
        case .peopleHR: return "People & HR"
        case .generalBusiness: return "General Business"
        }
    }

    fileprivate var inferenceKeywords: [String] {
        switch self {
        case .softwareEngineering:
            return [
                "software engineer", "ios", "android", "backend", "frontend", "full stack",
                "platform engineer", "site reliability", "sre", "devops", "mobile engineer",
                "application engineer", "developer", "swift", "kotlin", "react", "typescript",
                "distributed systems", "infrastructure"
            ]
        case .dataAI:
            return [
                "data scientist", "data engineer", "machine learning", "ml engineer", "ai engineer",
                "artificial intelligence", "analytics engineer", "nlp", "computer vision", "pytorch",
                "tensorflow", "business intelligence", "data analyst", "research scientist"
            ]
        case .product:
            return [
                "product manager", "product owner", "program manager", "technical program manager",
                "growth product", "product strategy", "roadmap", "prioritization", "go to market"
            ]
        case .design:
            return [
                "product designer", "ux designer", "ui designer", "design systems", "user research",
                "visual designer", "interaction designer", "content designer"
            ]
        case .operations:
            return [
                "operations", "business operations", "it support", "systems administrator",
                "implementation", "customer operations", "project manager", "program operations",
                "security analyst", "compliance"
            ]
        case .salesCustomer:
            return [
                "account executive", "sales", "customer success", "solutions engineer",
                "solutions consultant", "account manager", "partnerships", "revenue"
            ]
        case .marketing:
            return [
                "marketing", "growth", "demand generation", "brand", "content marketing",
                "product marketing", "communications", "seo", "paid media"
            ]
        case .financeStrategy:
            return [
                "finance", "financial analyst", "fp&a", "corporate strategy", "business strategy",
                "consulting", "investment", "planning", "strategy and operations"
            ]
        case .peopleHR:
            return [
                "recruiter", "talent acquisition", "people operations", "human resources",
                "hr business partner", "people partner", "learning and development"
            ]
        case .generalBusiness:
            return []
        }
    }

    static func infer(from text: String, title: String?) -> JobCategory {
        let searchable = "\(title ?? "")\n\(text)".lowercased()
        let bestMatch = Self.allCases
            .map { category in
                (category, category.inferenceKeywords.reduce(into: 0) { score, keyword in
                    if searchable.contains(keyword) {
                        score += keyword.contains(" ") ? 3 : 2
                    }
                })
            }
            .max { lhs, rhs in lhs.1 < rhs.1 }

        guard let bestMatch, bestMatch.1 > 0 else {
            return .generalBusiness
        }

        return bestMatch.0
    }
}

enum PositionLevel: String, Codable, CaseIterable, Identifiable {
    case entryLevel
    case midLevel
    case seniorIndividualContributor
    case management
    case seniorManagement
    case executive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .entryLevel: return "Entry Level"
        case .midLevel: return "Mid Level"
        case .seniorIndividualContributor: return "Senior IC"
        case .management: return "Management"
        case .seniorManagement: return "Senior Management"
        case .executive: return "Executive"
        }
    }

    static func infer(from text: String, title: String?) -> PositionLevel {
        let searchable = "\(title ?? "")\n\(text)".lowercased()

        let executiveSignals = [
            "chief ", "cfo", "cto", "ceo", "coo", "president", "vp ", "vice president",
            "head of ", "general manager"
        ]
        if executiveSignals.contains(where: { searchable.contains($0) }) {
            return .executive
        }

        let seniorManagementSignals = [
            "senior manager", "sr manager", "director", "group manager", "principal manager"
        ]
        if seniorManagementSignals.contains(where: { searchable.contains($0) }) {
            return .seniorManagement
        }

        let managementSignals = [
            "manager", "lead ", "people lead", "team lead", "engineering manager", "product lead"
        ]
        if managementSignals.contains(where: { searchable.contains($0) }) {
            return .management
        }

        let seniorSignals = [
            "senior ", "sr ", "staff ", "principal ", "lead engineer", "lead designer", "architect"
        ]
        if seniorSignals.contains(where: { searchable.contains($0) }) {
            return .seniorIndividualContributor
        }

        let entrySignals = [
            "entry level", "new grad", "new graduate", "associate ", "junior ", "jr ", "intern"
        ]
        if entrySignals.contains(where: { searchable.contains($0) }) {
            return .entryLevel
        }

        return .midLevel
    }
}

struct RoleResponseProfile: Sendable {
    let interviewType: InterviewType
    let responseBehavior: ResponseBehavior
    let responseTone: ResponseTone
    let responseEmphasis: ResponseEmphasis
    let rolePromptInstruction: String

    static func derive(
        jobCategory: JobCategory,
        positionLevel: PositionLevel
    ) -> RoleResponseProfile {
        let interviewType: InterviewType = {
            switch jobCategory {
            case .softwareEngineering, .dataAI:
                switch positionLevel {
                case .management, .seniorManagement, .executive:
                    return .general
                case .seniorIndividualContributor:
                    return .systemDesign
                default:
                    return .technical
                }
            case .product, .financeStrategy:
                return .caseStudy
            case .design, .salesCustomer, .marketing, .peopleHR, .generalBusiness:
                return positionLevel == .executive ? .general : .behavioral
            case .operations:
                return .general
            }
        }()

        let emphasis: ResponseEmphasis = {
            switch jobCategory {
            case .softwareEngineering, .dataAI:
                return .technicalDepth
            case .product, .design:
                return .productThinking
            case .salesCustomer, .marketing, .financeStrategy:
                return .businessImpact
            case .operations, .peopleHR, .generalBusiness:
                return positionLevel == .entryLevel ? .balanced : .leadership
            }
        }()

        let behavior: ResponseBehavior = {
            switch positionLevel {
            case .entryLevel:
                return emphasis == .technicalDepth ? .direct : .storyLed
            case .midLevel:
                return emphasis == .technicalDepth ? .analytical : .storyLed
            case .seniorIndividualContributor:
                return .analytical
            case .management, .seniorManagement, .executive:
                return .collaborative
            }
        }()

        let tone: ResponseTone = {
            switch positionLevel {
            case .entryLevel, .midLevel:
                return emphasis == .technicalDepth ? .confident : .natural
            case .seniorIndividualContributor:
                return .confident
            case .management, .seniorManagement, .executive:
                return .executive
            }
        }()

        let rolePromptInstruction: String = {
            switch positionLevel {
            case .entryLevel:
                return "Calibrate answers for an entry-level candidate: emphasize strong execution, coachability, clear fundamentals, and scope that matches individual contribution."
            case .midLevel:
                return "Calibrate answers for a mid-level candidate: emphasize ownership of meaningful work, sound prioritization, and the ability to execute independently."
            case .seniorIndividualContributor:
                return "Calibrate answers for a senior individual contributor: emphasize technical judgment, tradeoffs, mentoring influence, and ownership of ambiguous projects."
            case .management:
                return "Calibrate answers for a manager: emphasize team leadership, hiring, execution, delegation, and stakeholder alignment."
            case .seniorManagement:
                return "Calibrate answers for senior management: emphasize multi-team leadership, organizational prioritization, cross-functional influence, and durable operating judgment."
            case .executive:
                return "Calibrate answers for an executive: emphasize strategic bets, business outcomes, organizational leadership, and concise high-signal judgment."
            }
        }()

        return RoleResponseProfile(
            interviewType: interviewType,
            responseBehavior: behavior,
            responseTone: tone,
            responseEmphasis: emphasis,
            rolePromptInstruction: rolePromptInstruction
        )
    }
}
