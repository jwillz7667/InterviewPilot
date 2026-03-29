import Foundation

enum JobDescriptionService {
    // Extract key terms from job description for Deepgram keyword boosting
    static func extractKeywords(from text: String) -> [String] {
        let techTerms = [
            // Languages
            "React", "Node", "TypeScript", "JavaScript", "Python", "Swift", "SwiftUI",
            "Java", "Go", "Rust", "C++", "C#", "Ruby", "PHP", "Kotlin", "Scala",
            "Elixir", "Haskell", "Clojure", "Dart", "Zig",

            // Frontend frameworks
            "Next.js", "Vue", "Angular", "Svelte", "Remix", "Astro", "Nuxt",
            "Tailwind", "Storybook", "Webpack", "Vite", "Turbopack",
            "React Native", "Flutter", "Expo",

            // Backend frameworks
            "Express", "Fastify", "NestJS", "Django", "Flask", "FastAPI",
            "Spring", "Spring Boot", "Rails", "Laravel", "ASP.NET",
            "Gin", "Echo", "Fiber", "Actix",

            // Databases
            "PostgreSQL", "Postgres", "MySQL", "MongoDB", "Redis",
            "Elasticsearch", "DynamoDB", "Cassandra", "CockroachDB",
            "SQLite", "Supabase", "PlanetScale", "Neon",
            "Prisma", "Drizzle", "TypeORM", "Sequelize", "SQLAlchemy",

            // Cloud & Infrastructure
            "AWS", "GCP", "Azure", "Docker", "Kubernetes",
            "Terraform", "Pulumi", "CloudFormation",
            "Lambda", "S3", "EC2", "ECS", "Fargate", "EKS",
            "Vercel", "Netlify", "Railway", "Fly.io", "Render",
            "Cloudflare", "Nginx", "Caddy",

            // CI/CD & DevOps
            "GitHub Actions", "Jenkins", "CircleCI", "GitLab CI",
            "ArgoCD", "Flux", "Helm", "Kustomize",
            "Datadog", "Prometheus", "Grafana", "New Relic", "Sentry",
            "PagerDuty", "OpsGenie",

            // Messaging & Streaming
            "Kafka", "RabbitMQ", "SQS", "SNS", "NATS",
            "Pub/Sub", "EventBridge", "Kinesis",

            // APIs & Protocols
            "GraphQL", "REST", "gRPC", "WebSocket", "tRPC",
            "OpenAPI", "Swagger", "Protocol Buffers", "Protobuf",

            // AI & ML
            "Machine Learning", "Deep Learning", "NLP", "Computer Vision",
            "TensorFlow", "PyTorch", "LLM", "RAG",
            "OpenAI", "Anthropic", "Claude", "GPT",
            "LangChain", "Pinecone", "Weaviate", "ChromaDB",
            "Hugging Face", "Transformers",

            // Data Engineering
            "Spark", "Airflow", "dbt", "Snowflake", "BigQuery",
            "Redshift", "Databricks", "Pandas", "Polars",
            "Dagster", "Prefect", "Fivetran",

            // Auth & Security
            "OAuth", "JWT", "SAML", "SSO", "RBAC",
            "Vault", "Auth0", "Clerk", "NextAuth",

            // Testing
            "Jest", "Vitest", "Cypress", "Playwright",
            "Selenium", "pytest", "JUnit", "Mocha",
            "Storybook", "Chromatic",

            // Practices
            "Agile", "Scrum", "Kanban", "CI/CD",
            "Microservices", "Serverless", "Monorepo",
            "CQRS", "Event Sourcing", "Domain Driven Design",
            "SQL", "NoSQL", "Git",
        ]

        return techTerms.filter { text.localizedCaseInsensitiveContains($0) }
    }
}
