import AgentObservatoryCore
import SwiftUI

struct MemoryMigrationDraft: Identifiable, Hashable {
    let asset: AgentAsset
    let target: AgentOwner
    let plan: MemoryMigrationPlan
    let existingTargetPath: String?

    init(
        asset: AgentAsset,
        target: AgentOwner,
        plan: MemoryMigrationPlan,
        existingTargetPath: String? = nil
    ) {
        self.asset = asset
        self.target = target
        self.plan = plan
        self.existingTargetPath = existingTargetPath
    }

    var id: String {
        "\(asset.id.uuidString)-\(target.rawValue)-\(plan.destinationPath)-\(existingTargetPath ?? "clear")"
    }

    var targetAlreadyHasMemory: Bool {
        existingTargetPath != nil
    }

    var isBlocked: Bool {
        plan.destinationExists || targetAlreadyHasMemory
    }
}

struct MemoryMigrationCompactButton: View {
    @EnvironmentObject private var store: AssetStore
    let draft: MemoryMigrationDraft
    let open: (MemoryMigrationDraft) -> Void

    private var tint: Color {
        if draft.plan.destinationExists {
            return .orange
        }
        if draft.targetAlreadyHasMemory {
            return .green
        }
        return ownerTint(draft.target)
    }

    var body: some View {
        Button {
            open(draft)
        } label: {
            Image(systemName: draft.isBlocked ? "checkmark.seal" : "arrow.left.arrow.right")
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
        .help(memoryMigrationCompactHelp(draft: draft, language: store.appLanguage))
    }
}

struct MemoryMigrationInspectorPanel: View {
    @EnvironmentObject private var store: AssetStore
    @State private var presentedDraft: MemoryMigrationDraft?
    let asset: AgentAsset

    private var presenceGroup: MemoryPresenceGroup? {
        MemoryMigrationPlanner()
            .groups(items: store.contextCatalog.memoryItems)
            .first { group in
                group.items.contains { $0.asset.id == asset.id }
            }
    }

    private var draft: MemoryMigrationDraft? {
        if let presenceGroup {
            if let claudeItem = presenceGroup.migratableClaudeItem,
               claudeItem.asset.id == asset.id,
               let plan = store.memoryMigrationPlan(for: claudeItem.asset, to: .codex) {
                return makeDraft(asset: claudeItem.asset, target: .codex, plan: plan)
            }

            if let codexItem = presenceGroup.migratableCodexItem,
               codexItem.asset.id == asset.id,
               let plan = store.memoryMigrationPlan(for: codexItem.asset, to: .claude) {
                return makeDraft(asset: codexItem.asset, target: .claude, plan: plan)
            }
        }

        guard let sourceSide = MemoryMigrationSide(owner: asset.owner) else { return nil }
        let target: AgentOwner = sourceSide == .claude ? .codex : .claude
        guard let plan = store.memoryMigrationPlan(for: asset, to: target) else { return nil }
        return makeDraft(asset: asset, target: target, plan: plan)
    }

    private func makeDraft(
        asset: AgentAsset,
        target: AgentOwner,
        plan: MemoryMigrationPlan
    ) -> MemoryMigrationDraft {
        MemoryMigrationDraft(
            asset: asset,
            target: target,
            plan: plan,
            existingTargetPath: store.existingMemoryTargetPath(
                for: asset,
                to: target,
                plannedDestinationPath: plan.destinationPath
            )
        )
    }

    var body: some View {
        InspectorPanel(title: memorySyncPanelTitle(language: store.appLanguage), systemImage: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 12) {
                MemoryMigrationPresenceLine(
                    hasClaude: presenceGroup?.hasClaudeSurface ?? (asset.owner == .claude),
                    hasCodex: presenceGroup?.hasCodexSurface ?? (asset.owner == .codex)
                )

                Text(memorySyncPanelDescription(group: presenceGroup, draft: draft, language: store.appLanguage))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let draft {
                    MemoryMigrationRoutePreview(draft: draft)

                    Button {
                        presentedDraft = draft
                    } label: {
                        Label(memoryMigrationPreviewButtonTitle(for: draft, language: store.appLanguage), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(draft.isBlocked ? .orange : ownerTint(draft.target))
                } else if presenceGroup?.status == .bothSides {
                    Label(memorySyncAlreadyAlignedTitle(language: store.appLanguage), systemImage: "checkmark.seal")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                }
            }
        }
        .sheet(item: $presentedDraft) { draft in
            MemoryMigrationDetailSheet(draft: draft)
        }
    }
}

private struct MemoryMigrationPresenceLine: View {
    @EnvironmentObject private var store: AssetStore
    let hasClaude: Bool
    let hasCodex: Bool

    var body: some View {
        HStack(spacing: 8) {
            MemoryMigrationEndpointStatus(owner: .claude, isPresent: hasClaude)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .overlay {
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                }
            MemoryMigrationEndpointStatus(owner: .codex, isPresent: hasCodex)
        }
    }
}

private struct MemoryMigrationEndpointStatus: View {
    @EnvironmentObject private var store: AssetStore
    let owner: AgentOwner
    let isPresent: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isPresent ? ownerTint(owner) : .secondary)

            Text(memoryMigrationOwnerTitle(owner, language: store.appLanguage))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background((isPresent ? ownerTint(owner) : Color.secondary).opacity(isPresent ? 0.13 : 0.08), in: Capsule())
    }
}

private struct MemoryMigrationRoutePreview: View {
    @EnvironmentObject private var store: AssetStore
    let draft: MemoryMigrationDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            MemoryMigrationRoutePathRow(
                title: memoryMigrationEndpointTitle(.source, language: store.appLanguage),
                owner: draft.asset.owner,
                path: draft.plan.sourcePath
            )

            Divider()

            MemoryMigrationRoutePathRow(
                title: memoryMigrationEndpointTitle(.target, language: store.appLanguage),
                owner: draft.target,
                path: draft.plan.destinationPath
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ownerTint(draft.target).opacity(0.22))
        }
    }
}

private struct MemoryMigrationRoutePathRow: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let owner: AgentOwner
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                BadgeView(text: memoryMigrationOwnerTitle(owner, language: store.appLanguage), tint: ownerTint(owner))
            }

            PathPreviewLink(
                path: path,
                displayPath: path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                font: .caption.monospaced(),
                foregroundColor: .primary,
                lineLimit: 2,
                language: store.appLanguage
            )
        }
    }
}

struct MemoryMigrationDetailSheet: View {
    @EnvironmentObject private var store: AssetStore
    @Environment(\.dismiss) private var dismiss
    @State private var copiedResult: MemoryMigrationResult?
    let draft: MemoryMigrationDraft

    private var targetTint: Color {
        ownerTint(draft.target)
    }

    private var sourceOwner: AgentOwner {
        draft.asset.owner
    }

    private var destinationExists: Bool {
        draft.plan.destinationExists || FileManager.default.fileExists(atPath: draft.plan.destinationPath)
    }

    private var targetAlreadyHasMemory: Bool {
        draft.targetAlreadyHasMemory
    }

    private var canCopy: Bool {
        copiedResult == nil && !destinationExists && !targetAlreadyHasMemory
    }

    private var statusIcon: String {
        if copiedResult != nil {
            return "checkmark.circle.fill"
        }
        if destinationExists {
            return "exclamationmark.triangle.fill"
        }
        if targetAlreadyHasMemory {
            return "checkmark.seal.fill"
        }
        return "arrow.left.arrow.right.circle.fill"
    }

    private var statusTint: Color {
        if copiedResult != nil {
            return .green
        }
        if destinationExists || targetAlreadyHasMemory {
            return .orange
        }
        return targetTint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(memoryMigrationSheetTitle(draft: draft, copied: copiedResult != nil, destinationExists: destinationExists, language: store.appLanguage))
                        .font(.title3.weight(.semibold))
                    Text(
                        memoryMigrationSheetSubtitle(
                            for: draft.asset.title,
                            to: draft.target,
                            blocked: destinationExists || targetAlreadyHasMemory,
                            language: store.appLanguage
                        )
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .compactHitTarget()
                }
                .buttonStyle(.borderless)
                .help(store.t(.cancel))
            }

            HStack(spacing: 12) {
                MemoryMigrationEndpointCard(
                    title: memoryMigrationEndpointTitle(.source, language: store.appLanguage),
                    owner: sourceOwner,
                    path: draft.plan.sourcePath,
                    detail: memoryMigrationEndpointDetail(.source, language: store.appLanguage)
                )

                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                MemoryMigrationEndpointCard(
                    title: memoryMigrationEndpointTitle(.target, language: store.appLanguage),
                    owner: draft.target,
                    path: draft.plan.destinationPath,
                    detail: memoryMigrationEndpointDetail(.target, language: store.appLanguage)
                )
            }

            MemoryMigrationPolicyPanel(
                destinationExists: destinationExists,
                targetAlreadyHasMemory: targetAlreadyHasMemory
            )

            if let copiedResult {
                MemoryMigrationResultPanel(result: copiedResult)
            } else if destinationExists {
                MemoryMigrationBlockPanel(
                    title: memoryMigrationDestinationExistsWarning(language: store.appLanguage),
                    path: draft.plan.destinationPath
                )
            } else if targetAlreadyHasMemory, let existingTargetPath = draft.existingTargetPath {
                MemoryMigrationBlockPanel(
                    title: memoryMigrationTargetAlreadyExistsWarning(language: store.appLanguage),
                    path: existingTargetPath
                )
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text(copiedResult == nil ? store.t(.cancel) : memoryMigrationCloseTitle(language: store.appLanguage))
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    if let result = store.migrateMemory(draft.asset, to: draft.target) {
                        copiedResult = result
                    }
                } label: {
                    Label(memoryMigrationConfirmTitle(to: draft.target, language: store.appLanguage), systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(targetTint)
                .disabled(!canCopy)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 720, alignment: .topLeading)
    }
}

private enum MemoryMigrationEndpointRole {
    case source
    case target
}

private struct MemoryMigrationEndpointCard: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let owner: AgentOwner
    let path: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                BadgeView(text: memoryMigrationOwnerTitle(owner, language: store.appLanguage), tint: ownerTint(owner))
            }

            PathPreviewLink(
                path: path,
                displayPath: path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                font: .caption.monospaced(),
                foregroundColor: .primary,
                lineLimit: 2,
                language: store.appLanguage
            )

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.42))
        }
    }
}

private struct MemoryMigrationPolicyPanel: View {
    @EnvironmentObject private var store: AssetStore
    let destinationExists: Bool
    let targetAlreadyHasMemory: Bool

    private var rows: [(String, String, Color)] {
        memoryMigrationPolicyRows(
            destinationExists: destinationExists,
            targetAlreadyHasMemory: targetAlreadyHasMemory,
            language: store.appLanguage
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(memoryMigrationPolicyTitle(language: store.appLanguage), systemImage: "shield.checkered")
                .font(.callout.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: row.0)
                            .foregroundStyle(row.2)
                            .frame(width: 18)
                        Text(row.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.32))
        }
    }
}

private struct MemoryMigrationResultPanel: View {
    @EnvironmentObject private var store: AssetStore
    let result: MemoryMigrationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(memoryMigrationCopiedTitle(language: store.appLanguage), systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.green)

            PathPreviewLink(
                path: result.plan.destinationPath,
                displayPath: result.plan.destinationPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                font: .caption.monospaced(),
                foregroundColor: .secondary,
                lineLimit: 2,
                language: store.appLanguage
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.green.opacity(0.22))
        }
    }
}

private struct MemoryMigrationBlockPanel: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)

            PathPreviewLink(
                path: path,
                displayPath: path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
                font: .caption.monospaced(),
                foregroundColor: .secondary,
                lineLimit: 2,
                language: store.appLanguage
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.orange.opacity(0.26))
        }
    }
}

private func memorySyncPanelTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Memory sync"
    case .simplifiedChinese:
        "记忆同步建议"
    }
}

private func memorySyncPanelDescription(
    group: MemoryPresenceGroup?,
    draft: MemoryMigrationDraft?,
    language: AppLanguage
) -> String {
    if let draft {
        if draft.targetAlreadyHasMemory {
            switch language {
            case .english:
                return "The target agent already has a matching memory. Open the preview to inspect the existing path; nothing will be copied."
            case .simplifiedChinese:
                return "目标 agent 已经有对应记忆。打开预览可以查看已有位置，本次不会再复制。"
            }
        }

        if draft.plan.destinationExists {
            switch language {
            case .english:
                return "The generated destination file already exists. Open the preview to inspect it; copying is disabled."
            case .simplifiedChinese:
                return "生成的目标文件已经存在。打开预览可以查看路径，本次复制已禁用。"
            }
        }

        switch language {
        case .english:
            return "This memory exists on \(memoryMigrationOwnerTitle(draft.asset.owner, language: language)) only. Review the destination before copying it to \(memoryMigrationOwnerTitle(draft.target, language: language))."
        case .simplifiedChinese:
            return "这条记忆目前只在 \(memoryMigrationOwnerTitle(draft.asset.owner, language: language)) 侧存在。先检查目标路径，再复制到 \(memoryMigrationOwnerTitle(draft.target, language: language))。"
        }
    }

    if group?.status == .bothSides {
        switch language {
        case .english:
            return "Claude Code and Codex both have a matching memory record, so there is no copy action to take here."
        case .simplifiedChinese:
            return "Claude Code 和 Codex 都已经有对应记忆，这里不需要再复制。"
        }
    }

    switch language {
    case .english:
        return "This memory is not currently eligible for automatic migration."
    case .simplifiedChinese:
        return "这条记忆暂时不适合自动迁移。"
    }
}

private func memorySyncAlreadyAlignedTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Already available on both sides"
    case .simplifiedChinese:
        "两边都已存在"
    }
}

private func memoryMigrationInlineButtonTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "迁移" : "Migrate"
}

private func memoryMigrationPreviewButtonTitle(for draft: MemoryMigrationDraft, language: AppLanguage) -> String {
    if draft.isBlocked {
        return switch language {
        case .english:
            "Review existing target"
        case .simplifiedChinese:
            "查看目标已存在"
        }
    }

    return switch language {
    case .english:
        "Preview and copy to \(memoryMigrationOwnerTitle(draft.target, language: language))"
    case .simplifiedChinese:
        "预览并复制到 \(memoryMigrationOwnerTitle(draft.target, language: language))"
    }
}

private func memoryMigrationCompactHelp(draft: MemoryMigrationDraft, language: AppLanguage) -> String {
    if draft.plan.destinationExists {
        return memoryMigrationDestinationExistsWarning(language: language)
    }
    if draft.targetAlreadyHasMemory, let existingTargetPath = draft.existingTargetPath {
        let displayPath = existingTargetPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        return switch language {
        case .english:
            "Target already has a matching memory: \(displayPath)"
        case .simplifiedChinese:
            "目标 agent 已有对应记忆：\(displayPath)"
        }
    }

    return "\(memoryMigrationInlineButtonTitle(language: language)) · \(memoryMigrationDestinationHelp(draft.plan.destinationPath, language: language))"
}

private func memoryMigrationDestinationHelp(_ path: String, language: AppLanguage) -> String {
    let displayPath = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    return switch language {
    case .english:
        "Destination: \(displayPath)"
    case .simplifiedChinese:
        "目标位置：\(displayPath)"
    }
}

private func memoryMigrationSheetTitle(
    draft: MemoryMigrationDraft,
    copied: Bool,
    destinationExists: Bool,
    language: AppLanguage
) -> String {
    if copied {
        return memoryMigrationCopiedTitle(language: language)
    }

    if destinationExists || draft.targetAlreadyHasMemory {
        return switch language {
        case .english:
            "Target already exists"
        case .simplifiedChinese:
            "目标已存在"
        }
    }

    return switch language {
    case .english:
        "Review memory migration"
    case .simplifiedChinese:
        "确认记忆迁移"
    }
}

private func memoryMigrationCopiedTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Memory copied"
    case .simplifiedChinese:
        "记忆已复制"
    }
}

private func memoryMigrationSheetSubtitle(
    for title: String,
    to target: AgentOwner,
    blocked: Bool,
    language: AppLanguage
) -> String {
    if blocked {
        return switch language {
        case .english:
            "No file will be copied until the existing target state is resolved."
        case .simplifiedChinese:
            "这次不会复制文件；先确认目标侧已有内容是否就是你要保留的版本。"
        }
    }

    return switch language {
    case .english:
        "Copy \"\(title)\" to \(memoryMigrationOwnerTitle(target, language: language)) after checking the destination path."
    case .simplifiedChinese:
        "检查目标路径后，把「\(title)」复制到 \(memoryMigrationOwnerTitle(target, language: language))。"
    }
}

private func memoryMigrationEndpointTitle(_ role: MemoryMigrationEndpointRole, language: AppLanguage) -> String {
    switch (role, language) {
    case (.source, .simplifiedChinese):
        "来源"
    case (.target, .simplifiedChinese):
        "目标"
    case (.source, _):
        "Source"
    case (.target, _):
        "Destination"
    }
}

private func memoryMigrationEndpointDetail(_ role: MemoryMigrationEndpointRole, language: AppLanguage) -> String {
    switch (role, language) {
    case (.source, .simplifiedChinese):
        "复制时不会移动或删除这个文件。"
    case (.target, .simplifiedChinese):
        "如果目标文件已存在，复制会停止，避免覆盖已有记忆。"
    case (.source, _):
        "This file is copied in place; it will not be moved or deleted."
    case (.target, _):
        "If this destination already exists, copying stops instead of overwriting memory."
    }
}

private func memoryMigrationPolicyTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Copy policy"
    case .simplifiedChinese:
        "复制策略"
    }
}

private func memoryMigrationPolicyRows(
    destinationExists: Bool,
    targetAlreadyHasMemory: Bool,
    language: AppLanguage
) -> [(String, String, Color)] {
    switch language {
    case .english:
        return [
            ("doc.on.doc", "Copy only. The source memory remains readable by its original agent.", .blue),
            ("lock.shield", "No overwrite. Existing destination files block this action.", destinationExists ? .orange : .green),
            ("checkmark.seal", "No duplicate round trips. A matching memory already on the target side blocks this action.", targetAlreadyHasMemory ? .orange : .green),
            ("arrow.clockwise", "After copying, the app rescans so the new memory appears in the index.", .teal)
        ]
    case .simplifiedChinese:
        return [
            ("doc.on.doc", "只复制，不移动。原来的 agent 仍然能读到源记忆。", .blue),
            ("lock.shield", "不覆盖。目标文件已存在时会阻止本次复制。", destinationExists ? .orange : .green),
            ("checkmark.seal", "不来回复制。目标侧已有对应记忆时会阻止本次复制。", targetAlreadyHasMemory ? .orange : .green),
            ("arrow.clockwise", "复制后会自动重新扫描，让新记忆进入索引。", .teal)
        ]
    }
}

private func memoryMigrationDestinationExistsWarning(language: AppLanguage) -> String {
    switch language {
    case .english:
        "The destination already exists. This copy action is disabled to avoid overwriting memory."
    case .simplifiedChinese:
        "目标文件已经存在。为了避免覆盖记忆，本次复制已禁用。"
    }
}

private func memoryMigrationTargetAlreadyExistsWarning(language: AppLanguage) -> String {
    switch language {
    case .english:
        "The target agent already has a matching memory. This copy action is disabled to avoid creating a duplicate."
    case .simplifiedChinese:
        "目标 agent 已有对应记忆。为了避免来回复制出重复文件，本次复制已禁用。"
    }
}

private func memoryMigrationConfirmTitle(to target: AgentOwner, language: AppLanguage) -> String {
    switch language {
    case .english:
        "Copy to \(memoryMigrationOwnerTitle(target, language: language))"
    case .simplifiedChinese:
        "复制到 \(memoryMigrationOwnerTitle(target, language: language))"
    }
}

private func memoryMigrationCloseTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "完成" : "Done"
}

private func memoryMigrationOwnerTitle(_ owner: AgentOwner, language: AppLanguage) -> String {
    switch owner {
    case .claude:
        return "Claude Code"
    case .codex:
        return "Codex"
    default:
        return L10n.agentOwner(owner, language: language)
    }
}

private func ownerTint(_ owner: AgentOwner) -> Color {
    switch owner {
    case .claude: .orange
    case .codex: .blue
    case .agents: .green
    case .project: .teal
    case .unknown: .secondary
    }
}
