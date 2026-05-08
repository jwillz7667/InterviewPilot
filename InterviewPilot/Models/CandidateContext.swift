import Foundation

/// Structured personalization payload for AI prompts.
///
/// Built once per session from the user-selected `InterviewProfile` (or the account
/// `UserProfile` as fallback) and threaded into `PromptBuilder` alongside the resume
/// blob. The prompt builder renders this as dedicated, model-readable sections —
/// dramatically improving identity, project, and stack awareness over the legacy
/// `<user_resume>` text dump.
struct CandidateContext: Sendable, Equatable {
    let candidateName: String?
    let currentRole: String?
    let currentCompany: String?
    let yearsInRole: Int?
    let summary: String?
    let linkedinUrl: String?
    let primaryGoal: String?
    let projects: [Project]
    let topSkills: [String]

    struct Project: Sendable, Equatable, Hashable {
        let name: String
        let description: String?
        let techStack: String?
        let year: Int?
    }

    var hasIdentity: Bool {
        candidateName != nil || linkedinUrl != nil || currentRole != nil
    }

    var isEmpty: Bool {
        !hasIdentity && projects.isEmpty && topSkills.isEmpty && summary == nil && primaryGoal == nil
    }

    /// Returns the intersection of the candidate's listed skills with the role's
    /// required + preferred tech stack — case-insensitive, de-duplicated.
    func stackOverlap(with requirements: StructuredJobRequirements) -> [String] {
        let needle = Set(
            (requirements.requiredTechStack + requirements.preferredTechStack)
                .map { $0.lowercased() }
        )
        guard !needle.isEmpty else { return [] }

        var seen = Set<String>()
        var overlap: [String] = []
        for skill in topSkills {
            let key = skill.lowercased()
            if needle.contains(key) && !seen.contains(key) {
                seen.insert(key)
                overlap.append(skill)
            }
        }
        return overlap
    }

    /// Renders the structured `## Candidate Identity`, `## Candidate's Key Projects`,
    /// and `## Stack Match Signal` sections for inclusion in the system prompt.
    /// Returns an empty string if there is no usable personalization data.
    func promptSection(jobRequirements: StructuredJobRequirements?) -> String {
        var sections: [String] = []

        var identityLines: [String] = []
        if let candidateName, !candidateName.isEmpty {
            identityLines.append("Name: \(candidateName)")
        }
        if let currentRole, !currentRole.isEmpty {
            var line = "Currently a \(currentRole)"
            if let currentCompany, !currentCompany.isEmpty {
                line += " at \(currentCompany)"
            }
            if let yearsInRole, yearsInRole > 0 {
                line += " (\(yearsInRole) \(yearsInRole == 1 ? "year" : "years") in role)"
            }
            identityLines.append(line)
        }
        if let linkedinUrl, !linkedinUrl.isEmpty {
            identityLines.append("LinkedIn: \(linkedinUrl)")
        }
        if let summary, !summary.isEmpty {
            identityLines.append("Self-summary: \(summary)")
        }
        if let primaryGoal, !primaryGoal.isEmpty {
            identityLines.append("Career goal: \(primaryGoal)")
        }

        if !identityLines.isEmpty {
            sections.append("""
            ## Candidate Identity
            \(identityLines.joined(separator: "\n"))
            """)
        }

        if !projects.isEmpty {
            let formatted = projects.prefix(5).map { project -> String in
                var line = "- **\(project.name)**"
                if let description = project.description, !description.isEmpty {
                    line += ": \(description)"
                }
                if let techStack = project.techStack, !techStack.isEmpty {
                    line += " | Stack: \(techStack)"
                }
                if let year = project.year {
                    line += " (\(year))"
                }
                return line
            }.joined(separator: "\n")
            sections.append("""
            ## Candidate's Key Projects
            Use these exact project names when referencing — never paraphrase or abbreviate.
            \(formatted)
            """)
        }

        if let requirements = jobRequirements {
            let overlap = stackOverlap(with: requirements)
            if !overlap.isEmpty {
                sections.append("""
                ## Stack Match Signal
                The candidate has direct, listed experience in these technologies that this role requires or prefers: \(overlap.joined(separator: ", ")).
                When the question touches any of these, prefer examples that use them and reference the specific project where they were applied.
                """)
            }
        }

        return sections.joined(separator: "\n\n")
    }
}

extension CandidateContext {
    /// Builds a `CandidateContext` from the user-selected `InterviewProfile`, falling back
    /// to the account `UserProfile` and the `AuthService` display name for identity fields.
    /// Always returns a value — `isEmpty` indicates whether the prompt has anything to render.
    static func build(
        from interviewProfile: InterviewProfile?,
        accountProfile: UserProfile?,
        authDisplayName: String?
    ) -> CandidateContext {
        // "default" is the system-generated label for the auto-created profile and
        // must not be passed to the model as the candidate's actual name.
        let candidateName = firstNonEmpty(
            [interviewProfile?.name, accountProfile?.displayName, authDisplayName],
            disallow: ["default"]
        )

        let currentRole = firstNonEmpty([interviewProfile?.currentRole, accountProfile?.currentRole])
        let currentCompany = firstNonEmpty([interviewProfile?.currentCompany, accountProfile?.currentCompany])
        let yearsInRole = interviewProfile?.yearsInRole ?? accountProfile?.yearsInRole
        let linkedinUrl = firstNonEmpty([interviewProfile?.linkedinUrl, accountProfile?.linkedinUrl])
        let summary = firstNonEmpty([interviewProfile?.summary])
        let primaryGoal = firstNonEmpty([accountProfile?.primaryGoal])

        let projects = (interviewProfile?.projects ?? []).map {
            Project(name: $0.name, description: $0.description, techStack: $0.techStack, year: $0.year)
        }

        let interviewSkills = (interviewProfile?.skills ?? []).map(\.name)
        let accountSkills = (accountProfile?.skills ?? []).map(\.name)
        let topSkills = interviewSkills.isEmpty ? accountSkills : interviewSkills

        return CandidateContext(
            candidateName: candidateName,
            currentRole: currentRole,
            currentCompany: currentCompany,
            yearsInRole: yearsInRole,
            summary: summary,
            linkedinUrl: linkedinUrl,
            primaryGoal: primaryGoal,
            projects: projects,
            topSkills: topSkills
        )
    }

    private static func firstNonEmpty(_ candidates: [String?], disallow: [String] = []) -> String? {
        for raw in candidates {
            guard let raw else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if disallow.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                continue
            }
            return trimmed
        }
        return nil
    }
}
