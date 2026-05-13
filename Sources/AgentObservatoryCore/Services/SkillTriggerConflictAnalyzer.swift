import Foundation

public struct SkillTriggerConflictAnalyzer: Sendable {
    private let loadAnalyzer: ContextLoadAnalyzer

    public init(loadAnalyzer: ContextLoadAnalyzer = ContextLoadAnalyzer()) {
        self.loadAnalyzer = loadAnalyzer
    }

    public func conflicts(assets: [AgentAsset], limit: Int = 80) -> [SkillTriggerConflict] {
        let candidates = assets
            .filter { $0.kind == .skill }
            .map { asset in
                SkillTriggerCandidate(
                    asset: asset,
                    route: loadAnalyzer.route(for: asset),
                    profile: SkillTriggerProfile(asset: asset)
                )
            }

        guard candidates.count > 1 else { return [] }

        var conflicts: [SkillTriggerConflict] = []

        for leftIndex in candidates.indices {
            for rightIndex in candidates.index(after: leftIndex)..<candidates.endIndex {
                let left = candidates[leftIndex]
                let right = candidates[rightIndex]

                guard shouldCompare(left, right),
                      let conflict = conflict(left, right) else {
                    continue
                }

                conflicts.append(conflict)
            }
        }

        return conflicts
            .sorted(by: conflictSort)
            .prefix(limit)
            .map { $0 }
    }

    private func shouldCompare(_ left: SkillTriggerCandidate, _ right: SkillTriggerCandidate) -> Bool {
        if left.asset.path == right.asset.path {
            return false
        }

        let leftBundled = left.route.skillInstallOrigin?.isBundled == true
        let rightBundled = right.route.skillInstallOrigin?.isBundled == true
        if leftBundled && rightBundled {
            return false
        }

        let leftSurfaces = Set(left.route.surfaces)
        let rightSurfaces = Set(right.route.surfaces)
        return !leftSurfaces.isDisjoint(with: rightSurfaces)
    }

    private func conflict(
        _ left: SkillTriggerCandidate,
        _ right: SkillTriggerCandidate
    ) -> SkillTriggerConflict? {
        let titleSimilarity = jaccard(left.profile.titleTokens, right.profile.titleTokens)
        let triggerSimilarity = jaccard(left.profile.triggerTokens, right.profile.triggerTokens)
        let summarySimilarity = jaccard(left.profile.allTokens, right.profile.allTokens)
        let exactName = !left.profile.normalizedTitle.isEmpty
            && left.profile.normalizedTitle == right.profile.normalizedTitle
        let sharedTerms = importantSharedTerms(left.profile.triggerTokens, right.profile.triggerTokens)
        let broadTrigger = left.profile.isBroad || right.profile.isBroad
        let userOverlapsBundled = userSkillOverlapsBundled(left, right)

        var signals: [SkillTriggerConflictSignal] = [.sharedRuntimeSurface]
        if exactName || titleSimilarity >= 0.80 {
            signals.append(.sameName)
        }
        if triggerSimilarity >= 0.30 || sharedTerms.count >= 4 {
            signals.append(.sharedTriggerTerms)
        }
        if summarySimilarity >= 0.64 && sharedTerms.count >= 3 {
            signals.append(.duplicateSummary)
        }
        if broadTrigger {
            signals.append(.broadTrigger)
        }
        if userOverlapsBundled {
            signals.append(.userSkillOverlapsBundled)
        }

        var score = max(titleSimilarity * 0.58, triggerSimilarity * 0.72, summarySimilarity * 0.48)
        if exactName {
            score += 0.30
        }
        if sharedTerms.count >= 5 {
            score += 0.12
        } else if sharedTerms.count >= 3 {
            score += 0.07
        }
        if userOverlapsBundled {
            score += 0.08
            if sharedTerms.count >= 4 {
                score += 0.08
            }
        }
        if broadTrigger {
            score += left.profile.isBroad && right.profile.isBroad ? 0.09 : 0.04
        }
        score += min(Double(sharedSurfaceCount(left, right)) * 0.03, 0.06)
        score = min(score, 1.0)

        guard let severity = severity(
            score: score,
            exactName: exactName,
            titleSimilarity: titleSimilarity,
            sharedTerms: sharedTerms,
            broadTrigger: broadTrigger,
            userOverlapsBundled: userOverlapsBundled
        ) else {
            return nil
        }

        let ordered = primaryFirst(left, right)
        return SkillTriggerConflict(
            id: conflictID(ordered.primary.asset, ordered.competitor.asset),
            severity: severity,
            score: rounded(score),
            primaryAsset: ordered.primary.asset,
            competingAsset: ordered.competitor.asset,
            primaryRoute: ordered.primary.route,
            competingRoute: ordered.competitor.route,
            sharedTerms: sharedTerms,
            signals: signals
        )
    }

    private func severity(
        score: Double,
        exactName: Bool,
        titleSimilarity: Double,
        sharedTerms: [String],
        broadTrigger: Bool,
        userOverlapsBundled: Bool
    ) -> SkillTriggerConflictSeverity? {
        if exactName || score >= 0.74 || (userOverlapsBundled && titleSimilarity >= 0.60 && score >= 0.55) {
            return .high
        }
        if score >= 0.48 || sharedTerms.count >= 5 || (userOverlapsBundled && sharedTerms.count >= 3 && score >= 0.42) {
            return .medium
        }
        if score >= 0.36 && (broadTrigger || userOverlapsBundled || sharedTerms.count >= 3) {
            return .low
        }
        return nil
    }

    private func primaryFirst(
        _ left: SkillTriggerCandidate,
        _ right: SkillTriggerCandidate
    ) -> (primary: SkillTriggerCandidate, competitor: SkillTriggerCandidate) {
        let leftRank = actionabilityRank(left)
        let rightRank = actionabilityRank(right)
        if leftRank != rightRank {
            return leftRank < rightRank ? (left, right) : (right, left)
        }

        if left.profile.broadnessScore != right.profile.broadnessScore {
            return left.profile.broadnessScore > right.profile.broadnessScore ? (left, right) : (right, left)
        }

        return left.asset.title.localizedStandardCompare(right.asset.title) == .orderedAscending
            ? (left, right)
            : (right, left)
    }

    private func actionabilityRank(_ candidate: SkillTriggerCandidate) -> Int {
        switch candidate.route.skillInstallOrigin {
        case .projectLocal:
            0
        case .userInstalled, .unknown, .none:
            1
        case .officialPlugin:
            2
        case .preset:
            3
        }
    }

    private func userSkillOverlapsBundled(
        _ left: SkillTriggerCandidate,
        _ right: SkillTriggerCandidate
    ) -> Bool {
        let leftBundled = left.route.skillInstallOrigin?.isBundled == true
        let rightBundled = right.route.skillInstallOrigin?.isBundled == true
        return leftBundled != rightBundled
    }

    private func sharedSurfaceCount(_ left: SkillTriggerCandidate, _ right: SkillTriggerCandidate) -> Int {
        Set(left.route.surfaces).intersection(Set(right.route.surfaces)).count
    }

    private func conflictSort(_ left: SkillTriggerConflict, _ right: SkillTriggerConflict) -> Bool {
        if left.severity.sortIndex != right.severity.sortIndex {
            return left.severity.sortIndex < right.severity.sortIndex
        }
        if left.score != right.score {
            return left.score > right.score
        }
        return left.primaryAsset.title.localizedStandardCompare(right.primaryAsset.title) == .orderedAscending
    }

    private func conflictID(_ left: AgentAsset, _ right: AgentAsset) -> String {
        [left.path, right.path]
            .sorted()
            .joined(separator: "::")
    }

    private func importantSharedTerms(_ left: Set<String>, _ right: Set<String>) -> [String] {
        left
            .intersection(right)
            .filter { !SkillTriggerProfile.genericTerms.contains($0) }
            .sorted { leftTerm, rightTerm in
                if leftTerm.count != rightTerm.count {
                    return leftTerm.count > rightTerm.count
                }
                return leftTerm < rightTerm
            }
            .prefix(8)
            .map { $0 }
    }

    private func jaccard(_ left: Set<String>, _ right: Set<String>) -> Double {
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let intersection = Double(left.intersection(right).count)
        let union = Double(left.union(right).count)
        guard union > 0 else { return 0 }
        return intersection / union
    }

    private func rounded(_ score: Double) -> Double {
        (score * 100).rounded() / 100
    }
}

private struct SkillTriggerCandidate {
    let asset: AgentAsset
    let route: ContextLoadRoute
    let profile: SkillTriggerProfile
}

private struct SkillTriggerProfile {
    static let genericTerms: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "can", "code",
        "for", "from", "has", "in", "into", "is", "it", "its", "of",
        "on", "or", "that", "the", "their", "this", "to", "use", "used",
        "using", "when", "with", "you", "your", "agent", "agents", "skill",
        "skills", "file", "files", "task", "tasks", "work", "workflow",
        "should", "must", "will", "all", "any", "create", "build", "make",
        "help", "helps", "guide", "guides", "user", "users", "project",
        "local", "source", "sources", "prompt", "prompts", "context",
        "description", "selected", "matches", "overview", "before", "after",
        "current", "existing", "required", "require", "requires", "provide",
        "provides", "provided", "guidance", "reference", "references",
        "instruction", "instructions",
        "ask", "asks", "want", "wants", "need", "needs", "mention", "mentions",
        "discuss", "discusses", "auto", "case", "set", "setup", "up", "what",
        "how", "without", "first", "common", "best",
        "the", "and", "or", "for", "with", "使用", "当", "用于", "这个",
        "这些", "文件", "项目", "任务", "能力"
    ]

    private static let broadTerms: Set<String> = [
        "all", "any", "general", "every", "whenever", "always", "create",
        "build", "implement", "write", "debug", "fix", "review", "analyze",
        "design", "refactor", "test", "frontend", "backend", "agent", "app",
        "code", "project", "workflow", "tool", "tools", "自动", "所有", "任何",
        "开发", "调试", "实现", "审查", "设计"
    ]

    let normalizedTitle: String
    let titleTokens: Set<String>
    let triggerTokens: Set<String>
    let allTokens: Set<String>
    let broadnessScore: Int

    init(asset: AgentAsset) {
        let title = asset.title
        let triggerText = [
            asset.trigger ?? "",
            asset.summary
        ]
        .joined(separator: "\n")

        normalizedTitle = Self.normalizedTitle(title)
        titleTokens = Self.titleTokens(title)
        triggerTokens = Self.tokens(triggerText)
        allTokens = Self.tokens(triggerText).union(Self.titleTokens(title))
        broadnessScore = triggerTokens.intersection(Self.broadTerms).count
    }

    var isBroad: Bool {
        broadnessScore >= 4 || (broadnessScore >= 2 && triggerTokens.count <= 24)
    }

    private static func normalizedTitle(_ title: String) -> String {
        let rawTokens = titleTokens(title).sorted()
        let trimmedTokens = rawTokens
            .filter { !["skill", "prompt", "template", "agent", "workflow"].contains($0) }
        let tokens = trimmedTokens.count >= 2 ? trimmedTokens : rawTokens
        return tokens.joined(separator: " ")
    }

    private static func titleTokens(_ text: String) -> Set<String> {
        Set(
            rawTokens(text)
                .filter { !["a", "an", "and", "for", "of", "the", "to", "with"].contains($0) }
        )
    }

    private static func tokens(_ text: String) -> Set<String> {
        Set(rawTokens(text).filter { !genericTerms.contains($0) })
    }

    private static func rawTokens(_ text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 2 }
        )
    }
}
