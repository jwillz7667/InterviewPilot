import Foundation

/// Orchestrates the resume → profile autofill pipeline:
/// raw bytes → text extraction → LLM-structured profile → form-field merge.
///
/// The service is intentionally stateless and policy-driven. Callers pass
/// their existing form values, the service returns resolved values plus a
/// diagnostic `Report` describing what was filled, what was skipped, and why.
/// View models simply assign the resolved values back; no hidden mutation.
enum ResumeAutofillField: String, Sendable, Hashable, CaseIterable {
    case displayName, linkedInURL, currentRole, currentCompany, yearsInRole
    case summary, skills, workExperiences
}

enum ResumeAutofillSkipReason: Sendable {
    case userValuePresent
    case notExtracted
    case invalid(reason: String)
}

enum ResumeAutofillMergePolicy: Sendable {
    /// Default. Never overwrite a field the user has already typed into.
    case fillEmptyOnly
    /// Overwrite scalar fields with extracted values when present. Collections
    /// still merge additively (no destructive replacement of typed entries).
    case overwriteScalarsMergeCollections
}

struct ResumeAutofillInput: Sendable {
    let displayName: String
    let currentRole: String
    let currentCompany: String
    let yearsInRole: Int
    let linkedInURL: String
    let skills: [SkillEntry]
    let workExperiences: [WorkExperienceEntry]
}

struct ResumeAutofillOutput: Sendable {
    let resumeText: String
    let documentName: String
    let format: ResumeFileFormat
    let usedOCR: Bool
    let textCharacterCount: Int

    let displayName: String
    let currentRole: String
    let currentCompany: String
    let yearsInRole: Int
    let linkedInURL: String
    let summary: String?
    let skills: [SkillEntry]
    let workExperiences: [WorkExperienceEntry]

    let filledFields: Set<ResumeAutofillField>
    let skippedFields: [ResumeAutofillField: ResumeAutofillSkipReason]
}

enum ResumeAutofillService {

    /// Full pipeline from a file URL. Use this when the user picks a file.
    static func autofill(
        from url: URL,
        existing: ResumeAutofillInput,
        policy: ResumeAutofillMergePolicy = .fillEmptyOnly
    ) async throws -> ResumeAutofillOutput {
        let extracted = try await ResumeTextExtractor.extract(from: url)
        return try await autofill(
            text: extracted.text,
            extraction: extracted,
            documentName: url.lastPathComponent,
            existing: existing,
            policy: policy
        )
    }

    /// Full pipeline from raw bytes (e.g., when the file URL has already been
    /// consumed and we only have the buffered data).
    static func autofill(
        from data: Data,
        filename: String,
        existing: ResumeAutofillInput,
        policy: ResumeAutofillMergePolicy = .fillEmptyOnly
    ) async throws -> ResumeAutofillOutput {
        let extracted = try await ResumeTextExtractor.extract(from: data, filename: filename)
        return try await autofill(
            text: extracted.text,
            extraction: extracted,
            documentName: filename,
            existing: existing,
            policy: policy
        )
    }

    /// Runs only the LLM + merge stages. Used when the user pastes text
    /// directly and already has it in `resumeText`.
    static func autofillFromText(
        _ text: String,
        documentName: String = "Pasted resume",
        existing: ResumeAutofillInput,
        policy: ResumeAutofillMergePolicy = .fillEmptyOnly
    ) async throws -> ResumeAutofillOutput {
        let stub = ResumeTextExtractor.Result(
            text: text,
            format: .plainText,
            pageCount: nil,
            usedOCR: false
        )
        return try await autofill(
            text: text,
            extraction: stub,
            documentName: documentName,
            existing: existing,
            policy: policy
        )
    }

    // MARK: - Private pipeline

    private static func autofill(
        text: String,
        extraction: ResumeTextExtractor.Result,
        documentName: String,
        existing: ResumeAutofillInput,
        policy: ResumeAutofillMergePolicy
    ) async throws -> ResumeAutofillOutput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ResumeTextExtractor.Failure.empty }

        try Task.checkCancellation()

        let extracted: ExtractedProfile
        do {
            extracted = try await ResumeProfileExtractor.extract(from: trimmed)
        } catch is CancellationError {
            throw ResumeTextExtractor.Failure.cancelled
        }

        try Task.checkCancellation()

        let regexLinkedIn = ResumeRegex.firstLinkedInURL(in: trimmed)

        return merge(
            input: existing,
            extracted: extracted,
            regexLinkedIn: regexLinkedIn,
            text: trimmed,
            extraction: extraction,
            documentName: documentName,
            policy: policy
        )
    }

    // MARK: - Merge (pure)

    static func merge(
        input: ResumeAutofillInput,
        extracted: ExtractedProfile,
        regexLinkedIn: String?,
        text: String,
        extraction: ResumeTextExtractor.Result,
        documentName: String,
        policy: ResumeAutofillMergePolicy
    ) -> ResumeAutofillOutput {
        var filled = Set<ResumeAutofillField>()
        var skipped: [ResumeAutofillField: ResumeAutofillSkipReason] = [:]

        let displayName = mergeScalar(
            field: .displayName,
            existing: input.displayName,
            candidate: ResumeSanitizer.sanitizeName(extracted.displayName),
            policy: policy,
            filled: &filled,
            skipped: &skipped
        )

        let currentRole = mergeScalar(
            field: .currentRole,
            existing: input.currentRole,
            candidate: ResumeSanitizer.sanitizeShort(extracted.currentRole, maxLength: 120),
            policy: policy,
            filled: &filled,
            skipped: &skipped
        )

        let currentCompany = mergeScalar(
            field: .currentCompany,
            existing: input.currentCompany,
            candidate: ResumeSanitizer.sanitizeShort(extracted.currentCompany, maxLength: 120),
            policy: policy,
            filled: &filled,
            skipped: &skipped
        )

        // Years in role: validate plausibility (0–60), treat existing 0 as "unset".
        let candidateYears = ResumeSanitizer.sanitizeYearsInRole(extracted.yearsInRole)
        let yearsInRole: Int
        switch (input.yearsInRole, candidateYears, policy) {
        case (0, .some(let y), _):
            yearsInRole = y
            filled.insert(.yearsInRole)
        case (_, .some(let y), .overwriteScalarsMergeCollections):
            yearsInRole = y
            filled.insert(.yearsInRole)
        case (let existing, _, _) where existing > 0:
            yearsInRole = existing
            if candidateYears == nil {
                skipped[.yearsInRole] = .notExtracted
            } else {
                skipped[.yearsInRole] = .userValuePresent
            }
        case (_, .none, _):
            yearsInRole = input.yearsInRole
            skipped[.yearsInRole] = .notExtracted
        default:
            yearsInRole = input.yearsInRole
        }

        // LinkedIn: prefer regex (verbatim, never hallucinated) over LLM.
        let linkedInCandidate = ResumeSanitizer.sanitizeLinkedIn(regexLinkedIn)
            ?? ResumeSanitizer.sanitizeLinkedIn(extracted.linkedinUrl)

        let linkedInURL = mergeScalar(
            field: .linkedInURL,
            existing: input.linkedInURL,
            candidate: linkedInCandidate,
            policy: policy,
            filled: &filled,
            skipped: &skipped
        )

        let summary = ResumeSanitizer.sanitizeSummary(extracted.summary)
        if summary != nil {
            filled.insert(.summary)
        } else {
            skipped[.summary] = .notExtracted
        }

        // Skills: additive merge, dedupe by canonical name; preserve user order.
        let mergedSkills = mergeSkills(existing: input.skills, extracted: extracted.skills)
        let addedSkills = mergedSkills.count - input.skills.count
        if addedSkills > 0 {
            filled.insert(.skills)
        } else if extracted.skills.isEmpty {
            skipped[.skills] = .notExtracted
        }

        // Work experiences: additive merge, dedupe by (company+title+startYear).
        let mergedExperiences = mergeExperiences(
            existing: input.workExperiences,
            extracted: extracted.workExperiences
        )
        let addedExperiences = mergedExperiences.count - input.workExperiences.count
        if addedExperiences > 0 {
            filled.insert(.workExperiences)
        } else if extracted.workExperiences.isEmpty {
            skipped[.workExperiences] = .notExtracted
        }

        return ResumeAutofillOutput(
            resumeText: text,
            documentName: documentName,
            format: extraction.format,
            usedOCR: extraction.usedOCR,
            textCharacterCount: text.count,
            displayName: displayName,
            currentRole: currentRole,
            currentCompany: currentCompany,
            yearsInRole: yearsInRole,
            linkedInURL: linkedInURL,
            summary: summary,
            skills: mergedSkills,
            workExperiences: mergedExperiences,
            filledFields: filled,
            skippedFields: skipped
        )
    }

    private static func mergeScalar(
        field: ResumeAutofillField,
        existing: String,
        candidate: String?,
        policy: ResumeAutofillMergePolicy,
        filled: inout Set<ResumeAutofillField>,
        skipped: inout [ResumeAutofillField: ResumeAutofillSkipReason]
    ) -> String {
        let existingTrim = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExisting = !existingTrim.isEmpty

        switch policy {
        case .fillEmptyOnly:
            if !hasExisting, let candidate {
                filled.insert(field)
                return candidate
            }
            if hasExisting {
                skipped[field] = .userValuePresent
                return existing
            }
            skipped[field] = .notExtracted
            return existing
        case .overwriteScalarsMergeCollections:
            if let candidate {
                filled.insert(field)
                return candidate
            }
            skipped[field] = .notExtracted
            return existing
        }
    }

    private static func mergeSkills(
        existing: [SkillEntry],
        extracted: [ExtractedSkill]
    ) -> [SkillEntry] {
        var seen = Set(existing.map { canonicalize($0.name) })
        var result = existing
        for skill in extracted {
            guard let cleaned = ResumeSanitizer.sanitizeSkill(skill.name) else { continue }
            let key = canonicalize(cleaned)
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(SkillEntry(name: cleaned))
        }
        return result
    }

    private static func mergeExperiences(
        existing: [WorkExperienceEntry],
        extracted: [ExtractedExperience]
    ) -> [WorkExperienceEntry] {
        var seen = Set(existing.map { experienceKey(title: $0.title, company: $0.company, startYear: $0.startYear) })
        var result = existing
        for exp in extracted {
            guard let entry = ResumeSanitizer.sanitizeExperience(exp) else { continue }
            let key = experienceKey(title: entry.title, company: entry.company, startYear: entry.startYear)
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(entry)
        }
        // Sort by startYear desc, current-role first.
        return result.sorted { lhs, rhs in
            let lEnd = lhs.endYear ?? Int.max
            let rEnd = rhs.endYear ?? Int.max
            if lEnd != rEnd { return lEnd > rEnd }
            return lhs.startYear > rhs.startYear
        }
    }

    private static func canonicalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: .punctuationCharacters).joined()
            .components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private static func experienceKey(title: String, company: String, startYear: Int) -> String {
        "\(canonicalize(title))::\(canonicalize(company))::\(startYear)"
    }
}

// MARK: - Sanitizers (pure)

enum ResumeSanitizer {

    static func sanitizeName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Reject lines that look like URLs, emails, or addresses — those are
        // not names and indicate the LLM grabbed the wrong row.
        if trimmed.contains("@") || trimmed.contains("://") || trimmed.contains("www.") { return nil }
        // Names should be ≤ 80 chars, ≤ 6 tokens.
        guard trimmed.count <= 80 else { return nil }
        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard tokens.count <= 6 else { return nil }
        // At least one alphabetic character.
        guard trimmed.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }
        return trimmed
    }

    static func sanitizeShort(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maxLength else {
            let idx = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
            return String(trimmed[..<idx])
        }
        return trimmed
    }

    static func sanitizeYearsInRole(_ raw: Int?) -> Int? {
        guard let raw else { return nil }
        guard raw > 0, raw <= 60 else { return nil }
        return raw
    }

    static func sanitizeSummary(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20, trimmed.count <= 1200 else { return nil }
        return trimmed
    }

    /// Normalizes a LinkedIn URL to `https://www.linkedin.com/in/<slug>` form.
    static func sanitizeLinkedIn(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>().,;\"'"))
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        guard lowered.contains("linkedin.com") else { return nil }

        var url = trimmed
        if !lowered.hasPrefix("http://") && !lowered.hasPrefix("https://") {
            url = "https://" + url
        }
        // Force https + www for canonical form.
        url = url.replacingOccurrences(of: "http://", with: "https://", options: .anchored)
        if !url.lowercased().contains("://www.") {
            url = url.replacingOccurrences(of: "://linkedin.com", with: "://www.linkedin.com")
        }
        // Ensure it parses as a URL.
        guard URL(string: url) != nil else { return nil }
        // Cap pathological lengths.
        guard url.count <= 200 else { return nil }
        return url
    }

    static func sanitizeSkill(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= 60 else { return nil }
        // Reject skills that are full sentences (likely description fragments).
        let wordCount = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount <= 8 else { return nil }
        return trimmed
    }

    static func sanitizeExperience(_ exp: ExtractedExperience) -> WorkExperienceEntry? {
        let title = exp.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = exp.company.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !company.isEmpty else { return nil }
        guard title.count <= 120, company.count <= 120 else { return nil }

        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        guard exp.startYear >= 1950, exp.startYear <= currentYear + 1 else { return nil }

        let endYear: Int?
        if let raw = exp.endYear {
            guard raw >= exp.startYear, raw <= currentYear + 1 else {
                endYear = nil  // treat implausible end as "current"
                return WorkExperienceEntry(title: title, company: company, startYear: exp.startYear, endYear: nil)
            }
            endYear = raw
        } else {
            endYear = nil
        }
        return WorkExperienceEntry(title: title, company: company, startYear: exp.startYear, endYear: endYear)
    }
}

// MARK: - Regex helpers

enum ResumeRegex {
    /// Matches a LinkedIn URL anywhere in the resume text. Handles common
    /// variations: with/without scheme, with/without www, in or out of
    /// parentheses. Returns the raw matched substring (callers should run it
    /// through `ResumeSanitizer.sanitizeLinkedIn` before assigning).
    static func firstLinkedInURL(in text: String) -> String? {
        let pattern = #"(?i)\b(?:https?://)?(?:www\.)?linkedin\.com/(?:in|pub)/[A-Za-z0-9\-_%/.]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }
}
