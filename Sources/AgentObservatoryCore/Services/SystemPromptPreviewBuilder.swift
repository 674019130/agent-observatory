import Foundation

public struct SystemPromptPreview: Sendable {
    public let surface: AgentOwner
    public let sections: [SystemPromptPreviewSection]

    public init(surface: AgentOwner, sections: [SystemPromptPreviewSection]) {
        self.surface = surface
        self.sections = sections
    }

    public var promptMaterialItemCount: Int {
        sections
            .filter(\.isPromptMaterial)
            .reduce(0) { $0 + $1.items.count }
    }

    public var registryItemCount: Int {
        sections
            .filter { !$0.isPromptMaterial }
            .reduce(0) { $0 + $1.items.count }
    }

    public var totalItemCount: Int {
        promptMaterialItemCount + registryItemCount
    }

    public var estimatedTokenCount: Int {
        sections.reduce(0) { $0 + $1.estimatedTokenCount }
    }
}

public struct SystemPromptPreviewSection: Identifiable, Sendable {
    public let id: String
    public let role: AgentContextRole
    public let layer: AgentContextLayer
    public let destination: ContextLoadDestination
    public let items: [ContextCatalogItem]
    public let estimatedTokenCount: Int

    public init(
        id: String,
        role: AgentContextRole,
        layer: AgentContextLayer,
        destination: ContextLoadDestination,
        items: [ContextCatalogItem],
        estimatedTokenCount: Int
    ) {
        self.id = id
        self.role = role
        self.layer = layer
        self.destination = destination
        self.items = items
        self.estimatedTokenCount = estimatedTokenCount
    }

    public var isPromptMaterial: Bool {
        destination.isPromptMaterial
    }
}

public struct SystemPromptPreviewBuilder: Sendable {
    public init() {}

    public func preview(
        surface: AgentOwner,
        catalog: ContextCatalog,
        visibleCapabilityItems: [ContextCatalogItem]
    ) -> SystemPromptPreview {
        let sourceItems = catalog.memoryItems + visibleCapabilityItems
        let scopedItems = sourceItems
            .filter { $0.surfaces.contains(surface) }
            .sorted(by: itemSort)

        let grouped = Dictionary(grouping: scopedItems) { item in
            SectionKey(
                role: item.role,
                layer: item.layer,
                destination: item.loadRoute.destination
            )
        }

        let sections = grouped
            .map { key, items in
                let sortedItems = items.sorted(by: itemSort)
                return SystemPromptPreviewSection(
                    id: "\(surface.rawValue)-\(key.role.rawValue)-\(key.layer.rawValue)-\(key.destination.rawValue)",
                    role: key.role,
                    layer: key.layer,
                    destination: key.destination,
                    items: sortedItems,
                    estimatedTokenCount: sortedItems.reduce(0) { $0 + estimatedTokenCount(for: $1) }
                )
            }
            .sorted(by: sectionSort)

        return SystemPromptPreview(surface: surface, sections: sections)
    }

    public func markdown(
        for preview: SystemPromptPreview,
        language: AppLanguage,
        itemLimit: Int? = nil
    ) -> String {
        var lines: [String] = []
        var renderedItemCount = 0
        let surfaceTitle = L10n.agentOwner(preview.surface, language: language)
        let titleSuffix = localized("local system prompt preview", "本地 System Prompt 预览", language: language)
        let promptMaterialLabel = localized("Prompt material", "提示词材料", language: language)
        let registriesLabel = localized("Registries and tools", "注册表与工具", language: language)
        let tokensLabel = localized("Estimated tokens", "估算 token", language: language)
        let placementLabel = localized("Placement", "放置位置", language: language)
        let loadRouteLabel = localized("Load route", "加载说明", language: language)
        let itemsLabel = localized("Items", "项目", language: language)
        let sourceLabel = localized("Source", "来源", language: language)
        let kindLabel = localized("Kind", "类型", language: language)
        let ownerLabel = localized("Owner", "归属", language: language)
        let triggerLabel = localized("Trigger", "触发", language: language)

        lines.append("# \(surfaceTitle) \(titleSuffix)")
        lines.append("")
        lines.append(localized(
            "This is an inspectable local preview. It does not expose the hidden vendor system prompt; it only shows files Agent Observatory can see and classify as prompt material, registries, tools, or support context.",
            "这是一个可检查的本地预览。它不会展示厂商隐藏的 system prompt，只展示 Agent Observatory 能看到并归类为提示词材料、注册表、工具或支持上下文的文件。",
            language: language
        ))
        lines.append("")
        lines.append("- \(promptMaterialLabel): \(preview.promptMaterialItemCount)")
        lines.append("- \(registriesLabel): \(preview.registryItemCount)")
        lines.append("- \(tokensLabel): \(preview.estimatedTokenCount)")

        for section in preview.sections {
            lines.append("")
            lines.append("## \(sectionTitle(section, language: language))")
            lines.append("")
            lines.append("- \(placementLabel): \(L10n.loadDestination(section.destination, language: language))")
            lines.append("- \(loadRouteLabel): \(L10n.loadRouteDescription(route(for: section), language: language))")
            lines.append("- \(itemsLabel): \(section.items.count)")
            lines.append("")

            for item in section.items {
                if let itemLimit, renderedItemCount >= itemLimit {
                    lines.append(localized(
                        "_Preview truncated for display. Copy the full preview to include the remaining local sources._",
                        "_界面预览已截断。复制完整预览会包含剩余本地来源。_",
                        language: language
                    ))
                    return lines.joined(separator: "\n")
                }
                renderedItemCount += 1
                lines.append("### \(item.asset.title)")
                lines.append("")
                lines.append("- \(sourceLabel): `\(item.asset.displayPath)`")
                lines.append("- \(kindLabel): \(item.asset.kind.rawValue)")
                lines.append("- \(ownerLabel): \(L10n.agentOwner(item.asset.owner, language: language))")
                if let trigger = item.asset.trigger, !trigger.isEmpty {
                    lines.append("- \(triggerLabel): \(singleLine(trigger))")
                }
                let excerpt = excerpt(for: item.asset)
                if !excerpt.isEmpty {
                    lines.append("")
                    lines.append("```text")
                    lines.append(excerpt)
                    lines.append("```")
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func route(for section: SystemPromptPreviewSection) -> ContextLoadRoute {
        ContextLoadRoute(
            role: section.role,
            layer: section.layer,
            surfaces: [section.items.first?.surfaces.first ?? .unknown],
            destination: section.destination,
            trigger: section.items.first?.loadRoute.trigger ?? .observatoryIndex
        )
    }

    private func sectionTitle(
        _ section: SystemPromptPreviewSection,
        language: AppLanguage
    ) -> String {
        let layer = L10n.contextLayer(section.layer, language: language)
        let role = L10n.contextRole(section.role, language: language)
        let destination = L10n.loadDestination(section.destination, language: language)
        return "\(layer) · \(role) · \(destination)"
    }

    private func estimatedTokenCount(for item: ContextCatalogItem) -> Int {
        let text = [
            item.asset.title,
            item.asset.summary,
            item.asset.trigger ?? "",
            item.asset.preview
        ]
        .joined(separator: "\n")
        return max(1, text.count / 4)
    }

    private func excerpt(for asset: AgentAsset) -> String {
        let text = asset.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        if text.count <= 900 { return text }
        return String(text.prefix(900)).trimmingCharacters(in: .whitespacesAndNewlines) + "\n..."
    }

    private func singleLine(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func sectionSort(
        _ left: SystemPromptPreviewSection,
        _ right: SystemPromptPreviewSection
    ) -> Bool {
        if left.isPromptMaterial != right.isPromptMaterial {
            return left.isPromptMaterial
        }
        if left.role != right.role {
            return left.role.sortIndex < right.role.sortIndex
        }
        if left.layer != right.layer {
            return left.layer.sortIndex < right.layer.sortIndex
        }
        return left.destination.sortIndex < right.destination.sortIndex
    }

    private func itemSort(_ left: ContextCatalogItem, _ right: ContextCatalogItem) -> Bool {
        if left.role != right.role {
            return left.role.sortIndex < right.role.sortIndex
        }
        if left.layer != right.layer {
            return left.layer.sortIndex < right.layer.sortIndex
        }
        if left.loadRoute.destination != right.loadRoute.destination {
            return left.loadRoute.destination.sortIndex < right.loadRoute.destination.sortIndex
        }
        if left.memoryType != right.memoryType {
            let leftIndex = left.memoryType?.sortIndex ?? Int.max
            let rightIndex = right.memoryType?.sortIndex ?? Int.max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
        }
        if left.asset.kind != right.asset.kind {
            return left.asset.kind.rawValue < right.asset.kind.rawValue
        }
        return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
    }

    private func localized(
        _ english: String,
        _ simplifiedChinese: String,
        language: AppLanguage
    ) -> String {
        switch language {
        case .english: english
        case .simplifiedChinese: simplifiedChinese
        }
    }

    private struct SectionKey: Hashable {
        let role: AgentContextRole
        let layer: AgentContextLayer
        let destination: ContextLoadDestination
    }
}

private extension AgentContextRole {
    var sortIndex: Int {
        switch self {
        case .memory: 0
        case .capability: 1
        }
    }
}

private extension ContextLoadDestination {
    var sortIndex: Int {
        switch self {
        case .systemPrompt: 0
        case .memoryBlock: 1
        case .projectContextBlock: 2
        case .workspaceContextBlock: 3
        case .pluginInstructionBlock: 4
        case .skillRegistry: 5
        case .commandRegistry: 6
        case .toolRegistry: 7
        case .pluginRegistry: 8
        case .configuration: 9
        case .sessionArchive: 10
        case .supportFile: 11
        case .indexOnly: 12
        }
    }
}
