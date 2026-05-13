import Foundation

public struct SkillTriggerConflictPromptExporter: Sendable {
    public init() {}

    public func prompt(for conflict: SkillTriggerConflict, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            chinesePrompt(for: conflict)
        case .english:
            englishPrompt(for: conflict)
        }
    }

    private func chinesePrompt(for conflict: SkillTriggerConflict) -> String {
        """
        你是一个本地 agent 配置维护者。请处理下面这个 Skill 触发冲突。

        目标：
        1. 读取并比较两个 Skill 文件。
        2. 判断它们是否真的会抢同一类任务或误触发。
        3. 如果需要修改，优先收窄 description / trigger / name 的职责边界；不要直接删除文件，除非用户明确批准。
        4. 保持改动最小，避免影响无关 Skill、插件或命令。
        5. 完成后说明你做了什么、为什么这样做，以及是否还需要人工决定。

        冲突概览：
        - 风险等级：\(L10n.skillTriggerConflictSeverity(conflict.severity, language: .simplifiedChinese))
        - 置信度：\(Int(conflict.score * 100))%
        - 共同运行面：\(owners(conflict.sharedSurfaces, language: .simplifiedChinese))
        - 触发信号：\(signals(conflict, language: .simplifiedChinese))
        - 重叠词：\(terms(conflict.sharedTerms))

        主 Skill：
        \(assetBlock(conflict.primaryAsset, route: conflict.primaryRoute, language: .simplifiedChinese))

        竞争 Skill：
        \(assetBlock(conflict.competingAsset, route: conflict.competingRoute, language: .simplifiedChinese))

        建议处理方向：
        \(suggestion(for: conflict, language: .simplifiedChinese))

        \(outputFormat(language: .simplifiedChinese))
        """
    }

    private func englishPrompt(for conflict: SkillTriggerConflict) -> String {
        """
        You are maintaining local agent configuration. Please resolve the following Skill trigger conflict.

        Goals:
        1. Read and compare both Skill files.
        2. Decide whether they actually compete for the same task or can mis-trigger.
        3. If changes are needed, prefer narrowing description / trigger / name boundaries; do not delete files unless the user explicitly approves it.
        4. Keep the change minimal and avoid touching unrelated skills, plugins, or commands.
        5. When finished, explain what changed, why, and whether any human decision remains.

        Conflict overview:
        - Risk: \(L10n.skillTriggerConflictSeverity(conflict.severity, language: .english))
        - Confidence: \(Int(conflict.score * 100))%
        - Shared surfaces: \(owners(conflict.sharedSurfaces, language: .english))
        - Signals: \(signals(conflict, language: .english))
        - Shared terms: \(terms(conflict.sharedTerms))

        Primary Skill:
        \(assetBlock(conflict.primaryAsset, route: conflict.primaryRoute, language: .english))

        Competing Skill:
        \(assetBlock(conflict.competingAsset, route: conflict.competingRoute, language: .english))

        Suggested direction:
        \(suggestion(for: conflict, language: .english))

        \(outputFormat(language: .english))
        """
    }

    private func assetBlock(
        _ asset: AgentAsset,
        route: ContextLoadRoute,
        language: AppLanguage
    ) -> String {
        let fallback = language == .simplifiedChinese ? "未提供" : "Not provided"
        return """
        - Title: \(asset.title)
        - Path: \(asset.path)
        - Owner: \(L10n.agentOwner(asset.owner, language: language))
        - Skill source: \(L10n.skillInstallOrigin(route.skillInstallOrigin ?? .unknown, language: language))
        - Loaded into: \(L10n.loadDestination(route.destination, language: language))
        - How it loads: \(L10n.loadTrigger(route.trigger, language: language))
        - Summary: \(asset.summary.isEmpty ? fallback : asset.summary)
        - Trigger: \((asset.trigger ?? "").isEmpty ? fallback : asset.trigger!)
        """
    }

    private func owners(_ owners: [AgentOwner], language: AppLanguage) -> String {
        guard !owners.isEmpty else {
            return language == .simplifiedChinese ? "未知" : "Unknown"
        }
        return owners
            .map { $0 == .claude ? L10n.text(.claudeCode, language: language) : L10n.agentOwner($0, language: language) }
            .joined(separator: ", ")
    }

    private func signals(_ conflict: SkillTriggerConflict, language: AppLanguage) -> String {
        conflict.signals
            .map { L10n.skillTriggerConflictSignal($0, language: language) }
            .joined(separator: ", ")
    }

    private func terms(_ terms: [String]) -> String {
        terms.isEmpty ? "-" : terms.joined(separator: ", ")
    }

    private func suggestion(for conflict: SkillTriggerConflict, language: AppLanguage) -> String {
        if conflict.signals.contains(.userSkillOverlapsBundled) {
            return L10n.text(.triggerConflictSuggestionBundleOverlap, language: language)
        }
        if conflict.signals.contains(.sameName) {
            return L10n.text(.triggerConflictSuggestionSameName, language: language)
        }
        if conflict.signals.contains(.broadTrigger) || conflict.signals.contains(.sharedTriggerTerms) {
            return L10n.text(.triggerConflictSuggestionNarrow, language: language)
        }
        return L10n.text(.triggerConflictSuggestionGeneral, language: language)
    }

    private func outputFormat(language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            """
            处理结果输出格式：
            请严格按以下 Markdown 结构输出；如果某一项不适用，也要写“无”或说明未执行原因。

            ## 结论
            - 是否确认为真实触发冲突：
            - 最终处理策略：

            ## 文件处理明细
            - `path/to/file`：改动/未改动/需要人工确认；说明具体处理内容。
            - 如未改文件，说明原因。

            ## 验证
            - 已运行的命令或检查：
            - 结果：
            - 未运行验证时的原因：

            ## 剩余人工决策
            - 需要用户决定的事项；没有则写“无”。

            ## 风险与回滚
            - 可能的误触发/漏触发风险：
            - 如需回滚，应恢复哪些文件或改动：
            """
        case .english:
            """
            Required output format:
            Use the following Markdown structure exactly. If a section does not apply, write "None" or explain why it was not performed.

            ## Conclusion
            - Confirmed as a real trigger conflict:
            - Final handling strategy:

            ## File Handling Details
            - `path/to/file`: changed / unchanged / needs human confirmation; explain the concrete handling.
            - If no files changed, explain why.

            ## Verification
            - Commands or checks run:
            - Result:
            - If verification was not run, explain why:

            ## Remaining Human Decisions
            - Decisions the user still needs to make; write "None" if there are none.

            ## Risks and Rollback
            - Possible mis-trigger or missed-trigger risk:
            - Files or edits to restore if rollback is needed:
            """
        }
    }
}
