import AgentObservatoryCore
import Foundation

enum ContextTreeAccent: String, Hashable {
    case claude
    case codex
    case agents
    case project
    case memory
    case capability
    case neutral
}

struct ContextTreeNode: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: ContextTreeAccent
    let items: [ContextCatalogItem]
    let asset: AgentAsset?
    let children: [ContextTreeNode]

    var isAsset: Bool {
        asset != nil
    }

    var memoryCount: Int {
        items.filter { $0.role == .memory }.count
    }

    var capabilityCount: Int {
        items.filter { $0.role == .capability }.count
    }

    var flattened: [ContextTreeNode] {
        [self] + children.flatMap(\.flattened)
    }

    var defaultExpandedIDs: Set<String> {
        guard !children.isEmpty else { return [] }
        let childGroupIDs = children
            .filter { !$0.children.isEmpty }
            .map(\.id)
        return Set([id] + childGroupIDs)
    }
}

struct ContextTreeBuilder {
    let catalog: ContextCatalog
    let visibleCapabilityItems: [ContextCatalogItem]
    let searchText: String
    let language: AppLanguage

    func nodes() -> [ContextTreeNode] {
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
                items: uniqueItems.filter { $0.role == .capability }
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
            children: children
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
            children = capabilityBucketNodes(parentID: id, items: items)
        }

        return ContextTreeNode(
            id: id,
            title: title,
            subtitle: "\(items.count) \(L10n.text(.items, language: language))",
            systemImage: systemImage,
            accent: accent,
            items: items,
            asset: nil,
            children: children
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
                    children: assetNodes(parentID: "\(parentID):type:\(type.rawValue)", items: typeItems)
                )
            }
    }

    private func capabilityBucketNodes(parentID: String, items: [ContextCatalogItem]) -> [ContextTreeNode] {
        Dictionary(grouping: items, by: capabilityBucketID)
            .map { bucketID, bucketItems in
                let sortedItems = bucketItems.sorted(by: itemTitleSort)
                return ContextTreeNode(
                    id: "\(parentID):bucket:\(bucketID)",
                    title: capabilityBucketTitle(for: sortedItems[0]),
                    subtitle: "\(sortedItems.count) \(L10n.text(.items, language: language))",
                    systemImage: assetKindIcon(sortedItems[0].asset.kind),
                    accent: .capability,
                    items: sortedItems,
                    asset: nil,
                    children: assetNodes(parentID: "\(parentID):bucket:\(bucketID)", items: sortedItems)
                )
            }
            .sorted { left, right in
                let leftRank = capabilityBucketRank(left.items[0])
                let rightRank = capabilityBucketRank(right.items[0])
                if leftRank != rightRank {
                    return leftRank < rightRank
                }
                return left.title.localizedStandardCompare(right.title) == .orderedAscending
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
                children: []
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
        let capabilities = items.filter { $0.role == .capability }.count
        return "\(memories) \(L10n.text(.memories, language: language)) · \(capabilities) \(L10n.text(.capabilities, language: language))"
    }

    private func capabilityBucketID(_ item: ContextCatalogItem) -> String {
        if item.asset.kind == .skill, let origin = item.loadRoute.skillInstallOrigin {
            return "skill:\(origin.rawValue)"
        }
        return item.asset.kind.rawValue
    }

    private func capabilityBucketTitle(for item: ContextCatalogItem) -> String {
        if item.asset.kind == .skill, let origin = item.loadRoute.skillInstallOrigin {
            return "\(L10n.assetKind(.skill, language: language)) · \(L10n.skillInstallOrigin(origin, language: language))"
        }
        return L10n.assetKind(item.asset.kind, language: language)
    }

    private func capabilityBucketRank(_ item: ContextCatalogItem) -> Int {
        switch item.asset.kind {
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

    private func itemTitleSort(_ left: ContextCatalogItem, _ right: ContextCatalogItem) -> Bool {
        left.asset.title.localizedStandardCompare(right.asset.title) == .orderedAscending
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
