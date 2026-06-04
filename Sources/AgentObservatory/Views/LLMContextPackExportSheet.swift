import AgentObservatoryCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LLMContextPackExportSheet: View {
    @EnvironmentObject private var store: AssetStore
    @Environment(\.dismiss) private var dismiss

    @State private var options: LLMContextPackOptions
    @State private var didCopy = false
    @State private var saveMessage: String?

    init(initialPreset: LLMContextPackPreset, language: AppLanguage) {
        _options = State(initialValue: LLMContextPackOptions(preset: initialPreset, language: language))
    }

    private var markdown: String {
        store.llmContextPackMarkdown(options: options)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(18)

            Divider()

            HStack(spacing: 0) {
                presetRail
                    .frame(width: 210)

                Divider()

                previewPane
                    .frame(minWidth: 460)

                Divider()

                optionsPane
                    .frame(width: 250)
            }

            Divider()

            footer
                .padding(18)
        }
        .frame(width: 980, height: 690)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(exportText("LLM Context Pack", "LLM 上下文包", language: store.appLanguage))
                    .font(.title3.weight(.semibold))
                Text(exportText(
                    "Export the current local evidence as a Markdown handoff another agent can safely continue from.",
                    "把当前本地证据导出成一份 Markdown 交接包，让另一个 agent 可以安全接手。",
                    language: store.appLanguage
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .compactHitTarget()
            }
            .buttonStyle(.plain)
            .help(exportText("Close", "关闭", language: store.appLanguage))
        }
    }

    private var presetRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exportText("Preset", "预设", language: store.appLanguage))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(LLMContextPackPreset.allCases) { preset in
                LLMExportPresetButton(
                    preset: preset,
                    isSelected: options.preset == preset
                ) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        options.preset = preset
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Label(exportText("Read-only", "只读导出", language: store.appLanguage), systemImage: "lock.open")
                    .font(.caption.weight(.semibold))
                Text(exportText(
                    "Copying or saving this pack does not modify any Claude Code, Codex, or Agents files.",
                    "复制或保存这份上下文包，不会修改任何 Claude Code、Codex 或 Agents 文件。",
                    language: store.appLanguage
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exportText("Markdown Preview", "Markdown 预览", language: store.appLanguage))
                        .font(.headline)
                    Text(store.llmContextPackScopeTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(markdown.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(14)

            Divider()

            ScrollView {
                Text(markdown)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var optionsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                optionGroup(title: exportText("Target", "目标", language: store.appLanguage)) {
                    Picker("", selection: $options.target) {
                        ForEach(LLMContextPackTarget.allCases) { target in
                            Text(targetTitle(target)).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                optionGroup(title: exportText("Path", "路径", language: store.appLanguage)) {
                    Picker("", selection: $options.pathStyle) {
                        ForEach(LLMContextPackPathStyle.allCases) { style in
                            Text(pathStyleTitle(style)).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                optionGroup(title: exportText("Content", "内容", language: store.appLanguage)) {
                    Picker("", selection: $options.detailLevel) {
                        ForEach(LLMContextPackDetailLevel.allCases) { level in
                            Text(detailLevelTitle(level)).tag(level)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                optionGroup(title: "Top N") {
                    Stepper(value: $options.itemLimit, in: 1...30) {
                        HStack {
                            Text(exportText("Items", "项目", language: store.appLanguage))
                            Spacer()
                            Text("\(options.itemLimit)")
                                .font(.callout.monospacedDigit().weight(.semibold))
                        }
                    }
                }

                optionGroup(title: exportText("Language", "语言", language: store.appLanguage)) {
                    Picker("", selection: $options.language) {
                        Text("中文").tag(AppLanguage.simplifiedChinese)
                        Text("English").tag(AppLanguage.english)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let saveMessage {
                Label(saveMessage, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(exportText("Cancel", "取消", language: store.appLanguage)) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                saveMarkdown()
            } label: {
                Label(exportText("Save .md", "保存 .md", language: store.appLanguage), systemImage: "square.and.arrow.down")
            }

            Button {
                copyMarkdown()
            } label: {
                Label(
                    didCopy ? exportText("Copied", "已复制", language: store.appLanguage) : exportText("Copy Markdown", "复制 Markdown", language: store.appLanguage),
                    systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func optionGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        didCopy = true
        saveMessage = exportText("Copied to clipboard.", "已复制到剪贴板。", language: store.appLanguage)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            didCopy = false
        }
    }

    private func saveMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename
        panel.title = exportText("Save LLM Context Pack", "保存 LLM 上下文包", language: store.appLanguage)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            saveMessage = exportText("Saved.", "已保存。", language: store.appLanguage)
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    private var suggestedFilename: String {
        let scope = store.llmContextPackScopeTitle
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "agent-observatory-\(scope)-context-pack.md"
    }

    private func targetTitle(_ target: LLMContextPackTarget) -> String {
        switch (target, store.appLanguage) {
        case (.general, .simplifiedChinese): "通用"
        case (.codex, .simplifiedChinese): "Codex"
        case (.claudeCode, .simplifiedChinese): "Claude"
        case (.general, _): "General"
        case (.codex, _): "Codex"
        case (.claudeCode, _): "Claude"
        }
    }

    private func pathStyleTitle(_ style: LLMContextPackPathStyle) -> String {
        switch (style, store.appLanguage) {
        case (.abbreviated, .simplifiedChinese): "~ 简写"
        case (.full, .simplifiedChinese): "完整路径"
        case (.redactedUser, .simplifiedChinese): "隐藏用户名"
        case (.abbreviated, _): "Abbreviated"
        case (.full, _): "Full path"
        case (.redactedUser, _): "Redacted user"
        }
    }

    private func detailLevelTitle(_ level: LLMContextPackDetailLevel) -> String {
        switch (level, store.appLanguage) {
        case (.summary, .simplifiedChinese): "仅摘要"
        case (.snippets, .simplifiedChinese): "摘要 + 片段"
        case (.summary, _): "Summary only"
        case (.snippets, _): "Summary + snippets"
        }
    }
}

private struct LLMExportPresetButton: View {
    @EnvironmentObject private var store: AssetStore
    let preset: LLMContextPackPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? tint.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.45) : Color(nsColor: .separatorColor).opacity(0.22))
            }
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch preset {
        case .currentView: "rectangle.3.group"
        case .selectedItem: "scope"
        case .migrationCleanup: "arrow.left.arrow.right"
        }
    }

    private var tint: Color {
        switch preset {
        case .currentView: .blue
        case .selectedItem: .teal
        case .migrationCleanup: .orange
        }
    }

    private var title: String {
        switch (preset, store.appLanguage) {
        case (.currentView, .simplifiedChinese): "当前视图"
        case (.selectedItem, .simplifiedChinese): "选中项"
        case (.migrationCleanup, .simplifiedChinese): "迁移/清理"
        case (.currentView, _): "Current view"
        case (.selectedItem, _): "Selected item"
        case (.migrationCleanup, _): "Migration / cleanup"
        }
    }

    private var subtitle: String {
        switch (preset, store.appLanguage) {
        case (.currentView, .simplifiedChinese): "按应用排序，适合整体分析"
        case (.selectedItem, .simplifiedChinese): "只导出当前选中的资产"
        case (.migrationCleanup, .simplifiedChinese): "聚焦单边记忆和风险项"
        case (.currentView, _): "Rank by app for broad analysis"
        case (.selectedItem, _): "Export the active asset"
        case (.migrationCleanup, _): "Focus one-sided memory and risks"
        }
    }
}

private func exportText(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
    switch language {
    case .english: english
    case .simplifiedChinese: simplifiedChinese
    }
}
