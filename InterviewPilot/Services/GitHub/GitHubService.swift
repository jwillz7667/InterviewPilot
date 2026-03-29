import Foundation

struct GitHubProfileSummary: Sendable {
    let username: String
    let displayName: String?
    let bio: String?
    let publicRepoCount: Int
    let followers: Int
    let topRepos: [RepoSummary]
    let primaryLanguages: [String]

    struct RepoSummary: Sendable, Identifiable {
        var id: String { name }
        let name: String
        let description: String?
        let language: String?
        let stars: Int
        let forks: Int
        let topics: [String]
        let updatedAt: String
    }

    /// Full profile context using all top repos
    var formattedContext: String {
        formattedContext(featuredRepos: topRepos)
    }

    /// Profile context using only user-selected featured repos
    func formattedContext(featuredRepos: [RepoSummary]) -> String {
        var sections: [String] = []

        sections.append("GitHub: github.com/\(username)")
        if let displayName, !displayName.isEmpty {
            sections.append("Name: \(displayName)")
        }
        if let bio, !bio.isEmpty {
            sections.append("Bio: \(bio)")
        }
        sections.append("Public repos: \(publicRepoCount) | Followers: \(followers)")

        if !primaryLanguages.isEmpty {
            sections.append("Primary languages: \(primaryLanguages.joined(separator: ", "))")
        }

        if !featuredRepos.isEmpty {
            sections.append("")
            sections.append("FEATURED PROJECTS — rotate across these in answers. Use the EXACT name shown (never abbreviate or rename):")
            for repo in featuredRepos {
                var line = "- \"\(repo.name)\" (use this exact name)"
                if let lang = repo.language {
                    line += " [\(lang)]"
                }
                if repo.stars > 0 {
                    line += " (\(repo.stars) stars)"
                }
                if let desc = repo.description, !desc.isEmpty {
                    line += " — \(desc)"
                }
                if !repo.topics.isEmpty {
                    line += " | Topics: \(repo.topics.prefix(5).joined(separator: ", "))"
                }
                sections.append(line)
            }
        }

        return sections.joined(separator: "\n")
    }
}

enum GitHubServiceError: LocalizedError {
    case invalidUsername
    case networkError(String)
    case rateLimited
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Enter a valid GitHub username."
        case .networkError(let detail):
            return "GitHub fetch failed: \(detail)"
        case .rateLimited:
            return "GitHub API rate limit reached. Try again in a few minutes."
        case .userNotFound:
            return "GitHub user not found. Check the username."
        }
    }
}

enum GitHubService {
    static func fetchProfile(username: String) async throws -> GitHubProfileSummary {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !trimmed.isEmpty, !trimmed.contains(" "), !trimmed.contains("/") else {
            throw GitHubServiceError.invalidUsername
        }

        async let userResponse = fetchJSON(
            from: "https://api.github.com/users/\(trimmed)"
        )
        async let reposResponse = fetchJSON(
            from: "https://api.github.com/users/\(trimmed)/repos?sort=pushed&per_page=30&type=owner"
        )

        let user = try await userResponse
        let repos = try await reposResponse

        guard let userDict = user as? [String: Any] else {
            throw GitHubServiceError.userNotFound
        }

        if userDict["message"] as? String == "Not Found" {
            throw GitHubServiceError.userNotFound
        }

        let repoArray = (repos as? [[String: Any]]) ?? []

        // Build repo summaries, sorted by stars then recent activity
        let repoSummaries: [GitHubProfileSummary.RepoSummary] = repoArray
            .filter { ($0["fork"] as? Bool) != true }
            .compactMap { repo in
                guard let name = repo["name"] as? String else { return nil }
                return GitHubProfileSummary.RepoSummary(
                    name: name,
                    description: repo["description"] as? String,
                    language: repo["language"] as? String,
                    stars: (repo["stargazers_count"] as? Int) ?? 0,
                    forks: (repo["forks_count"] as? Int) ?? 0,
                    topics: (repo["topics"] as? [String]) ?? [],
                    updatedAt: (repo["pushed_at"] as? String) ?? ""
                )
            }
            .sorted { lhs, rhs in
                if lhs.stars != rhs.stars { return lhs.stars > rhs.stars }
                return lhs.updatedAt > rhs.updatedAt
            }

        // Extract primary languages by frequency
        var languageCounts: [String: Int] = [:]
        for repo in repoSummaries {
            if let lang = repo.language, !lang.isEmpty {
                languageCounts[lang, default: 0] += 1
            }
        }
        let primaryLanguages = languageCounts
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map(\.key)

        // Take top 10 repos for the summary
        let topRepos = Array(repoSummaries.prefix(10))

        return GitHubProfileSummary(
            username: trimmed,
            displayName: userDict["name"] as? String,
            bio: userDict["bio"] as? String,
            publicRepoCount: (userDict["public_repos"] as? Int) ?? 0,
            followers: (userDict["followers"] as? Int) ?? 0,
            topRepos: topRepos,
            primaryLanguages: primaryLanguages
        )
    }

    private static func fetchJSON(from urlString: String) async throws -> Any {
        guard let url = URL(string: urlString) else {
            throw GitHubServiceError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("InterviewPilot/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubServiceError.networkError("No HTTP response")
        }

        if httpResponse.statusCode == 403 {
            throw GitHubServiceError.rateLimited
        }

        if httpResponse.statusCode == 404 {
            throw GitHubServiceError.userNotFound
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubServiceError.networkError("HTTP \(httpResponse.statusCode)")
        }

        return try JSONSerialization.jsonObject(with: data)
    }
}
