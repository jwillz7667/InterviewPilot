import Foundation

enum JobDescriptionService {
    // Extract key terms from job description for Deepgram keyword boosting
    static func extractKeywords(from text: String) -> [String] {
        let techTerms = [
            "React", "Node", "TypeScript", "JavaScript", "Python", "AWS",
            "Docker", "Kubernetes", "PostgreSQL", "MongoDB", "Redis",
            "GraphQL", "REST", "CI/CD", "Terraform", "Swift", "SwiftUI",
            "Java", "Go", "Rust", "C++", "Angular", "Vue", "Next.js",
            "Express", "Django", "Flask", "Spring", "Kafka", "RabbitMQ",
            "Elasticsearch", "DynamoDB", "Firebase", "Azure", "GCP",
            "Machine Learning", "Deep Learning", "NLP", "Computer Vision",
            "TensorFlow", "PyTorch", "Agile", "Scrum", "Kanban",
            "Microservices", "Serverless", "Lambda", "S3", "EC2",
            "SQL", "NoSQL", "Git", "Jenkins", "GitHub Actions"
        ]

        return techTerms.filter { text.localizedCaseInsensitiveContains($0) }
    }
}
