import Foundation

public struct ContextCapabilityGrouper: Sendable {
    public init() {}

    public func sections(items: [ContextCatalogItem]) -> [ContextCapabilitySection] {
        let categorizedItems = Dictionary(grouping: items, by: category(for:))
        return ContextCapabilityCategory.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { category in
                guard let items = categorizedItems[category], !items.isEmpty else {
                    return nil
                }
                return ContextCapabilitySection(
                    category: category,
                    groups: groups(items: items)
                )
            }
    }

    public func groups(items: [ContextCatalogItem]) -> [ContextCapabilityGroup] {
        let initialDescriptors = items.map { item in
            (descriptor: descriptor(for: item), item: item)
        }
        let repositoryAliases = repositoryAliases(from: initialDescriptors)
        let repositoryMergedDescriptors = initialDescriptors.map { entry in
            let skillKey = entry.item.asset.normalizedTitleKey
            if entry.item.asset.kind == .skill,
               entry.descriptor.canUseRepositoryAlias,
               let repositoryDescriptor = repositoryAliases[skillKey] {
                return (
                    descriptor: repositoryDescriptor.withBasisKind(.sameNameSkillCopies),
                    item: entry.item
                )
            }
            return entry
        }

        let descriptorCounts = Dictionary(grouping: repositoryMergedDescriptors, by: \.descriptor.groupKey)
            .mapValues(\.count)
        let descriptors = repositoryMergedDescriptors.map { entry in
            let descriptor = entry.descriptor
            if descriptor.isSyntheticFamily,
               descriptorCounts[descriptor.groupKey, default: 0] < 2,
               let fallback = descriptor.fallback {
                return (descriptor: fallback.descriptor, item: entry.item)
            }
            return entry
        }

        return Dictionary(grouping: descriptors, by: \.descriptor.groupKey)
            .map { _, entries in
                makeGroup(entries: entries)
            }
            .sorted(by: groupSort)
    }

    public func category(for item: ContextCatalogItem) -> ContextCapabilityCategory {
        if item.loadRoute.skillInstallOrigin?.isBundled == true {
            return .officialCapabilities
        }

        switch item.asset.kind {
        case .skill:
            return .userSkills
        case .mcp:
            return .mcpTools
        case .command, .plugin, .script, .config:
            return .localCapabilities
        case .memory, .rule, .instruction, .session, .unknown:
            return .otherCapabilities
        }
    }

    private func makeGroup(
        entries: [(descriptor: CapabilityGroupDescriptor, item: ContextCatalogItem)]
    ) -> ContextCapabilityGroup {
        let items = entries.map(\.item).sorted(by: itemSort)
        let descriptor = entries.map(\.descriptor).sorted(by: descriptorSort).first
        let rootPath = descriptor?.rootPath ?? items.first?.asset.path ?? ""
        let primaryKind = primaryKind(for: items)
        let origin = primaryOrigin(for: items)
        let kindCounts = Dictionary(grouping: items.map(\.asset.kind), by: { $0 }).mapValues(\.count)
        let owners = uniqueSorted(items.map(\.asset.owner)) { $0.rawValue < $1.rawValue }
        let surfaces = uniqueSorted(items.flatMap(\.surfaces)) { $0.rawValue < $1.rawValue }
        let title = preferredTitle(from: entries, items: items)
        let subtitle = subtitle(kindCounts: kindCounts, owners: owners)
        let groupingBasis = groupingBasis(from: entries)
        let idInput = "\(descriptor?.groupKey ?? rootPath)\n\(rootPath)\n\(primaryKind.rawValue)\n\(origin?.rawValue ?? "none")"

        return ContextCapabilityGroup(
            id: "capability-group:\(StableHash.hash(idInput))",
            title: title,
            subtitle: subtitle,
            rootPath: rootPath,
            groupingBasis: groupingBasis,
            origin: origin,
            primaryKind: primaryKind,
            kindCounts: kindCounts,
            owners: owners,
            surfaces: surfaces,
            items: items
        )
    }

    private func descriptor(for item: ContextCatalogItem) -> CapabilityGroupDescriptor {
        let asset = item.asset
        let path = asset.path
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents

        if let descriptor = codexPluginDescriptor(components: components) {
            return descriptor
        }

        if let descriptor = claudePluginDescriptor(components: components) {
            return descriptor
        }

        if asset.kind == .skill,
           let descriptor = skillDescriptor(item: item, components: components) {
            return descriptor
        }

        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL.path
        let fallbackTitle = item.asset.kind == .plugin ? item.asset.title : readableLastPathComponent(parentPath)
        return CapabilityGroupDescriptor(
            groupKey: parentPath,
            rootPath: parentPath,
            title: fallbackTitle,
            kind: .fallback,
            basisKind: asset.kind == .mcp ? .mcpConfiguration : .parentDirectory
        )
    }

    private func codexPluginDescriptor(components: [String]) -> CapabilityGroupDescriptor? {
        pluginCacheDescriptor(components: components, marker: ".codex")
    }

    private func claudePluginDescriptor(components: [String]) -> CapabilityGroupDescriptor? {
        let lowercased = components.map { $0.lowercased() }
        guard lowercased.contains(".claude") else { return nil }

        if let cacheDescriptor = pluginCacheDescriptor(components: components, marker: ".claude") {
            return cacheDescriptor
        }

        if let marketplaceDescriptor = pluginMarketplaceDescriptor(components: components) {
            return marketplaceDescriptor
        }

        return nil
    }

    private func pluginCacheDescriptor(components: [String], marker: String) -> CapabilityGroupDescriptor? {
        let lowercased = components.map { $0.lowercased() }
        guard let markerIndex = lowercased.firstIndex(of: marker),
              markerIndex + 4 < components.count,
              lowercased[markerIndex + 1] == "plugins",
              lowercased[markerIndex + 2] == "cache" else {
            return nil
        }

        let pluginIndex = markerIndex + 4
        let pluginName = components[pluginIndex]
        let rootPath = path(from: components, through: pluginIndex)
        return CapabilityGroupDescriptor(
            groupKey: repositoryGroupKey(repositoryName: pluginName),
            rootPath: rootPath,
            title: pluginName,
            kind: .repository,
            basisKind: .pluginBundle
        )
    }

    private func pluginMarketplaceDescriptor(components: [String]) -> CapabilityGroupDescriptor? {
        let lowercased = components.map { $0.lowercased() }
        for collectionName in ["external_plugins", "plugins"] {
            guard let collectionIndex = lowercased.lastIndex(of: collectionName) else { continue }
            let pluginIndex = collectionIndex + 1
            guard pluginIndex < components.count else { continue }
            let pluginName = components[pluginIndex]
            guard pluginName != "marketplaces", pluginName != "cache" else { continue }
            let rootPath = path(from: components, through: pluginIndex)
            return CapabilityGroupDescriptor(
                groupKey: repositoryGroupKey(repositoryName: pluginName),
                rootPath: rootPath,
                title: pluginName,
                kind: .repository,
                basisKind: .pluginBundle
            )
        }

        for index in lowercased.indices.reversed() where lowercased[index] == "plugins" {
            let pluginIndex = index + 1
            guard pluginIndex < components.count else { continue }
            let pluginName = components[pluginIndex]
            guard !pluginName.isEmpty, pluginName != "marketplaces" else { continue }
            let rootPath = path(from: components, through: pluginIndex)
            return CapabilityGroupDescriptor(
                groupKey: repositoryGroupKey(repositoryName: pluginName),
                rootPath: rootPath,
                title: pluginName,
                kind: .repository,
                basisKind: .pluginBundle
            )
        }

        return nil
    }

    private func skillDescriptor(
        item: ContextCatalogItem,
        components: [String]
    ) -> CapabilityGroupDescriptor? {
        let lowercased = components.map { $0.lowercased() }
        guard lowercased.last == "skill.md",
              let skillsIndex = lowercased.lastIndex(of: "skills") else {
            return nil
        }

        let remainingCount = components.count - skillsIndex - 1
        if remainingCount >= 3 {
            let repositoryIndex = skillsIndex + 1
            let rootPath = path(from: components, through: repositoryIndex)
            return CapabilityGroupDescriptor(
                groupKey: repositoryGroupKey(repositoryName: components[repositoryIndex]),
                rootPath: rootPath,
                title: components[repositoryIndex],
                kind: .repository,
                basisKind: .repositorySkillDirectory
            )
        }

        let skillDirectory = URL(fileURLWithPath: item.asset.path).deletingLastPathComponent().standardizedFileURL.path
        if let familyName = flatSkillFamilyName(for: components[skillsIndex + 1]) {
            let skillsRoot = path(from: components, through: skillsIndex)
            let familyDescriptor = CapabilityGroupDescriptor(
                groupKey: "flat-skill-family:\(familyName)",
                rootPath: skillsRoot,
                title: familyName,
                kind: .syntheticFamily,
                basisKind: .skillNameFamily,
                isSyntheticFamily: true,
                fallback: CapabilityGroupFallback(
                    groupKey: skillDirectory,
                    rootPath: skillDirectory,
                    title: item.asset.title,
                    kind: .flatSkill,
                    basisKind: .skillDirectory
                )
            )
            return familyDescriptor
        }

        return CapabilityGroupDescriptor(
            groupKey: skillDirectory,
            rootPath: skillDirectory,
            title: item.asset.title,
            kind: .flatSkill,
            basisKind: .skillDirectory
        )
    }

    private func repositoryAliases(
        from entries: [(descriptor: CapabilityGroupDescriptor, item: ContextCatalogItem)]
    ) -> [String: CapabilityGroupDescriptor] {
        let repositoryEntries = entries.filter { entry in
            entry.item.asset.kind == .skill && entry.descriptor.kind == .repository
        }
        let repositoryCounts = Dictionary(grouping: repositoryEntries, by: \.descriptor.groupKey)
            .mapValues(\.count)
        let entriesBySkillName = Dictionary(grouping: repositoryEntries, by: \.item.asset.normalizedTitleKey)

        return entriesBySkillName.reduce(into: [:]) { aliases, element in
            let (skillName, matches) = element
            let descriptors = uniqueSorted(matches.map(\.descriptor), by: descriptorSort)
            guard let preferred = descriptors.sorted(by: { left, right in
                let leftExact = normalizedRepositoryName(left.title) == skillName
                let rightExact = normalizedRepositoryName(right.title) == skillName
                if leftExact != rightExact {
                    return leftExact
                }

                let leftCount = repositoryCounts[left.groupKey, default: 0]
                let rightCount = repositoryCounts[right.groupKey, default: 0]
                if leftCount != rightCount {
                    return leftCount > rightCount
                }

                return descriptorSort(left, right)
            }).first else {
                return
            }
            aliases[skillName] = preferred
        }
    }

    private func flatSkillFamilyName(for folderName: String) -> String? {
        let normalized = folderName.lowercased()
        let specialFamilies = [
            "build-mcp",
            "peon-ping",
            "google-calendar"
        ]
        if let family = specialFamilies.first(where: { normalized == $0 || normalized.hasPrefix("\($0)-") || normalized.hasPrefix($0) }) {
            return family
        }

        if normalized.hasSuffix("-driven-development") {
            return "driven-development"
        }

        if normalized.hasSuffix("-development") {
            return "development"
        }

        let tokens = normalized
            .split(separator: "-")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard tokens.count >= 2 else { return nil }

        let ignoredFirstTokens: Set<String> = [
            "using",
            "build",
            "with"
        ]
        guard tokens[0].count >= 4, !ignoredFirstTokens.contains(tokens[0]) else {
            return nil
        }
        return tokens[0]
    }

    private func preferredTitle(
        from entries: [(descriptor: CapabilityGroupDescriptor, item: ContextCatalogItem)],
        items: [ContextCatalogItem]
    ) -> String {
        if let title = entries.map(\.descriptor.title).first(where: { !$0.isEmpty }) {
            return title
        }

        if items.count == 1, let item = items.first {
            return item.asset.title
        }

        return readableLastPathComponent(entries.first?.descriptor.rootPath ?? "")
    }

    private func groupingBasis(
        from entries: [(descriptor: CapabilityGroupDescriptor, item: ContextCatalogItem)]
    ) -> ContextCapabilityGroupingBasis {
        let kind = uniqueSorted(entries.map(\.descriptor.basisKind), by: groupingBasisSort)
            .first ?? .parentDirectory
        return .official(kind)
    }

    private func subtitle(kindCounts: [AssetKind: Int], owners: [AgentOwner]) -> String {
        let kindSummary = kindCounts
            .sorted { left, right in
                if assetKindSortIndex(left.key) != assetKindSortIndex(right.key) {
                    return assetKindSortIndex(left.key) < assetKindSortIndex(right.key)
                }
                return left.key.rawValue < right.key.rawValue
            }
            .map { "\($0.value) \($0.key.rawValue)" }
            .joined(separator: " · ")
        let ownerSummary = owners.map(\.shortName).joined(separator: " + ")

        if kindSummary.isEmpty {
            return ownerSummary
        }
        if ownerSummary.isEmpty {
            return kindSummary
        }
        return "\(kindSummary) · \(ownerSummary)"
    }

    private func primaryKind(for items: [ContextCatalogItem]) -> AssetKind {
        Dictionary(grouping: items.map(\.asset.kind), by: { $0 })
            .map { (kind: $0.key, count: $0.value.count) }
            .sorted { left, right in
                if left.count != right.count {
                    return left.count > right.count
                }
                return assetKindSortIndex(left.kind) < assetKindSortIndex(right.kind)
            }
            .first?.kind ?? .unknown
    }

    private func primaryOrigin(for items: [ContextCatalogItem]) -> SkillInstallOrigin? {
        items
            .compactMap(\.loadRoute.skillInstallOrigin)
            .sorted { $0.sortIndex < $1.sortIndex }
            .first
    }

    private func groupSort(_ left: ContextCapabilityGroup, _ right: ContextCapabilityGroup) -> Bool {
        let leftIsGroup = left.items.count > 1
        let rightIsGroup = right.items.count > 1
        if leftIsGroup != rightIsGroup {
            return leftIsGroup
        }

        if left.items.count != right.items.count {
            return left.items.count > right.items.count
        }

        if left.primaryKind != right.primaryKind {
            return assetKindSortIndex(left.primaryKind) < assetKindSortIndex(right.primaryKind)
        }

        let leftOrigin = left.origin?.sortIndex ?? Int.max
        let rightOrigin = right.origin?.sortIndex ?? Int.max
        if leftOrigin != rightOrigin {
            return leftOrigin < rightOrigin
        }

        let titleOrder = left.title.localizedStandardCompare(right.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }

        return left.rootPath.localizedStandardCompare(right.rootPath) == .orderedAscending
    }

    private func descriptorSort(_ left: CapabilityGroupDescriptor, _ right: CapabilityGroupDescriptor) -> Bool {
        let leftKindPriority = descriptorKindPriority(left.kind)
        let rightKindPriority = descriptorKindPriority(right.kind)
        if leftKindPriority != rightKindPriority {
            return leftKindPriority < rightKindPriority
        }

        let leftPathPriority = descriptorPathPriority(left.rootPath)
        let rightPathPriority = descriptorPathPriority(right.rootPath)
        if leftPathPriority != rightPathPriority {
            return leftPathPriority < rightPathPriority
        }

        return left.rootPath.localizedStandardCompare(right.rootPath) == .orderedAscending
    }

    private func itemSort(_ left: ContextCatalogItem, _ right: ContextCatalogItem) -> Bool {
        let titleOrder = left.asset.title.localizedStandardCompare(right.asset.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }

        return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
    }

    private func path(from components: [String], through index: Int) -> String {
        NSString.path(withComponents: Array(components.prefix(index + 1)))
    }

    private func repositoryGroupKey(repositoryName: String) -> String {
        "repository:\(normalizedRepositoryName(repositoryName))"
    }

    private func normalizedRepositoryName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func descriptorKindPriority(_ kind: CapabilityGroupDescriptorKind) -> Int {
        switch kind {
        case .repository: 0
        case .flatSkill: 1
        case .syntheticFamily: 2
        case .fallback: 3
        }
    }

    private func descriptorPathPriority(_ path: String) -> Int {
        if path.contains("/plugins/marketplaces/") {
            return 0
        }
        if path.contains("/.claude/plugins/cache/") {
            return 1
        }
        if path.contains("/.codex/plugins/cache/") {
            return 2
        }
        return 3
    }

    private func readableLastPathComponent(_ path: String) -> String {
        let component = URL(fileURLWithPath: path).lastPathComponent
        return component.isEmpty ? path : component
    }

    private func uniqueSorted<T: Hashable>(_ values: [T], by areInIncreasingOrder: (T, T) -> Bool) -> [T] {
        Array(Set(values)).sorted(by: areInIncreasingOrder)
    }

    private func groupingBasisSort(_ left: ContextCapabilityGroupingBasisKind, _ right: ContextCapabilityGroupingBasisKind) -> Bool {
        groupingBasisSortIndex(left) < groupingBasisSortIndex(right)
    }

    private func groupingBasisSortIndex(_ kind: ContextCapabilityGroupingBasisKind) -> Int {
        switch kind {
        case .sameNameSkillCopies: 0
        case .pluginBundle: 1
        case .repositorySkillDirectory: 2
        case .skillNameFamily: 3
        case .skillDirectory: 4
        case .mcpConfiguration: 5
        case .parentDirectory: 6
        }
    }

    private func assetKindSortIndex(_ kind: AssetKind) -> Int {
        switch kind {
        case .skill: 0
        case .command: 1
        case .mcp: 2
        case .plugin: 3
        case .script: 4
        case .config: 5
        case .rule: 6
        case .instruction: 7
        case .memory: 8
        case .session: 9
        case .unknown: 10
        }
    }
}

private struct CapabilityGroupDescriptor: Hashable {
    let groupKey: String
    let rootPath: String
    let title: String
    var kind: CapabilityGroupDescriptorKind = .fallback
    var basisKind: ContextCapabilityGroupingBasisKind = .parentDirectory
    var isSyntheticFamily = false
    var fallback: CapabilityGroupFallback?

    var canUseRepositoryAlias: Bool {
        kind == .flatSkill || kind == .syntheticFamily
    }

    func withBasisKind(_ basisKind: ContextCapabilityGroupingBasisKind) -> CapabilityGroupDescriptor {
        CapabilityGroupDescriptor(
            groupKey: groupKey,
            rootPath: rootPath,
            title: title,
            kind: kind,
            basisKind: basisKind,
            isSyntheticFamily: isSyntheticFamily,
            fallback: fallback
        )
    }
}

private enum CapabilityGroupDescriptorKind: Hashable {
    case repository
    case flatSkill
    case syntheticFamily
    case fallback
}

private struct CapabilityGroupFallback: Hashable {
    let groupKey: String
    let rootPath: String
    let title: String
    let kind: CapabilityGroupDescriptorKind
    let basisKind: ContextCapabilityGroupingBasisKind

    var descriptor: CapabilityGroupDescriptor {
        CapabilityGroupDescriptor(
            groupKey: groupKey,
            rootPath: rootPath,
            title: title,
            kind: kind,
            basisKind: basisKind
        )
    }
}
