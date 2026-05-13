import Foundation

public enum SkillTriggerContractSectionKind: String, Codable, CaseIterable, Sendable {
    case trigger
    case responsibility
    case loading
}

public struct SkillTriggerContractSection: Codable, Hashable, Sendable {
    public let kind: SkillTriggerContractSectionKind
    public let title: String
    public let primaryText: String
    public let competingText: String
    public let sharedTerms: [String]
    public let takeaway: String

    public init(
        kind: SkillTriggerContractSectionKind,
        title: String,
        primaryText: String,
        competingText: String,
        sharedTerms: [String],
        takeaway: String
    ) {
        self.kind = kind
        self.title = title
        self.primaryText = primaryText
        self.competingText = competingText
        self.sharedTerms = sharedTerms
        self.takeaway = takeaway
    }
}

public struct SkillTriggerContractComparison: Codable, Hashable, Sendable {
    public let headline: String
    public let detail: String
    public let recommendedAction: String
    public let sections: [SkillTriggerContractSection]

    public init(
        headline: String,
        detail: String,
        recommendedAction: String,
        sections: [SkillTriggerContractSection]
    ) {
        self.headline = headline
        self.detail = detail
        self.recommendedAction = recommendedAction
        self.sections = sections
    }
}

public struct SkillTriggerContractComparator: Sendable {
    public init() {}

    public func comparison(
        for conflict: SkillTriggerConflict,
        language: AppLanguage
    ) -> SkillTriggerContractComparison {
        let primary = conflict.primaryAsset
        let competing = conflict.competingAsset

        return SkillTriggerContractComparison(
            headline: headline(for: conflict, language: language),
            detail: detail(for: conflict, language: language),
            recommendedAction: recommendedAction(for: conflict, language: language),
            sections: [
                triggerSection(for: conflict, language: language),
                responsibilitySection(primary: primary, competing: competing, language: language),
                loadingSection(for: conflict, language: language)
            ]
        )
    }

    private func headline(for conflict: SkillTriggerConflict, language: AppLanguage) -> String {
        let terms = conflict.sharedTerms.prefix(3).joined(separator: " / ")
        switch language {
        case .simplifiedChinese:
            if !terms.isEmpty {
                return "这两个 Skill 会覆盖同一类请求：\(terms)"
            }
            if conflict.signals.contains(.sameName) {
                return "这两个 Skill 的主题几乎相同"
            }
            return "这两个 Skill 可能会被同一类任务同时触发"
        case .english:
            if !terms.isEmpty {
                return "These skills cover the same request type: \(terms)"
            }
            if conflict.signals.contains(.sameName) {
                return "These skills describe nearly the same topic"
            }
            return "These skills may trigger for the same task"
        }
    }

    private func detail(for conflict: SkillTriggerConflict, language: AppLanguage) -> String {
        let risk = L10n.skillTriggerConflictSeverity(conflict.severity, language: language)
        let confidence = Int(conflict.score * 100)
        switch language {
        case .simplifiedChinese:
            return "\(risk) · \(confidence)% 置信度。先比较触发契约，再决定是否改名、收窄或归档。"
        case .english:
            return "\(risk) · \(confidence)% confidence. Compare the trigger contract before renaming, narrowing, or archiving."
        }
    }

    private func triggerSection(
        for conflict: SkillTriggerConflict,
        language: AppLanguage
    ) -> SkillTriggerContractSection {
        let primary = conflict.primaryAsset
        let competing = conflict.competingAsset
        let takeaway: String
        switch language {
        case .simplifiedChinese:
            takeaway = conflict.sharedTerms.isEmpty
                ? "触发文字相似度不高，但仍处在同一个运行面，需要人工确认。"
                : "这些重叠词会让 agent 在发现 Skill 时犹豫：\(conflict.sharedTerms.prefix(5).joined(separator: "、"))。"
        case .english:
            takeaway = conflict.sharedTerms.isEmpty
                ? "The trigger wording is not strongly similar, but the skills share a runtime surface and still need review."
                : "These shared terms can make skill discovery ambiguous: \(conflict.sharedTerms.prefix(5).joined(separator: ", "))."
        }

        return SkillTriggerContractSection(
            kind: .trigger,
            title: language == .simplifiedChinese ? "触发条件" : "Trigger Conditions",
            primaryText: triggerText(for: primary, language: language),
            competingText: triggerText(for: competing, language: language),
            sharedTerms: conflict.sharedTerms,
            takeaway: takeaway
        )
    }

    private func responsibilitySection(
        primary: AgentAsset,
        competing: AgentAsset,
        language: AppLanguage
    ) -> SkillTriggerContractSection {
        let takeaway: String
        switch language {
        case .simplifiedChinese:
            takeaway = "判断职责边界：如果一个负责原则/规范，另一个负责实现/工具，就应该把触发条件拆清楚。"
        case .english:
            takeaway = "Check ownership boundaries: if one skill owns principles and the other owns implementation, make that split explicit in the trigger."
        }

        return SkillTriggerContractSection(
            kind: .responsibility,
            title: language == .simplifiedChinese ? "职责边界" : "Responsibility Boundary",
            primaryText: responsibilityText(for: primary, language: language),
            competingText: responsibilityText(for: competing, language: language),
            sharedTerms: [],
            takeaway: takeaway
        )
    }

    private func loadingSection(
        for conflict: SkillTriggerConflict,
        language: AppLanguage
    ) -> SkillTriggerContractSection {
        let primaryRoute = routeText(for: conflict.primaryRoute, language: language)
        let competingRoute = routeText(for: conflict.competingRoute, language: language)
        let sharedSurfaces = owners(conflict.sharedSurfaces, language: language)
        let takeaway: String
        switch language {
        case .simplifiedChinese:
            takeaway = "\(sharedSurfaces) 会同时看到它们；共享或项目级 Skill 的影响面通常更大。"
        case .english:
            takeaway = "\(sharedSurfaces) can see both skills; shared or project-local skills usually have broader impact."
        }

        return SkillTriggerContractSection(
            kind: .loading,
            title: language == .simplifiedChinese ? "加载范围" : "Loading Scope",
            primaryText: primaryRoute,
            competingText: competingRoute,
            sharedTerms: [],
            takeaway: takeaway
        )
    }

    private func recommendedAction(for conflict: SkillTriggerConflict, language: AppLanguage) -> String {
        if conflict.signals.contains(.userSkillOverlapsBundled) {
            switch language {
            case .simplifiedChinese:
                return "优先收窄用户安装或共享 Skill 的触发条件；只有确认是重复维护时再归档。"
            case .english:
                return "Prefer narrowing the user-installed or shared skill trigger; archive only after confirming it is duplicate maintenance."
            }
        }

        if conflict.signals.contains(.sameName) {
            switch language {
            case .simplifiedChinese:
                return "保留一个权威入口，另一个改名或收窄到更具体场景。"
            case .english:
                return "Keep one authoritative entry point, then rename or narrow the other to a more specific scenario."
            }
        }

        if conflict.signals.contains(.broadTrigger) || conflict.signals.contains(.sharedTriggerTerms) {
            switch language {
            case .simplifiedChinese:
                return "把更宽的 Skill 收窄到具体工具、文件类型或任务阶段。"
            case .english:
                return "Narrow the broader skill to specific tools, file types, or task phases."
            }
        }

        switch language {
        case .simplifiedChinese:
            return "先人工确认真实使用场景，再决定是否调整。"
        case .english:
            return "Confirm the real usage scenarios before changing either skill."
        }
    }

    private func triggerText(for asset: AgentAsset, language: AppLanguage) -> String {
        compact(asset.trigger, fallback: asset.summary, emptyFallback: asset.title, language: language)
    }

    private func responsibilityText(for asset: AgentAsset, language: AppLanguage) -> String {
        compact(asset.summary, fallback: asset.trigger ?? "", emptyFallback: asset.title, language: language)
    }

    private func routeText(for route: ContextLoadRoute, language: AppLanguage) -> String {
        [
            owners(route.surfaces, language: language),
            L10n.skillInstallOrigin(route.skillInstallOrigin ?? .unknown, language: language),
            L10n.loadDestination(route.destination, language: language)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    private func owners(_ owners: [AgentOwner], language: AppLanguage) -> String {
        guard !owners.isEmpty else {
            return language == .simplifiedChinese ? "未知工具域" : "Unknown surface"
        }
        return owners
            .map { owner in
                owner == .claude ? L10n.text(.claudeCode, language: language) : L10n.agentOwner(owner, language: language)
            }
            .joined(separator: " + ")
    }

    private func compact(
        _ text: String?,
        fallback: String,
        emptyFallback: String,
        language: AppLanguage
    ) -> String {
        let raw = [text ?? "", fallback, emptyFallback]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        guard !raw.isEmpty else {
            return language == .simplifiedChinese ? "未提供" : "Not provided"
        }

        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > 180 else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 180)
        return String(collapsed[..<end]) + "..."
    }
}
