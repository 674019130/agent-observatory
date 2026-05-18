import Foundation

public enum ContextTreeAccent: String, Hashable, Sendable {
    case claude
    case codex
    case agents
    case project
    case memory
    case capability
    case mcp
    case neutral
}

public struct ContextTreeNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let systemImage: String
    public let accent: ContextTreeAccent
    public let items: [ContextCatalogItem]
    public let asset: AgentAsset?
    public let children: [ContextTreeNode]
    public let defaultExpanded: Bool

    public var isAsset: Bool {
        asset != nil
    }

    public var memoryCount: Int {
        items.filter { $0.role == .memory }.count
    }

    public var capabilityCount: Int {
        items.filter { $0.role == .capability }.count
    }

    public var flattened: [ContextTreeNode] {
        [self] + children.flatMap(\.flattened)
    }

    public var defaultExpandedIDs: Set<String> {
        var ids: Set<String> = []
        if defaultExpanded && !children.isEmpty {
            ids.insert(id)
        }
        children.forEach { ids.formUnion($0.defaultExpandedIDs) }
        return ids
    }
}

public struct ContextTreeBuilder {
    public let catalog: ContextCatalog
    public let visibleCapabilityItems: [ContextCatalogItem]
    public let searchText: String
    public let language: AppLanguage

    public init(
        catalog: ContextCatalog,
        visibleCapabilityItems: [ContextCatalogItem],
        searchText: String,
        language: AppLanguage
    ) {
        self.catalog = catalog
        self.visibleCapabilityItems = visibleCapabilityItems
        self.searchText = searchText
        self.language = language
    }

    public func nodes() -> [ContextTreeNode] {
        let memoryItems = filtered(catalog.memoryItems)
        let capabilityItems = filtered(visibleCapabilityItems)
        let allItems = memoryItems + capabilityItems

        return [
            surfaceNode(
                id: "surface:claude",
                title: L10n.text(.claudeCode, language: language),
                systemImage: "terminal",
                accent: .claude,
                items: allItems.filter { $0.surfaces.contains(.claude) }
            ),
            surfaceNode(
                id: "surface:codex",
                title: L10n.agentOwner(.codex, language: language),
                systemImage: "cube.transparent",
                accent: .codex,
                items: allItems.filter { $0.surfaces.contains(.codex) }
            ),
            surfaceNode(
                id: "surface:agents",
                title: L10n.text(.sharedAgents, language: language),
                systemImage: "person.2.wave.2",
                accent: .agents,
                items: allItems.filter { $0.asset.owner == .agents }
            ),
            surfaceNode(
                id: "surface:project",
                title: L10n.agentOwner(.project, language: language),
                systemImage: "folder",
                accent: .project,
                items: allItems.filter { $0.asset.owner == .project }
            )
        ]
        .compactMap { $0 }
    }

    private func filtered(_ items: [ContextCatalogItem]) -> [ContextCatalogItem] {
        items
            .filter { $0.asset.matchesSearch(query: searchText) }
            .sorted(by: itemTitleSort)
    }

    private func surfaceNode(
        id: String,
        title: String,
        systemImage: String,
        accent: ContextTreeAccent,
        items: [ContextCatalogItem]
    ) -> ContextTreeNode? {
        let uniqueItems = unique(items)
        guard !uniqueItems.isEmpty else {
            return nil
        }

        let children = [
            roleNode(
                id: "\(id):memory",
                role: .memory,
                items: uniqueItems.filter { $0.role == .memory }
            ),
            roleNode(
                id: "\(id):capability",
                role: .capability,
                items: uniqueItems.filter { $0.role == .capability && $0.asset.kind != .mcp }
            ),
            mcpNode(
                id: "\(id):mcp",
                items: uniqueItems.filter { $0.asset.kind == .mcp }
            )
        ]
        .compactMap { $0 }

        return ContextTreeNode(
            id: id,
            title: title,
            subtitle: countSummary(uniqueItems),
            systemImage: systemImage,
            accent: accent,
            items: uniqueItems,
            asset: nil,
            children: children,
            defaultExpanded: true
        )
    }

    private func roleNode(
        id: String,
        role: AgentContextRole,
        items: [ContextCatalogItem]
    ) -> ContextTreeNode? {
        guard !items.isEmpty else { return nil }

        let children: [ContextTreeNode]
        let title: String
        let systemImage: String
        let accent: ContextTreeAccent

        switch role {
        case .memory:
            title = L10n.text(.memories, language: language)
            systemImage = "brain.head.profile"
            accent = .memory
            children = memoryTypeNodes(parentID: id, items: items)
        case .capability:
            title = L10n.text(.capabilities, language: language)
            systemImage = "wand.and.stars"
            accent = .capability
            children = capabilityCategoryNodes(parentID: id, items: items)
        }

        return ContextTreeNode(
            id: id,
            title: title,
            subtitle: "\(items.count) \(L10n.text(.items, language: language))",
            systemImage: systemImage,
            accent: accent,
            items: items,
            asset: nil,
            children: children,
            defaultExpanded: true
        )
    }

    private func mcpNode(
        id: String,
        items: [ContextCatalogItem]
    ) -> ContextTreeNode? {
        guard !items.isEmpty else { return nil }
        let sections = ContextCapabilityGrouper().sections(items: items)
        let groups = sections.flatMap(\.groups)

        return ContextTreeNode(
            id: id,
            title: "MCP",
            subtitle: "\(items.count) \(L10n.text(.items, language: language))",
            systemImage: "point.3.connected.trianglepath.dotted",
            accent: .mcp,
            items: items,
            asset: nil,
            children: capabilityGroupNodes(parentID: id, groups: groups),
            defaultExpanded: true
        )
    }

    private func memoryTypeNodes(parentID: String, items: [ContextCatalogItem]) -> [ContextTreeNode] {
        AgentMemoryType.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { type in
                let typeItems = items.filter { $0.memoryType == type }
                guard !typeItems.isEmpty else { return nil }
                return ContextTreeNode(
                    id: "\(parentID):type:\(type.rawValue)",
                    title: L10n.memoryType(type, language: language),
                    subtitle: L10n.memoryTypeDescription(type, language: language),
                    systemImage: memoryTypeIcon(type),
                    accent: .memory,
                    items: typeItems,
                    asset: nil,
                    children: assetNodes(parentID: "\(parentID):type:\(type.rawValue)", items: typeItems),
                    defaultExpanded: true
                )
            }
    }

    private func capabilityCategoryNodes(parentID: String, items: [ContextCatalogItem]) -> [ContextTreeNode] {
        ContextCapabilityGrouper()
            .sections(items: items)
            .map { section in
                let sectionID = "\(parentID):category:\(section.category.rawValue)"
                return ContextTreeNode(
                    id: sectionID,
                    title: capabilityCategoryTitle(section.category),
                    subtitle: capabilityCategorySubtitle(section),
                    systemImage: capabilityCategoryIcon(section.category),
                    accent: .capability,
                    items: section.groups.flatMap(\.items),
                    asset: nil,
                    children: capabilityGroupNodes(parentID: sectionID, groups: section.groups),
                    defaultExpanded: !section.category.isLowPriority
                )
            }
    }

    private func capabilityGroupNodes(parentID: String, groups: [ContextCapabilityGroup]) -> [ContextTreeNode] {
        groups.map { group in
            return ContextTreeNode(
                id: "\(parentID):group:\(group.id)",
                title: group.title,
                subtitle: capabilityGroupSubtitle(group),
                systemImage: assetKindIcon(group.primaryKind),
                accent: .capability,
                items: group.items,
                asset: nil,
                children: assetNodes(parentID: "\(parentID):group:\(group.id)", items: group.items),
                defaultExpanded: false
            )
            }
    }

    private func assetNodes(parentID: String, items: [ContextCatalogItem]) -> [ContextTreeNode] {
        items.map { item in
            ContextTreeNode(
                id: "\(parentID):asset:\(item.asset.path)",
                title: item.asset.title,
                subtitle: item.asset.displayPath,
                systemImage: assetKindIcon(item.asset.kind),
                accent: item.role == .memory ? .memory : .capability,
                items: [item],
                asset: item.asset,
                children: [],
                defaultExpanded: false
            )
        }
    }

    private func unique(_ items: [ContextCatalogItem]) -> [ContextCatalogItem] {
        var seen: Set<AgentAsset.ID> = []
        return items.filter { item in
            seen.insert(item.asset.id).inserted
        }
    }

    private func countSummary(_ items: [ContextCatalogItem]) -> String {
        let memories = items.filter { $0.role == .memory }.count
        let mcp = items.filter { $0.asset.kind == .mcp }.count
        let capabilities = items.filter { $0.role == .capability && $0.asset.kind != .mcp }.count
        return "\(memories) \(L10n.text(.memories, language: language)) · \(capabilities) \(L10n.text(.capabilities, language: language)) · \(mcp) MCP"
    }

    private func itemTitleSort(_ left: ContextCatalogItem, _ right: ContextCatalogItem) -> Bool {
        left.asset.title.localizedStandardCompare(right.asset.title) == .orderedAscending
    }

    private func capabilityGroupSubtitle(_ group: ContextCapabilityGroup) -> String {
        let kindSummary = group.kindCounts
            .sorted { left, right in
                if assetKindSortIndex(left.key) != assetKindSortIndex(right.key) {
                    return assetKindSortIndex(left.key) < assetKindSortIndex(right.key)
                }
                return left.key.rawValue < right.key.rawValue
            }
            .map { "\($0.value) \(L10n.assetKind($0.key, language: language))" }
            .joined(separator: " · ")

        if kindSummary.isEmpty {
            return "\(group.items.count) \(L10n.text(.items, language: language))"
        }
        return "\(group.items.count) \(L10n.text(.items, language: language)) · \(kindSummary)"
    }

    private func capabilityCategoryTitle(_ category: ContextCapabilityCategory) -> String {
        switch (category, language) {
        case (.userSkills, .simplifiedChinese): "用户导入的 Skill"
        case (.mcpTools, .simplifiedChinese): "MCP / 工具配置"
        case (.localCapabilities, .simplifiedChinese): "本地命令与配置"
        case (.officialCapabilities, .simplifiedChinese): "官方 / 预置能力"
        case (.otherCapabilities, .simplifiedChinese): "其他能力"
        case (.userSkills, _): "User-Imported Skills"
        case (.mcpTools, _): "MCP / Tool Configuration"
        case (.localCapabilities, _): "Local Commands and Config"
        case (.officialCapabilities, _): "Official / Preset Capabilities"
        case (.otherCapabilities, _): "Other Capabilities"
        }
    }

    private func capabilityCategorySubtitle(_ section: ContextCapabilitySection) -> String {
        switch (section.category, language) {
        case (.officialCapabilities, .simplifiedChinese):
            "\(section.itemCount) \(L10n.text(.items, language: language)) · 低优先级基线"
        case (.officialCapabilities, _):
            "\(section.itemCount) \(L10n.text(.items, language: language)) · Low-priority baseline"
        case (_, .simplifiedChinese):
            "\(section.itemCount) \(L10n.text(.items, language: language)) · \(section.groups.count) 组"
        default:
            "\(section.itemCount) \(L10n.text(.items, language: language)) · \(section.groups.count) groups"
        }
    }

    private func capabilityCategoryIcon(_ category: ContextCapabilityCategory) -> String {
        switch category {
        case .userSkills: "wand.and.stars"
        case .mcpTools: "point.3.connected.trianglepath.dotted"
        case .localCapabilities: "slider.horizontal.3"
        case .officialCapabilities: "building.columns"
        case .otherCapabilities: "tray.full"
        }
    }

    private func assetKindSortIndex(_ kind: AssetKind) -> Int {
        switch kind {
        case .skill: 0
        case .command: 1
        case .mcp: 2
        case .plugin: 3
        case .config: 4
        case .script: 5
        case .instruction: 6
        case .rule: 7
        case .memory: 8
        case .session: 9
        case .unknown: 10
        }
    }
}

private func memoryTypeIcon(_ type: AgentMemoryType) -> String {
    switch type {
    case .longTerm: "brain.head.profile"
    case .project: "folder"
    case .workspace: "rectangle.3.group"
    case .automation: "clock.badge.checkmark"
    case .preference: "slider.horizontal.3"
    case .sessionHistory: "clock.arrow.circlepath"
    case .shared: "person.2"
    case .instructions: "doc.text"
    case .contextRules: "list.bullet.rectangle"
    case .pluginProvided: "puzzlepiece.extension"
    }
}

private func assetKindIcon(_ kind: AssetKind) -> String {
    switch kind {
    case .skill: "wand.and.stars"
    case .command: "command"
    case .memory: "brain.head.profile"
    case .config: "switch.2"
    case .rule: "list.bullet.rectangle"
    case .mcp: "point.3.connected.trianglepath.dotted"
    case .plugin: "puzzlepiece.extension"
    case .instruction: "doc.text"
    case .script: "chevron.left.forwardslash.chevron.right"
    case .session: "clock.arrow.circlepath"
    case .unknown: "questionmark"
    }
}
