import Foundation

public struct OrganizerRunExporter: Sendable {
    public init() {}

    public func markdown(
        run: OrganizerRun,
        language: AppLanguage = .english
    ) -> String {
        if language == .simplifiedChinese {
            return chineseMarkdown(run: run)
        }
        return englishMarkdown(run: run)
    }

    private func chineseMarkdown(run: OrganizerRun) -> String {
        sections([
            "# \(run.title.isEmpty ? "整理诊断" : run.title)",
            run.summary.isEmpty ? "当前没有可用诊断，请先扫描启用来源。" : run.summary,
            [
                "资产总数：\(run.totalAssetCount)",
                "重复项：\(run.duplicateAssetCount)",
                "低信号项：\(run.noiseAssetCount)",
                "敏感项：\(run.sensitiveAssetCount)",
                "旧路径项：\(run.stalePathAssetCount)",
                "待澄清项：\(run.unclearAssetCount)"
            ].joined(separator: "\n"),
            actionPackSection(
                title: "建议动作",
                emptyText: "没有可自动执行的行动包。",
                run: run,
                language: .simplifiedChinese
            )
        ])
    }

    private func englishMarkdown(run: OrganizerRun) -> String {
        sections([
            "# \(run.title.isEmpty ? "Organizer Diagnosis" : run.title)",
            run.summary.isEmpty ? "No organizer diagnosis is available. Scan enabled sources first." : run.summary,
            [
                "Total assets: \(run.totalAssetCount)",
                "Duplicates: \(run.duplicateAssetCount)",
                "Low-signal items: \(run.noiseAssetCount)",
                "Sensitive items: \(run.sensitiveAssetCount)",
                "Stale path items: \(run.stalePathAssetCount)",
                "Unclear items: \(run.unclearAssetCount)"
            ].joined(separator: "\n"),
            actionPackSection(
                title: "Recommended Actions",
                emptyText: "No automatic action packs.",
                run: run,
                language: .english
            )
        ])
    }

    private func actionPackSection(
        title: String,
        emptyText: String,
        run: OrganizerRun,
        language: AppLanguage
    ) -> String {
        guard !run.actionPacks.isEmpty else {
            return "## \(title)\n- \(emptyText)"
        }

        let blocks = run.actionPacks.map { pack in
            let execution = executionText(for: pack, language: language)
            let reversible = booleanText(pack.isReversible, language: language)
            return sections([
                "### \(pack.title)",
                pack.summary,
                "- \(field("Type", language: language)): \(L10n.organizerActionPackKind(pack.kind, language: language))",
                "- \(field("Risk", language: language)): \(L10n.organizerActionPackRisk(pack.risk, language: language))",
                "- \(field("Assets", language: language)): \(pack.assetPaths.count)",
                "- \(field("Execution", language: language)): \(execution)",
                "- \(field("Reversible", language: language)): \(reversible)"
            ])
        }

        return "## \(title)\n\n" + blocks.joined(separator: "\n\n")
    }

    private func executionText(for pack: OrganizerActionPack, language: AppLanguage) -> String {
        switch (pack.canExecuteAutomatically, language) {
        case (true, .simplifiedChinese): "可自动执行"
        case (false, .simplifiedChinese): "需要人工复核"
        case (true, _): "Automatic"
        case (false, _): "Manual review"
        }
    }

    private func booleanText(_ value: Bool, language: AppLanguage) -> String {
        switch (value, language) {
        case (true, .simplifiedChinese): "是"
        case (false, .simplifiedChinese): "否"
        case (true, _): "Yes"
        case (false, _): "No"
        }
    }

    private func field(_ english: String, language: AppLanguage) -> String {
        switch (english, language) {
        case ("Type", .simplifiedChinese): "类型"
        case ("Risk", .simplifiedChinese): "风险"
        case ("Assets", .simplifiedChinese): "资产数量"
        case ("Execution", .simplifiedChinese): "执行方式"
        case ("Reversible", .simplifiedChinese): "可撤销"
        default: english
        }
    }

    private func sections(_ values: [String]) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
