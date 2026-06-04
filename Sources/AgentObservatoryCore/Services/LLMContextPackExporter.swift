import Foundation

public enum LLMContextPackPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case currentView
    case selectedItem
    case migrationCleanup

    public var id: String { rawValue }
}

public enum LLMContextPackTarget: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case codex
    case claudeCode

    public var id: String { rawValue }
}

public enum LLMContextPackPathStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case abbreviated
    case full
    case redactedUser

    public var id: String { rawValue }
}

public enum LLMContextPackDetailLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case summary
    case snippets

    public var id: String { rawValue }
}

public struct LLMContextPackOptions: Codable, Hashable, Sendable {
    public var preset: LLMContextPackPreset
    public var target: LLMContextPackTarget
    public var language: AppLanguage
    public var pathStyle: LLMContextPackPathStyle
    public var detailLevel: LLMContextPackDetailLevel
    public var itemLimit: Int
    public var generatedAt: Date

    public init(
        preset: LLMContextPackPreset,
        target: LLMContextPackTarget = .general,
        language: AppLanguage = .english,
        pathStyle: LLMContextPackPathStyle = .abbreviated,
        detailLevel: LLMContextPackDetailLevel = .snippets,
        itemLimit: Int = 5,
        generatedAt: Date = Date()
    ) {
        self.preset = preset
        self.target = target
        self.language = language
        self.pathStyle = pathStyle
        self.detailLevel = detailLevel
        self.itemLimit = max(1, min(30, itemLimit))
        self.generatedAt = generatedAt
    }
}

public struct LLMContextPackExporter: Sendable {
    public init() {}

    public func markdown(
        scopeTitle: String,
        visibleAssets: [AgentAsset],
        contextItems: [ContextCatalogItem],
        selectedAsset: AgentAsset?,
        organizerRun: OrganizerRun,
        skillTriggerConflicts: [SkillTriggerConflict],
        options: LLMContextPackOptions
    ) -> String {
        let uniqueContextItems = uniqueItems(contextItems)
        let uniqueAssets = uniqueAssets(visibleAssets.isEmpty ? uniqueContextItems.map(\.asset) : visibleAssets)

        switch options.preset {
        case .currentView:
            return currentViewMarkdown(
                scopeTitle: scopeTitle,
                assets: uniqueAssets,
                contextItems: uniqueContextItems,
                options: options
            )
        case .selectedItem:
            return selectedItemMarkdown(
                scopeTitle: scopeTitle,
                selectedAsset: selectedAsset ?? uniqueAssets.first ?? uniqueContextItems.first?.asset,
                contextItems: uniqueContextItems,
                options: options
            )
        case .migrationCleanup:
            return migrationCleanupMarkdown(
                scopeTitle: scopeTitle,
                contextItems: uniqueContextItems,
                organizerRun: organizerRun,
                skillTriggerConflicts: skillTriggerConflicts,
                options: options
            )
        }
    }

    private func currentViewMarkdown(
        scopeTitle: String,
        assets: [AgentAsset],
        contextItems: [ContextCatalogItem],
        options: LLMContextPackOptions
    ) -> String {
        let rankedItems = rankedContextItems(contextItems)
        let ownerSections = Dictionary(grouping: rankedItems, by: { $0.asset.owner })
            .map { owner, items in
                LLMContextOwnerSection(owner: owner, items: items, tokenTotal: items.reduce(0) { $0 + estimatedTokenCount(for: $1) })
            }
            .sorted(by: ownerSectionSort)
        let tokenTotal = max(1, ownerSections.reduce(0) { $0 + $1.tokenTotal })

        return sections([
            header(title: text("Agent Observatory Context Pack", "Agent Observatory 上下文包", options.language), scopeTitle: scopeTitle, options: options),
            requestForLLM(options: options),
            requiredOutputFormat(language: options.language),
            contextSummary(
                assets: assets,
                contextItems: contextItems,
                tokenTotal: tokenTotal,
                options: options
            ),
            rankedByApplication(sections: ownerSections, totalTokens: tokenTotal, options: options),
            evidenceSnippets(items: rankedItems, options: options),
            safetyNotes(language: options.language)
        ])
    }

    private func selectedItemMarkdown(
        scopeTitle: String,
        selectedAsset: AgentAsset?,
        contextItems: [ContextCatalogItem],
        options: LLMContextPackOptions
    ) -> String {
        guard let selectedAsset else {
            return sections([
                header(title: text("Agent Observatory Selected Item Pack", "Agent Observatory 选中项上下文包", options.language), scopeTitle: scopeTitle, options: options),
                requestForLLM(options: options),
                requiredOutputFormat(language: options.language),
                text("No selected item is available in the current view.", "当前视图没有可导出的选中项。", options.language),
                safetyNotes(language: options.language)
            ])
        }

        let matchingItems = contextItems.filter { $0.asset.id == selectedAsset.id || $0.asset.path == selectedAsset.path }

        return sections([
            header(title: text("Agent Observatory Selected Item Pack", "Agent Observatory 选中项上下文包", options.language), scopeTitle: scopeTitle, options: options),
            requestForLLM(options: options),
            requiredOutputFormat(language: options.language),
            selectedAssetBlock(selectedAsset, matchingItems: matchingItems, options: options),
            safetyNotes(language: options.language)
        ])
    }

    private func migrationCleanupMarkdown(
        scopeTitle: String,
        contextItems: [ContextCatalogItem],
        organizerRun: OrganizerRun,
        skillTriggerConflicts: [SkillTriggerConflict],
        options: LLMContextPackOptions
    ) -> String {
        let memoryGroups = MemoryMigrationPlanner().groups(items: contextItems)
        let oneSidedGroups = memoryGroups.filter { $0.status == .claudeOnly || $0.status == .codexOnly }

        return sections([
            header(title: text("Agent Observatory Migration and Cleanup Pack", "Agent Observatory 迁移与清理上下文包", options.language), scopeTitle: scopeTitle, options: options),
            migrationRequestForLLM(language: options.language),
            requiredOutputFormat(language: options.language),
            migrationSummary(memoryGroups: memoryGroups, oneSidedGroups: oneSidedGroups, organizerRun: organizerRun, skillTriggerConflicts: skillTriggerConflicts, options: options),
            oneSidedMemorySection(groups: oneSidedGroups, options: options),
            cleanupDiagnosisSection(run: organizerRun, options: options),
            triggerConflictSection(conflicts: skillTriggerConflicts, options: options),
            safetyNotes(language: options.language)
        ])
    }

    private func header(title: String, scopeTitle: String, options: LLMContextPackOptions) -> String {
        """
        # \(title)

        - \(field("Generated", language: options.language)): \(generatedAtText(options.generatedAt))
        - \(field("Scope", language: options.language)): \(scopeTitle)
        - \(field("Preset", language: options.language)): \(presetTitle(options.preset, language: options.language))
        - \(field("Target", language: options.language)): \(targetTitle(options.target, language: options.language))
        - \(field("Path style", language: options.language)): \(pathStyleTitle(options.pathStyle, language: options.language))
        - \(field("Detail", language: options.language)): \(detailLevelTitle(options.detailLevel, language: options.language))
        """
    }

    private func requestForLLM(options: LLMContextPackOptions) -> String {
        switch options.language {
        case .simplifiedChinese:
            return """
            ## 给 LLM 的请求

            请基于下面的真实本地上下文进行分析。不要编造不存在的路径、文件或配置；如果信息不足，请明确指出缺口。
            \(targetInstruction(options.target, language: options.language))
            """
        case .english:
            return """
            ## Request For LLM

            Analyze the real local context below. Do not invent paths, files, or configuration that are not present here. If evidence is insufficient, call that out explicitly.
            \(targetInstruction(options.target, language: options.language))
            """
        }
    }

    private func migrationRequestForLLM(language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return """
            ## 给 LLM 的请求

            请判断哪些单边记忆、重复上下文或高风险项值得迁移、收敛或人工复核。不要直接建议覆盖文件；目标文件已存在时，应优先说明为什么不复制或需要人工确认。
            """
        case .english:
            return """
            ## Request For LLM

            Decide which one-sided memories, duplicate context items, or high-risk entries deserve migration, consolidation, or human review. Do not recommend overwriting files by default; when a destination already exists, explain why copying should be skipped or manually confirmed.
            """
        }
    }

    private func requiredOutputFormat(language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return """
            ## 处理结果输出格式

            请严格按以下 Markdown 结构输出：

            1. Summary
            2. Findings
            3. Recommended Actions
            4. Risks
            5. Exact File Operations, if any

            如果没有实际文件操作，请在第 5 项写“无”，并说明原因。
            """
        case .english:
            return """
            ## Required Output Format

            Use the following Markdown structure exactly:

            1. Summary
            2. Findings
            3. Recommended Actions
            4. Risks
            5. Exact File Operations, if any

            If no file operation is appropriate, write "None" in section 5 and explain why.
            """
        }
    }

    private func contextSummary(
        assets: [AgentAsset],
        contextItems: [ContextCatalogItem],
        tokenTotal: Int,
        options: LLMContextPackOptions
    ) -> String {
        let ownerCounts = Dictionary(grouping: assets, by: \.owner)
        let kindCounts = Dictionary(grouping: assets, by: \.kind)
        let promptItems = contextItems.filter { $0.loadRoute.destination.isPromptMaterial }.count
        let registryItems = max(0, contextItems.count - promptItems)
        let topOwner = ownerCounts
            .map { (owner: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return ownerSortIndex($0.owner) < ownerSortIndex($1.owner)
            }
            .first

        let ownerLines = ownerCounts
            .map { (owner: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return ownerSortIndex($0.owner) < ownerSortIndex($1.owner)
            }
            .map { "- \(ownerTitle($0.owner, language: options.language)): \($0.count)" }
            .joined(separator: "\n")

        let kindLines = kindCounts
            .map { (kind: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.kind.rawValue < $1.kind.rawValue
            }
            .prefix(8)
            .map { "- \(L10n.assetKind($0.kind, language: options.language)): \($0.count)" }
            .joined(separator: "\n")

        return sections([
            "## \(text("Context Summary", "上下文摘要", options.language))",
            [
                "- \(field("Assets in scope", language: options.language)): \(assets.count)",
                "- \(field("Context items", language: options.language)): \(contextItems.count)",
                "- \(field("Prompt material", language: options.language)): \(promptItems)",
                "- \(field("Registries and support", language: options.language)): \(registryItems)",
                "- \(field("Estimated tokens", language: options.language)): \(tokenTotal)",
                "- \(field("Largest application", language: options.language)): \(topOwner.map { ownerTitle($0.owner, language: options.language) } ?? unknown(options.language))"
            ].joined(separator: "\n"),
            "### \(text("By Application", "按应用", options.language))\n\(ownerLines.isEmpty ? "- -" : ownerLines)",
            "### \(text("By Kind", "按类型", options.language))\n\(kindLines.isEmpty ? "- -" : kindLines)"
        ])
    }

    private func rankedByApplication(
        sections: [LLMContextOwnerSection],
        totalTokens: Int,
        options: LLMContextPackOptions
    ) -> String {
        guard !sections.isEmpty else {
            return "## \(text("Ranked Files By Application", "按应用排序的文件", options.language))\n- -"
        }

        let renderedSections = sections.map { section in
            let appShare = percent(Double(section.tokenTotal) / Double(max(1, totalTokens)))
            let rows = section.items.prefix(options.itemLimit).enumerated().map { index, item in
                let tokenCount = estimatedTokenCount(for: item)
                return tableRow([
                    "\(index + 1)",
                    escapeTable(item.asset.title),
                    L10n.assetKind(item.asset.kind, language: options.language),
                    "\(tokenCount)",
                    percent(Double(tokenCount) / Double(max(1, section.tokenTotal))),
                    code(path(item.asset.path, style: options.pathStyle))
                ])
            }
            .joined(separator: "\n")

            let hiddenCount = max(0, section.items.count - options.itemLimit)
            let hiddenLine = hiddenCount > 0
                ? "\n\n_\(text("\(hiddenCount) smaller files in this application omitted.", "此应用还有 \(hiddenCount) 个更小的文件已省略。", options.language))_"
                : ""

            return """
            ### \(ownerTitle(section.owner, language: options.language))

            - \(field("Items", language: options.language)): \(section.items.count)
            - \(field("Application share", language: options.language)): \(appShare)
            - \(field("Estimated tokens", language: options.language)): \(section.tokenTotal)

            | Rank | File | Kind | Token | App Share | Path |
            |---:|---|---|---:|---:|---|
            \(rows)\(hiddenLine)
            """
        }

        return "## \(text("Ranked Files By Application", "按应用排序的文件", options.language))\n\n" + renderedSections.joined(separator: "\n\n")
    }

    private func selectedAssetBlock(
        _ asset: AgentAsset,
        matchingItems: [ContextCatalogItem],
        options: LLMContextPackOptions
    ) -> String {
        let routes = matchingItems.map { item in
            [
                "- \(field("Role", language: options.language)): \(L10n.contextRole(item.role, language: options.language))",
                "- \(field("Layer", language: options.language)): \(L10n.contextLayer(item.layer, language: options.language))",
                "- \(field("Loaded into", language: options.language)): \(L10n.loadDestination(item.loadRoute.destination, language: options.language))",
                "- \(field("How it loads", language: options.language)): \(L10n.loadTrigger(item.loadRoute.trigger, language: options.language))",
                "- \(field("Surfaces", language: options.language)): \(owners(item.surfaces, language: options.language))"
            ].joined(separator: "\n")
        }
        .joined(separator: "\n\n")

        return sections([
            "## \(text("Selected Item", "选中项", options.language))",
            [
                "- \(field("Title", language: options.language)): \(asset.title)",
                "- \(field("Path", language: options.language)): \(code(path(asset.path, style: options.pathStyle)))",
                "- \(field("Owner", language: options.language)): \(ownerTitle(asset.owner, language: options.language))",
                "- \(field("Kind", language: options.language)): \(L10n.assetKind(asset.kind, language: options.language))",
                "- \(field("Scope", language: options.language)): \(asset.scope)",
                "- \(field("Estimated tokens", language: options.language)): \(estimatedTokenCount(for: asset))",
                "- \(field("Status", language: options.language)): \(asset.statusFlags.isEmpty ? "-" : asset.statusFlags.map { L10n.statusFlag($0, language: options.language) }.joined(separator: ", "))"
            ].joined(separator: "\n"),
            asset.summary.isEmpty ? "" : "### \(field("Summary", language: options.language))\n\(asset.summary)",
            triggerBlock(asset, language: options.language),
            routes.isEmpty ? "" : "### \(text("Load Routes", "加载路径", options.language))\n\(routes)",
            dependenciesBlock(asset, options: options),
            snippetBlock(asset, options: options)
        ])
    }

    private func evidenceSnippets(items: [ContextCatalogItem], options: LLMContextPackOptions) -> String {
        guard options.detailLevel == .snippets else { return "" }
        let snippets = items
            .prefix(options.itemLimit)
            .map { item in snippetBlock(item.asset, options: options) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !snippets.isEmpty else { return "" }
        return "## \(text("Evidence Snippets", "证据片段", options.language))\n\n\(snippets)"
    }

    private func oneSidedMemorySection(groups: [MemoryPresenceGroup], options: LLMContextPackOptions) -> String {
        guard !groups.isEmpty else {
            return "## \(text("One-Sided Memories", "单边记忆", options.language))\n- \(text("No one-sided Claude Code or Codex memories were found in this export scope.", "当前导出范围内没有发现 Claude Code 或 Codex 单边记忆。", options.language))"
        }

        let rows = groups.prefix(options.itemLimit).map { group in
            let side = presenceTitle(group.status, language: options.language)
            let path = group.primaryItem.map { self.path($0.asset.path, style: options.pathStyle) } ?? "-"
            return tableRow([
                escapeTable(group.title),
                side,
                group.memoryType.map { L10n.memoryType($0, language: options.language) } ?? "-",
                "\(group.items.count)",
                code(path)
            ])
        }
        .joined(separator: "\n")

        return """
        ## \(text("One-Sided Memories", "单边记忆", options.language))

        | Memory | Presence | Type | Items | Example Path |
        |---|---|---|---:|---|
        \(rows)
        """
    }

    private func migrationSummary(
        memoryGroups: [MemoryPresenceGroup],
        oneSidedGroups: [MemoryPresenceGroup],
        organizerRun: OrganizerRun,
        skillTriggerConflicts: [SkillTriggerConflict],
        options: LLMContextPackOptions
    ) -> String {
        let claudeOnly = oneSidedGroups.filter { $0.status == .claudeOnly }.count
        let codexOnly = oneSidedGroups.filter { $0.status == .codexOnly }.count
        let both = memoryGroups.filter { $0.status == .bothSides }.count

        return """
        ## \(text("Migration and Cleanup Summary", "迁移与清理摘要", options.language))

        - \(field("Memory groups", language: options.language)): \(memoryGroups.count)
        - \(field("Claude-only memories", language: options.language)): \(claudeOnly)
        - \(field("Codex-only memories", language: options.language)): \(codexOnly)
        - \(field("Both-side memories", language: options.language)): \(both)
        - \(field("Organizer duplicate count", language: options.language)): \(organizerRun.duplicateAssetCount)
        - \(field("Stale path count", language: options.language)): \(organizerRun.stalePathAssetCount)
        - \(field("Skill trigger conflicts", language: options.language)): \(skillTriggerConflicts.count)
        """
    }

    private func cleanupDiagnosisSection(run: OrganizerRun, options: LLMContextPackOptions) -> String {
        guard run.totalAssetCount > 0 || !run.summary.isEmpty || !run.actionPacks.isEmpty else {
            return "## \(text("Cleanup Diagnosis", "清理诊断", options.language))\n- \(text("No organizer diagnosis is available in this scope.", "当前范围没有可用的整理诊断。", options.language))"
        }

        let packs = run.actionPacks.prefix(options.itemLimit).map { pack in
            "- \(pack.title): \(pack.summary) (\(pack.assetPaths.count) \(text("assets", "项", options.language)))"
        }
        .joined(separator: "\n")

        return sections([
            "## \(text("Cleanup Diagnosis", "清理诊断", options.language))",
            run.summary,
            [
                "- \(field("Total assets", language: options.language)): \(run.totalAssetCount)",
                "- \(field("Duplicates", language: options.language)): \(run.duplicateAssetCount)",
                "- \(field("Low-signal items", language: options.language)): \(run.noiseAssetCount)",
                "- \(field("Sensitive items", language: options.language)): \(run.sensitiveAssetCount)",
                "- \(field("Stale paths", language: options.language)): \(run.stalePathAssetCount)"
            ].joined(separator: "\n"),
            packs.isEmpty ? "" : "### \(text("Action Packs", "行动包", options.language))\n\(packs)"
        ])
    }

    private func triggerConflictSection(conflicts: [SkillTriggerConflict], options: LLMContextPackOptions) -> String {
        guard !conflicts.isEmpty else {
            return "## \(text("Skill Trigger Conflicts", "Skill 触发冲突", options.language))\n- \(text("No trigger conflicts are included in this scope.", "当前范围没有包含触发冲突。", options.language))"
        }

        let rows = conflicts.prefix(options.itemLimit).map { conflict in
            tableRow([
                L10n.skillTriggerConflictSeverity(conflict.severity, language: options.language),
                "\(Int(conflict.score * 100))%",
                escapeTable(conflict.primaryAsset.title),
                escapeTable(conflict.competingAsset.title),
                conflict.sharedTerms.prefix(5).joined(separator: ", ")
            ])
        }
        .joined(separator: "\n")

        return """
        ## \(text("Skill Trigger Conflicts", "Skill 触发冲突", options.language))

        | Risk | Confidence | Primary | Competing | Shared Terms |
        |---|---:|---|---|---|
        \(rows)
        """
    }

    private func safetyNotes(language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return """
            ## Safety Notes

            - 这是本地可见上下文的导出，不代表厂商隐藏 system prompt。
            - 密钥风险文件和敏感内容应保持不展开；不要要求 LLM 推断或恢复被隐藏的内容。
            - 大文件可能只包含预览片段；需要完整内容时，应回到本地文件逐项确认。
            - 文件操作建议必须保守：默认不删除、不覆盖、不迁移，除非用户明确批准。
            """
        case .english:
            return """
            ## Safety Notes

            - This export contains locally visible context only; it is not a hidden vendor system prompt.
            - Secret-risk files and sensitive content should remain redacted; do not ask the LLM to infer hidden content.
            - Large files may only include preview snippets; inspect local files directly before acting on full content.
            - File-operation recommendations must stay conservative: do not delete, overwrite, or migrate unless the user explicitly approves.
            """
        }
    }

    private func dependenciesBlock(_ asset: AgentAsset, options: LLMContextPackOptions) -> String {
        let dependencies = asset.dependencies.prefix(8).map { "- `\($0)`" }.joined(separator: "\n")
        let relatedFiles = asset.relatedFiles.prefix(8).map { "- `\(path($0, style: options.pathStyle))`" }.joined(separator: "\n")
        return sections([
            dependencies.isEmpty ? "" : "### \(L10n.text(.dependencies, language: options.language))\n\(dependencies)",
            relatedFiles.isEmpty ? "" : "### \(L10n.text(.relatedFiles, language: options.language))\n\(relatedFiles)"
        ])
    }

    private func triggerBlock(_ asset: AgentAsset, language: AppLanguage) -> String {
        guard let trigger = asset.trigger?.trimmingCharacters(in: .whitespacesAndNewlines), !trigger.isEmpty else { return "" }
        return "### \(L10n.text(.trigger, language: language))\n\(singleLine(trigger))"
    }

    private func snippetBlock(_ asset: AgentAsset, options: LLMContextPackOptions) -> String {
        guard options.detailLevel == .snippets else { return "" }
        let preview = asset.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preview.isEmpty else { return "" }
        let excerpt = preview.count <= 900 ? preview : String(preview.prefix(900)).trimmingCharacters(in: .whitespacesAndNewlines) + "\n..."
        return """
        ### \(asset.title)

        Path: `\(path(asset.path, style: options.pathStyle))`

        ```text
        \(excerpt)
        ```
        """
    }

    private func rankedContextItems(_ items: [ContextCatalogItem]) -> [ContextCatalogItem] {
        items.sorted { left, right in
            let leftTokens = estimatedTokenCount(for: left)
            let rightTokens = estimatedTokenCount(for: right)
            if leftTokens != rightTokens { return leftTokens > rightTokens }
            if ownerSortIndex(left.asset.owner) != ownerSortIndex(right.asset.owner) {
                return ownerSortIndex(left.asset.owner) < ownerSortIndex(right.asset.owner)
            }
            return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
        }
    }

    private func ownerSectionSort(_ left: LLMContextOwnerSection, _ right: LLMContextOwnerSection) -> Bool {
        if left.tokenTotal != right.tokenTotal { return left.tokenTotal > right.tokenTotal }
        return ownerSortIndex(left.owner) < ownerSortIndex(right.owner)
    }

    private func uniqueItems(_ items: [ContextCatalogItem]) -> [ContextCatalogItem] {
        var seen: Set<String> = []
        return items.filter { item in
            let key = item.asset.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func uniqueAssets(_ assets: [AgentAsset]) -> [AgentAsset] {
        var seen: Set<String> = []
        return assets.filter { asset in
            guard !seen.contains(asset.path) else { return false }
            seen.insert(asset.path)
            return true
        }
    }

    private func estimatedTokenCount(for item: ContextCatalogItem) -> Int {
        estimatedTokenCount(for: item.asset)
    }

    private func estimatedTokenCount(for asset: AgentAsset) -> Int {
        let text = [
            asset.title,
            asset.summary,
            asset.trigger ?? "",
            asset.preview
        ]
        .joined(separator: "\n")
        return max(1, text.count / 4)
    }

    private func path(_ value: String, style: LLMContextPackPathStyle) -> String {
        switch style {
        case .full:
            return value
        case .abbreviated:
            return value.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        case .redactedUser:
            let home = NSHomeDirectory()
            let user = URL(fileURLWithPath: home).lastPathComponent
            return value
                .replacingOccurrences(of: home, with: "~")
                .replacingOccurrences(of: "/Users/\(user)", with: "/Users/<user>")
        }
    }

    private func generatedAtText(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func percent(_ value: Double) -> String {
        let bounded = max(0, min(1, value))
        if bounded < 0.001, bounded > 0 { return "<0.1%" }
        return String(format: "%.1f%%", bounded * 100)
    }

    private func tableRow(_ cells: [String]) -> String {
        "| " + cells.joined(separator: " | ") + " |"
    }

    private func escapeTable(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "\\|")
    }

    private func code(_ text: String) -> String {
        "`\(text.replacingOccurrences(of: "`", with: "\\`"))`"
    }

    private func singleLine(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func sections(_ values: [String]) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func owners(_ owners: [AgentOwner], language: AppLanguage) -> String {
        guard !owners.isEmpty else { return unknown(language) }
        return owners.map { ownerTitle($0, language: language) }.joined(separator: ", ")
    }

    private func ownerTitle(_ owner: AgentOwner, language: AppLanguage) -> String {
        owner == .claude ? L10n.text(.claudeCode, language: language) : L10n.agentOwner(owner, language: language)
    }

    private func ownerSortIndex(_ owner: AgentOwner) -> Int {
        switch owner {
        case .claude: 0
        case .codex: 1
        case .agents: 2
        case .project: 3
        case .unknown: 4
        }
    }

    private func presenceTitle(_ status: MemoryPresenceStatus, language: AppLanguage) -> String {
        switch (status, language) {
        case (.claudeOnly, .simplifiedChinese): "仅 Claude Code"
        case (.codexOnly, .simplifiedChinese): "仅 Codex"
        case (.bothSides, .simplifiedChinese): "两边都有"
        case (.sharedOnly, .simplifiedChinese): "仅共享"
        case (.unknown, .simplifiedChinese): "未知"
        case (.claudeOnly, _): "Claude Code only"
        case (.codexOnly, _): "Codex only"
        case (.bothSides, _): "Both sides"
        case (.sharedOnly, _): "Shared only"
        case (.unknown, _): "Unknown"
        }
    }

    private func presetTitle(_ preset: LLMContextPackPreset, language: AppLanguage) -> String {
        switch (preset, language) {
        case (.currentView, .simplifiedChinese): "当前视图"
        case (.selectedItem, .simplifiedChinese): "选中项"
        case (.migrationCleanup, .simplifiedChinese): "迁移/清理"
        case (.currentView, _): "Current view"
        case (.selectedItem, _): "Selected item"
        case (.migrationCleanup, _): "Migration / cleanup"
        }
    }

    private func targetTitle(_ target: LLMContextPackTarget, language: AppLanguage) -> String {
        switch (target, language) {
        case (.general, .simplifiedChinese): "通用 LLM"
        case (.codex, .simplifiedChinese): "Codex"
        case (.claudeCode, .simplifiedChinese): "Claude Code"
        case (.general, _): "General LLM"
        case (.codex, _): "Codex"
        case (.claudeCode, _): "Claude Code"
        }
    }

    private func pathStyleTitle(_ style: LLMContextPackPathStyle, language: AppLanguage) -> String {
        switch (style, language) {
        case (.abbreviated, .simplifiedChinese): "~ 简写"
        case (.full, .simplifiedChinese): "完整路径"
        case (.redactedUser, .simplifiedChinese): "隐藏用户名"
        case (.abbreviated, _): "Abbreviated"
        case (.full, _): "Full path"
        case (.redactedUser, _): "Redacted user"
        }
    }

    private func detailLevelTitle(_ level: LLMContextPackDetailLevel, language: AppLanguage) -> String {
        switch (level, language) {
        case (.summary, .simplifiedChinese): "仅摘要"
        case (.snippets, .simplifiedChinese): "摘要 + 片段"
        case (.summary, _): "Summary only"
        case (.snippets, _): "Summary + snippets"
        }
    }

    private func targetInstruction(_ target: LLMContextPackTarget, language: AppLanguage) -> String {
        switch (target, language) {
        case (.general, .simplifiedChinese):
            return "目标模型是通用 LLM；请只根据本文本中的证据行动。"
        case (.codex, .simplifiedChinese):
            return "目标模型是 Codex；如需改文件，必须先读取真实文件并运行可行验证。"
        case (.claudeCode, .simplifiedChinese):
            return "目标模型是 Claude Code；如需迁移或修改，必须先确认目标路径是否已存在。"
        case (.general, _):
            return "The target model is a general LLM; act only on evidence in this text."
        case (.codex, _):
            return "The target model is Codex; if file edits are needed, inspect real files first and run feasible validation."
        case (.claudeCode, _):
            return "The target model is Claude Code; if migration or edits are needed, check whether destination paths already exist first."
        }
    }

    private func field(_ english: String, language: AppLanguage) -> String {
        switch (english, language) {
        case ("Generated", .simplifiedChinese): "生成时间"
        case ("Scope", .simplifiedChinese): "范围"
        case ("Preset", .simplifiedChinese): "预设"
        case ("Target", .simplifiedChinese): "目标"
        case ("Path style", .simplifiedChinese): "路径样式"
        case ("Detail", .simplifiedChinese): "细节"
        case ("Assets in scope", .simplifiedChinese): "范围内资产"
        case ("Context items", .simplifiedChinese): "上下文项目"
        case ("Prompt material", .simplifiedChinese): "提示词材料"
        case ("Registries and support", .simplifiedChinese): "注册表与支持文件"
        case ("Estimated tokens", .simplifiedChinese): "估算 token"
        case ("Largest application", .simplifiedChinese): "最大应用"
        case ("Items", .simplifiedChinese): "项目"
        case ("Application share", .simplifiedChinese): "应用占比"
        case ("Title", .simplifiedChinese): "标题"
        case ("Path", .simplifiedChinese): "路径"
        case ("Owner", .simplifiedChinese): "归属"
        case ("Kind", .simplifiedChinese): "类型"
        case ("Scope", .simplifiedChinese): "范围"
        case ("Status", .simplifiedChinese): "状态"
        case ("Summary", .simplifiedChinese): "摘要"
        case ("Role", .simplifiedChinese): "角色"
        case ("Layer", .simplifiedChinese): "层级"
        case ("Loaded into", .simplifiedChinese): "加载到"
        case ("How it loads", .simplifiedChinese): "加载方式"
        case ("Surfaces", .simplifiedChinese): "运行面"
        case ("Memory groups", .simplifiedChinese): "记忆组"
        case ("Claude-only memories", .simplifiedChinese): "仅 Claude Code 记忆"
        case ("Codex-only memories", .simplifiedChinese): "仅 Codex 记忆"
        case ("Both-side memories", .simplifiedChinese): "两边都有的记忆"
        case ("Organizer duplicate count", .simplifiedChinese): "整理器重复项"
        case ("Stale path count", .simplifiedChinese): "过期路径数"
        case ("Skill trigger conflicts", .simplifiedChinese): "Skill 触发冲突"
        case ("Total assets", .simplifiedChinese): "资产总数"
        case ("Duplicates", .simplifiedChinese): "重复项"
        case ("Low-signal items", .simplifiedChinese): "低信号项"
        case ("Sensitive items", .simplifiedChinese): "敏感项"
        case ("Stale paths", .simplifiedChinese): "过期路径"
        default: english
        }
    }

    private func text(_ english: String, _ simplifiedChinese: String, _ language: AppLanguage) -> String {
        switch language {
        case .english: english
        case .simplifiedChinese: simplifiedChinese
        }
    }

    private func unknown(_ language: AppLanguage) -> String {
        L10n.text(.unknown, language: language)
    }
}

private struct LLMContextOwnerSection: Sendable {
    let owner: AgentOwner
    let items: [ContextCatalogItem]
    let tokenTotal: Int
}
