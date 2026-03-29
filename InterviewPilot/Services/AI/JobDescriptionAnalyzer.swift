import Foundation

struct StructuredJobRequirements: Sendable {
    let companyName: String?
    let roleTitle: String?
    let requiredTechStack: [String]
    let preferredTechStack: [String]
    let keyResponsibilities: [String]
    let experienceYears: String?
    let teamContext: String?
    let domain: String?
    let workArrangement: String?

    var formattedAnalysis: String {
        var sections: [String] = []

        sections.append("STRUCTURED JOB REQUIREMENTS:")

        if let companyName, !companyName.isEmpty {
            sections.append("Company: \(companyName)")
        }
        if let roleTitle, !roleTitle.isEmpty {
            sections.append("Role: \(roleTitle)")
        }
        if let experienceYears, !experienceYears.isEmpty {
            sections.append("Experience: \(experienceYears)")
        }
        if let workArrangement, !workArrangement.isEmpty {
            sections.append("Work arrangement: \(workArrangement)")
        }
        if let domain, !domain.isEmpty {
            sections.append("Domain: \(domain)")
        }
        if let teamContext, !teamContext.isEmpty {
            sections.append("Team context: \(teamContext)")
        }

        if !requiredTechStack.isEmpty {
            sections.append("Required stack: \(requiredTechStack.joined(separator: ", "))")
        }
        if !preferredTechStack.isEmpty {
            sections.append("Preferred/bonus: \(preferredTechStack.joined(separator: ", "))")
        }

        if !keyResponsibilities.isEmpty {
            sections.append("Key responsibilities:")
            for resp in keyResponsibilities.prefix(8) {
                sections.append("- \(resp)")
            }
        }

        return sections.joined(separator: "\n")
    }
}

enum JobDescriptionAnalyzer {
    static func analyze(title: String?, rawText: String) -> StructuredJobRequirements {
        let lower = rawText.lowercased()

        return StructuredJobRequirements(
            companyName: extractCompanyName(from: rawText),
            roleTitle: title,
            requiredTechStack: extractRequiredTech(from: lower),
            preferredTechStack: extractPreferredTech(from: lower),
            keyResponsibilities: extractResponsibilities(from: rawText),
            experienceYears: extractExperienceYears(from: lower),
            teamContext: extractTeamContext(from: lower),
            domain: extractDomain(from: lower),
            workArrangement: extractWorkArrangement(from: lower)
        )
    }

    // MARK: - Extraction Helpers

    private static func extractCompanyName(from text: String) -> String? {
        let patterns = [
            #"(?i)(?:at|join|about)\s+([A-Z][A-Za-z0-9\s&.'-]{1,40}?)(?:\s+is|\s+we|\s*[,.])"#,
            #"(?i)(?:company|employer|organization)\s*:\s*(.+?)(?:\n|$)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: text) {
                let trimmed = match.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= 2, trimmed.count <= 50 {
                    return trimmed
                }
            }
        }

        return nil
    }

    private static func extractRequiredTech(from lower: String) -> [String] {
        let techKeywords: [String: [String]] = [
            // Languages
            "TypeScript": ["typescript", " ts "],
            "JavaScript": ["javascript", " js "],
            "Python": ["python"],
            "Go": [" go ", "golang"],
            "Rust": [" rust "],
            "Java": [" java ", "java "],
            "C++": ["c++", "cpp"],
            "C#": ["c#", " c# ", ".net"],
            "Ruby": [" ruby "],
            "PHP": [" php "],
            "Swift": [" swift "],
            "Kotlin": ["kotlin"],
            "Scala": ["scala"],
            "Elixir": ["elixir"],

            // Frontend
            "React": [" react", "react.js", "reactjs"],
            "Next.js": ["next.js", "nextjs"],
            "Vue": [" vue", "vue.js", "vuejs"],
            "Angular": ["angular"],
            "Svelte": ["svelte"],
            "Tailwind CSS": ["tailwind"],
            "CSS-in-JS": ["styled-components", "emotion", "css-in-js"],

            // Backend
            "Node.js": ["node.js", "nodejs", " node "],
            "Express": ["express.js", "expressjs"],
            "FastAPI": ["fastapi"],
            "Django": ["django"],
            "Flask": ["flask"],
            "Spring Boot": ["spring boot", "spring framework"],
            "Rails": ["ruby on rails", " rails "],
            "NestJS": ["nestjs", "nest.js"],
            "Fastify": ["fastify"],
            "ASP.NET": ["asp.net"],

            // Databases
            "PostgreSQL": ["postgresql", "postgres", " psql"],
            "MySQL": ["mysql"],
            "MongoDB": ["mongodb", "mongo "],
            "Redis": ["redis"],
            "Elasticsearch": ["elasticsearch", "elastic search"],
            "DynamoDB": ["dynamodb"],
            "Cassandra": ["cassandra"],
            "SQLite": ["sqlite"],
            "SQL Server": ["sql server", "mssql"],

            // Cloud & Infra
            "AWS": [" aws ", "amazon web services"],
            "GCP": [" gcp ", "google cloud"],
            "Azure": [" azure "],
            "Docker": ["docker"],
            "Kubernetes": ["kubernetes", " k8s"],
            "Terraform": ["terraform"],
            "Pulumi": ["pulumi"],
            "CI/CD": ["ci/cd", "cicd", "continuous integration", "continuous deployment"],
            "GitHub Actions": ["github actions"],
            "Jenkins": ["jenkins"],
            "ArgoCD": ["argocd"],
            "Datadog": ["datadog"],
            "Prometheus": ["prometheus"],
            "Grafana": ["grafana"],

            // Messaging & Streaming
            "Kafka": ["kafka"],
            "RabbitMQ": ["rabbitmq"],
            "SQS": [" sqs "],
            "SNS": [" sns "],
            "NATS": [" nats "],
            "Pub/Sub": ["pub/sub", "pubsub"],

            // APIs & Protocols
            "GraphQL": ["graphql"],
            "REST": ["rest api", "restful"],
            "gRPC": ["grpc"],
            "WebSocket": ["websocket"],
            "tRPC": ["trpc"],

            // Data & ML
            "TensorFlow": ["tensorflow"],
            "PyTorch": ["pytorch"],
            "Pandas": ["pandas"],
            "Spark": ["apache spark", " spark "],
            "Airflow": ["airflow"],
            "dbt": [" dbt "],
            "Snowflake": ["snowflake"],
            "BigQuery": ["bigquery"],
            "LLM": [" llm", "large language model"],
            "RAG": [" rag ", "retrieval augmented"],

            // Tools & Practices
            "Git": [" git ", "github", "gitlab", "bitbucket"],
            "Prisma": ["prisma"],
            "Drizzle": ["drizzle"],
            "TypeORM": ["typeorm"],
            "Sequelize": ["sequelize"],
            "SQLAlchemy": ["sqlalchemy"],
            "Storybook": ["storybook"],
            "Jest": [" jest "],
            "Cypress": ["cypress"],
            "Playwright": ["playwright"],
            "Vitest": ["vitest"],

            // Auth & Security
            "OAuth": ["oauth"],
            "JWT": [" jwt"],
            "SAML": ["saml"],
            "SSO": [" sso "],
        ]

        var found: [String] = []
        for (name, keywords) in techKeywords {
            if keywords.contains(where: { lower.contains($0) }) {
                found.append(name)
            }
        }

        return found.sorted()
    }

    private static func extractPreferredTech(from lower: String) -> [String] {
        // Look for "nice to have", "preferred", "bonus" sections
        let preferredPatterns = [
            #"(?:nice to have|preferred|bonus|plus|ideally|advantageous)[:\s]*(.+?)(?:\n\n|\z)"#
        ]

        var preferredText = ""
        for pattern in preferredPatterns {
            if let match = firstMatch(pattern: pattern, in: lower) {
                preferredText += " " + match
            }
        }

        guard !preferredText.isEmpty else { return [] }

        // Re-run tech extraction on just the preferred section
        let allTech = extractRequiredTech(from: preferredText)
        let requiredTech = Set(extractRequiredTech(from: lower))
        // Return only tech that appears in preferred section but filter duplicates with required
        return allTech.filter { !requiredTech.contains($0) }
    }

    private static func extractResponsibilities(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var responsibilities: [String] = []

        let responsibilityIndicators = [
            "build", "design", "develop", "implement", "architect", "lead",
            "collaborate", "optimize", "maintain", "create", "ship", "own",
            "drive", "mentor", "review", "scale", "deploy", "monitor",
            "debug", "troubleshoot", "write", "test", "integrate", "manage"
        ]

        for line in lines {
            let lower = line.lowercased()
            let startsWithBullet = line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*")
                || (line.count > 2 && line.prefix(3).contains(".") && line.first?.isNumber == true)

            let hasVerbStart = responsibilityIndicators.contains { lower.hasPrefix($0) }

            if (startsWithBullet || hasVerbStart) && line.count >= 20 && line.count <= 300 {
                let cleaned = line
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                    .trimmingCharacters(in: .whitespaces)

                if !cleaned.isEmpty, responsibilities.count < 10 {
                    responsibilities.append(cleaned)
                }
            }
        }

        return responsibilities
    }

    private static func extractExperienceYears(from lower: String) -> String? {
        let patterns = [
            #"(\d+)\+?\s*(?:years?|yrs?)\s*(?:of\s+)?(?:experience|exp)"#,
            #"(?:experience|exp)\s*:\s*(\d+)\+?\s*(?:years?|yrs?)"#,
            #"(\d+)\s*(?:to|-)\s*(\d+)\s*(?:years?|yrs?)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: lower) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func extractTeamContext(from lower: String) -> String? {
        var signals: [String] = []

        let teamPatterns: [(String, String)] = [
            ("cross-functional", "Cross-functional team environment"),
            ("small team", "Small team"),
            ("large team", "Large team"),
            ("startup", "Startup environment"),
            ("early stage", "Early-stage company"),
            ("series a", "Series A company"),
            ("series b", "Series B company"),
            ("growth stage", "Growth-stage company"),
            ("enterprise", "Enterprise environment"),
            ("fortune 500", "Fortune 500 company"),
            ("fast-paced", "Fast-paced environment"),
            ("founding engineer", "Founding/early engineer role"),
            ("team of", "Team-based role"),
            ("pair programming", "Pair programming practiced"),
            ("agile", "Agile methodology"),
            ("scrum", "Scrum framework"),
        ]

        for (keyword, label) in teamPatterns {
            if lower.contains(keyword) {
                signals.append(label)
            }
        }

        return signals.isEmpty ? nil : signals.joined(separator: ", ")
    }

    private static func extractDomain(from lower: String) -> String? {
        let domains: [(String, [String])] = [
            ("FinTech", ["fintech", "financial technology", "banking", "payments", "trading", "cryptocurrency", "blockchain"]),
            ("HealthTech", ["healthtech", "healthcare", "medical", "clinical", "patient", "hipaa", "ehr", "telemedicine"]),
            ("EdTech", ["edtech", "education", "learning platform", "e-learning", "lms"]),
            ("E-Commerce", ["e-commerce", "ecommerce", "marketplace", "retail", "shopping", "checkout"]),
            ("SaaS/B2B", ["saas", "b2b", "enterprise software", "platform-as-a-service"]),
            ("DevTools", ["developer tools", "devtools", "developer platform", "api platform", "sdk"]),
            ("AI/ML", ["artificial intelligence", "machine learning", "deep learning", "nlp", "computer vision", "generative ai"]),
            ("Cybersecurity", ["cybersecurity", "security platform", "threat detection", "soc", "siem"]),
            ("Media/Entertainment", ["media", "streaming", "content platform", "entertainment", "video platform"]),
            ("Real Estate/PropTech", ["real estate", "proptech", "property"]),
            ("Logistics/Supply Chain", ["logistics", "supply chain", "shipping", "warehouse", "fleet"]),
            ("Social/Consumer", ["social media", "consumer app", "social platform", "messaging"]),
            ("IoT/Hardware", ["iot", "internet of things", "embedded", "hardware", "firmware"]),
            ("Gaming", ["game development", "gaming", "game engine", "game studio"]),
            ("Data/Analytics", ["data platform", "analytics", "data engineering", "data pipeline", "business intelligence"]),
            ("Infrastructure/Cloud", ["cloud infrastructure", "cloud platform", "infrastructure", "hosting"]),
        ]

        for (name, keywords) in domains {
            if keywords.contains(where: { lower.contains($0) }) {
                return name
            }
        }

        return nil
    }

    private static func extractWorkArrangement(from lower: String) -> String? {
        if lower.contains("fully remote") || lower.contains("100% remote") {
            return "Fully remote"
        }
        if lower.contains("remote-first") || lower.contains("remote first") {
            return "Remote-first"
        }
        if lower.contains("hybrid") {
            return "Hybrid"
        }
        if lower.contains("on-site") || lower.contains("onsite") || lower.contains("in-office") {
            return "On-site"
        }
        if lower.contains("remote") {
            return "Remote"
        }

        return nil
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        // Return the first capture group if it exists, otherwise the full match
        let captureIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let captureRange = Range(match.range(at: captureIndex), in: text) else { return nil }

        return String(text[captureRange])
    }
}
