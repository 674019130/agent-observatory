import AgentObservatoryCore
import SwiftUI

private let memoryTypeVisibleBatchSize = 40
private let capabilityGroupVisibleBatchSize = 40

struct ContextOverviewView: View {
    var body: some View {
        ContextTreeView()
    }
}

struct MemoryBrowserView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var selectedMemoryType: AgentMemoryType = .longTerm

    private var filteredItems: [ContextCatalogItem] {
        store.contextCatalog.memoryItems.filter { item in
            item.asset.matchesSearch(query: store.searchText)
        }
    }

    var body: some View {
        MemoryTypeCollectionView(
            title: store.t(.memories),
            subtitle: store.t(.contextBrowserSubtitle),
            systemImage: "brain.head.profile",
            tint: .indigo,
            items: filteredItems,
            selectedType: $selectedMemoryType
        )
        .navigationTitle(store.t(.memories))
    }
}

struct CapabilityBrowserView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var expandedGroupIDs: Set<ContextCapabilityGroup.ID> = []

    private var filteredItems: [ContextCatalogItem] {
        store.visibleNonMCPCapabilityItems.filter { item in
            item.asset.matchesSearch(query: store.searchText)
        }
    }

    private var sections: [ContextCapabilitySection] {
        ContextCapabilityGrouper().sections(items: filteredItems)
    }

    var body: some View {
        CapabilityGroupCollectionView(
            title: store.t(.capabilities),
            subtitle: store.t(.contextBrowserSubtitle),
            systemImage: "puzzlepiece.extension",
            tint: .teal,
            sections: sections,
            tips: OfficialDocTips.tips(
                for: .capabilities,
                language: store.appLanguage
            ),
            showsBundledSkillToggle: true,
            expandedGroupIDs: $expandedGroupIDs
        )
        .navigationTitle(store.t(.capabilities))
    }
}

struct MCPBrowserView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var expandedGroupIDs: Set<ContextCapabilityGroup.ID> = []

    private var filteredItems: [ContextCatalogItem] {
        store.visibleMCPItems.filter { item in
            item.asset.matchesSearch(query: store.searchText)
        }
    }

    private var sections: [ContextCapabilitySection] {
        ContextCapabilityGrouper().sections(items: filteredItems)
    }

    var body: some View {
        CapabilityGroupCollectionView(
            title: "MCP",
            subtitle: mcpBrowserSubtitle(language: store.appLanguage),
            systemImage: "point.3.connected.trianglepath.dotted",
            tint: .orange,
            sections: sections,
            tips: OfficialDocTips.tips(
                for: .mcpTools,
                language: store.appLanguage
            ),
            showsBundledSkillToggle: false,
            expandedGroupIDs: $expandedGroupIDs
        )
        .navigationTitle("MCP")
    }
}

private func mcpBrowserSubtitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "MCP configuration creates callable tools and stays separate from skills and other capabilities."
    case .simplifiedChinese:
        "MCP 配置会生成可调用工具，和 Skill / 能力分开查看。"
    }
}

struct ContextAssemblyView: View {
    @EnvironmentObject private var store: AssetStore

    private var catalog: ContextCatalog { store.contextCatalog }

    var body: some View {
        ScrollView {
            ContextContentStack {
                ContextSectionHeader(
                    title: store.t(.assembly),
                    subtitle: store.t(.contextBrowserSubtitle),
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: .blue
                )

                OfficialDocTipsPanel(
                    tips: OfficialDocTips.tips(
                        for: .assembly,
                        language: store.appLanguage
                    )
                )

                HStack(alignment: .top, spacing: 14) {
                    AssemblyPipeline(surface: .claude, catalog: catalog)
                    AssemblyPipeline(surface: .codex, catalog: catalog)
                }
            }
        }
        .navigationTitle(store.t(.assembly))
    }
}

private struct ContextHeroCard: View {
    @EnvironmentObject private var store: AssetStore
    let catalog: ContextCatalog

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.t(.contextBrowser))
                        .font(.title2.weight(.semibold))
                    Text(store.t(.contextBrowserSubtitle))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
            }

            HStack(spacing: 8) {
                ContextSurfaceMiniPill(surface: .claude, catalog: catalog)
                ContextSurfaceMiniPill(surface: .codex, catalog: catalog)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }
}

private struct ContextContentStack<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ContextMetricCard: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }

            Text("\(value)")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Button(action: action) {
                Text(actionTitle)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ContextSurfaceCard: View {
    @EnvironmentObject private var store: AssetStore
    let surface: AgentOwner
    let catalog: ContextCatalog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(surfaceTitle, systemImage: surfaceIcon(surface))
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 8) {
                BadgeView(text: "\(catalog.memoryCount(for: surface)) \(store.t(.memories))", tint: .indigo)
                BadgeView(text: "\(visibleCapabilityCount) \(store.t(.capabilities))", tint: .teal)
            }

            Divider()

            ForEach(memoryRows.prefix(4), id: \.0) { type, count in
                Button {
                    store.showMemories()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: memoryTypeIcon(type))
                            .foregroundStyle(memoryTypeTint(type))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.memoryType(type, language: store.appLanguage))
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text("\(count) \(store.t(.items))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .rowHitTarget(cornerRadius: 7)
                }
                .buttonStyle(.plain)
            }

            ForEach(capabilitySteps.prefix(2)) { step in
                Button {
                    store.focusAsset(path: step.items.first?.asset.path)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: contextRoleIcon(step.role))
                            .foregroundStyle(contextRoleTint(step.role))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stepTitle(step))
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text("\(step.items.count) \(store.t(.items))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .rowHitTarget(cornerRadius: 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }

    private var surfaceTitle: String {
        surface == .claude ? store.t(.claudeCode) : L10n.agentOwner(surface, language: store.appLanguage)
    }

    private var memoryRows: [(AgentMemoryType, Int)] {
        AgentMemoryType.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { ($0, catalog.memoryCount(for: surface, type: $0)) }
            .filter { $0.1 > 0 }
    }

    private var capabilitySteps: [ContextAssemblyStep] {
        visibleAssemblySteps(for: surface, catalog: catalog, store: store).filter { $0.role == .capability }
    }

    private var visibleCapabilityCount: Int {
        store.visibleCapabilityItems.filter { $0.surfaces.contains(surface) }.count
    }

    private func stepTitle(_ step: ContextAssemblyStep) -> String {
        "\(contextRoleTitle(step.role, language: store.appLanguage)) · \(assemblyLayerTitle(step.layer, language: store.appLanguage))"
    }
}

private struct ContextSurfaceMiniPill: View {
    @EnvironmentObject private var store: AssetStore
    let surface: AgentOwner
    let catalog: ContextCatalog

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: surfaceIcon(surface))
            Text(surface == .claude ? store.t(.claudeCode) : L10n.agentOwner(surface, language: store.appLanguage))
            Text("\(catalog.memoryCount(for: surface) + visibleCapabilityCount)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ownerTint(surface).opacity(0.12), in: Capsule())
        .foregroundStyle(ownerTint(surface))
    }

    private var visibleCapabilityCount: Int {
        store.visibleCapabilityItems.filter { $0.surfaces.contains(surface) }.count
    }
}

private struct ContextLayerSummary: View {
    @EnvironmentObject private var store: AssetStore
    let catalog: ContextCatalog

    private var rows: [(AgentContextLayer, Int)] {
        let allItems = catalog.memoryItems + store.visibleCapabilityItems
        return AgentContextLayer.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { layer in
                let count = allItems.filter { $0.layer == layer }.count
                return count > 0 ? (layer, count) : nil
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(store.t(.layer), systemImage: "square.stack.3d.up")
                .font(.headline)

            if rows.isEmpty {
                Text(store.t(.noContextItems))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows, id: \.0) { layer, count in
                    HStack {
                        Image(systemName: contextLayerIcon(layer))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(assemblyLayerTitle(layer, language: store.appLanguage))
                        Spacer()
                        CountBadge(count: count, tint: .secondary)
                    }
                    .font(.callout)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }
}

private struct CapabilityGroupCollectionView: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let sections: [ContextCapabilitySection]
    let tips: [OfficialDocTip]
    let showsBundledSkillToggle: Bool
    @Binding var expandedGroupIDs: Set<ContextCapabilityGroup.ID>

    private var isSearching: Bool {
        !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var effectiveExpandedGroupIDs: Set<ContextCapabilityGroup.ID> {
        isSearching ? Set(sections.flatMap { $0.groups.map(\.id) }) : expandedGroupIDs
    }

    var body: some View {
        ScrollView {
            ContextContentStack {
                ContextSectionHeader(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage,
                    tint: tint
                )

                OfficialDocTipsPanel(tips: tips)

                if showsBundledSkillToggle {
                    SkillVisibilityControl()
                }

                if sections.isEmpty {
                    EmptyStateView(
                        title: store.t(.noContextItems),
                        message: store.t(.contextDetailPlaceholderMessage),
                        systemImage: "tray"
                    )
                    .frame(minHeight: 260)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(sections) { section in
                            CapabilityCategorySectionView(
                                section: section,
                                expandedGroupIDs: effectiveExpandedGroupIDs,
                                toggle: toggle
                            )
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ group: ContextCapabilityGroup) {
        if expandedGroupIDs.contains(group.id) {
            expandedGroupIDs.remove(group.id)
        } else {
            expandedGroupIDs.insert(group.id)
        }
    }
}

private struct CapabilityCategorySectionView: View {
    @EnvironmentObject private var store: AssetStore
    let section: ContextCapabilitySection
    let expandedGroupIDs: Set<ContextCapabilityGroup.ID>
    let toggle: (ContextCapabilityGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: capabilityCategoryIcon(section.category))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(capabilityCategoryTint(section.category))
                    .frame(width: 24, height: 24)
                    .background(
                        capabilityCategoryTint(section.category).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(capabilityCategoryTitle(section.category, language: store.appLanguage))
                            .font(.headline)

                        CountBadge(count: section.itemCount, tint: capabilityCategoryTint(section.category))

                        if section.category.isLowPriority {
                            BadgeView(
                                text: lowPriorityLabel(language: store.appLanguage),
                                tint: .secondary
                            )
                        }
                    }

                    Text(capabilityCategoryDisplayDescription(section, language: store.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(section.groups.enumerated()), id: \.element.id) { index, group in
                    CapabilityGroupRow(
                        group: group,
                        isExpanded: expandedGroupIDs.contains(group.id),
                        toggle: {
                            toggle(group)
                        }
                    )

                    if index < section.groups.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.36))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(section.category.isLowPriority ? 0.58 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(section.category.isLowPriority ? 0.32 : 0.45))
        }
    }
}

private struct CapabilityGroupRow: View {
    @EnvironmentObject private var store: AssetStore
    @State private var visibleItemLimit = capabilityGroupVisibleBatchSize
    @State private var isHovering = false
    let group: ContextCapabilityGroup
    let isExpanded: Bool
    let toggle: () -> Void

    private var visibleItems: ArraySlice<ContextCatalogItem> {
        group.items.prefix(visibleItemLimit)
    }

    private var hasMoreItems: Bool {
        group.items.count > visibleItemLimit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 20)

                    Image(systemName: assetKindIcon(group.primaryKind))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(capabilityKindTint(group.primaryKind))
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(group.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(capabilityGroupCountLabel(group, language: store.appLanguage))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(capabilityKindTint(group.primaryKind))
                                .lineLimit(1)
                        }

                        Text(capabilityGroupPreview(group, language: store.appLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 10)

                    HStack(spacing: 5) {
                        if let origin = group.origin {
                            CapabilityGroupTag(
                                text: L10n.skillInstallOrigin(origin, language: store.appLanguage),
                                tint: skillInstallOriginTint(origin)
                            )
                        }

                        ForEach(group.owners.prefix(2), id: \.self) { owner in
                            CapabilityGroupTag(text: ownerLabel(owner), tint: ownerTint(owner))
                        }
                    }
                    .layoutPriority(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(minHeight: 58)
                .background(
                    isHovering ? Color.accentColor.opacity(0.055) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }

            if isExpanded {
                CapabilityGroupExpandedMeta(group: group)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                LazyVStack(spacing: 6) {
                    ForEach(visibleItems) { item in
                        ContextItemRow(item: item)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

                if hasMoreItems {
                    Button {
                        visibleItemLimit += capabilityGroupVisibleBatchSize
                    } label: {
                        Label(
                            String(
                                format: store.t(.showingItems),
                                min(visibleItemLimit, group.items.count),
                                group.items.count
                            ),
                            systemImage: "chevron.down"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .onChange(of: group.id) { _, _ in
            visibleItemLimit = capabilityGroupVisibleBatchSize
        }
        .onChange(of: group.items.count) { _, _ in
            visibleItemLimit = capabilityGroupVisibleBatchSize
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                visibleItemLimit = capabilityGroupVisibleBatchSize
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ownerLabel(_ owner: AgentOwner) -> String {
        owner == .claude ? store.t(.claudeCode) : L10n.agentOwner(owner, language: store.appLanguage)
    }
}

private struct CapabilityGroupExpandedMeta: View {
    @EnvironmentObject private var store: AssetStore
    let group: ContextCapabilityGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)

                PathPreviewLink(
                    path: group.rootPath,
                    displayPath: displayPath(group.rootPath),
                    font: .caption2.monospaced(),
                    foregroundColor: .secondary.opacity(0.72),
                    language: store.appLanguage
                )
            }

            CapabilityGroupingBasisLine(basis: group.groupingBasis)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.64), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct CapabilityGroupTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct CapabilityGroupingBasisLine: View {
    @EnvironmentObject private var store: AssetStore
    let basis: ContextCapabilityGroupingBasis

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(groupingBasisPrefix(language: store.appLanguage))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(groupingBasisTitle(basis.kind, language: store.appLanguage))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if basis.kind == .sameNameSkillCopies {
                BadgeView(text: viewOnlyGroupingLabel(language: store.appLanguage), tint: .secondary)
            }

            if let sourceURL = basis.sourceURL,
               let url = URL(string: sourceURL) {
                Link(groupingBasisSourceLabel(language: store.appLanguage), destination: url)
                    .font(.caption2.weight(.medium))
                    .help(sourceHelpText(basis: basis, language: store.appLanguage))
            }

            if let sourceLocation = basis.sourceLocation {
                Text(sourceLocation)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct MemoryTypeCollectionView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var visibleItemLimit = memoryTypeVisibleBatchSize
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let items: [ContextCatalogItem]
    @Binding var selectedType: AgentMemoryType

    private var groups: [(AgentMemoryType, [ContextCatalogItem])] {
        AgentMemoryType.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { type in
                (
                    type,
                    items
                        .filter { $0.memoryType == type }
                        .sorted(by: itemTitleSort)
                )
            }
    }

    private var selectedItems: [ContextCatalogItem] {
        groups.first { $0.0 == selectedType }?.1 ?? []
    }

    private var presenceGroups: [MemoryPresenceGroup] {
        MemoryMigrationPlanner().groups(items: items)
    }

    private var selectedPresenceGroups: [MemoryPresenceGroup] {
        MemoryMigrationPlanner().groups(items: selectedItems)
    }

    private var visiblePresenceGroups: ArraySlice<MemoryPresenceGroup> {
        selectedPresenceGroups.prefix(visibleItemLimit)
    }

    private var availabilitySignature: String {
        groups.map { "\($0.0.rawValue):\($0.1.count)" }.joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            ContextContentStack {
                ContextSectionHeader(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage,
                    tint: tint
                )

                OfficialDocTipsPanel(
                    tips: OfficialDocTips.tips(
                        for: .memories,
                        language: store.appLanguage
                    )
                )

                MemoryMigrationOverview(groups: presenceGroups)

                if let error = store.managementError {
                    ManagementErrorBanner(message: error)
                }

                if let memoryMigrationStatus = store.memoryMigrationStatus {
                    MemoryMigrationStatusBanner(message: memoryMigrationStatus)
                }

                MemoryTypeNavigator(
                    groups: groups,
                    selectedType: $selectedType
                )

                FocusedMemoryTypeSection(
                    type: selectedType,
                    items: selectedItems,
                    groups: selectedPresenceGroups,
                    visibleGroups: visiblePresenceGroups,
                    hasMoreItems: selectedPresenceGroups.count > visibleItemLimit,
                    visibleCount: min(selectedPresenceGroups.count, visibleItemLimit),
                    showMore: {
                        visibleItemLimit += memoryTypeVisibleBatchSize
                    }
                )
            }
        }
        .onAppear {
            let targetItems = selectFirstUsefulType()
            syncDetailSelection(using: targetItems)
        }
        .onChange(of: selectedType) { _, _ in
            visibleItemLimit = memoryTypeVisibleBatchSize
            syncDetailSelection()
        }
        .onChange(of: availabilitySignature) { _, _ in
            visibleItemLimit = memoryTypeVisibleBatchSize
            let targetItems = selectFirstUsefulType()
            syncDetailSelection(using: targetItems)
        }
    }

    private func selectFirstUsefulType() -> [ContextCatalogItem] {
        guard !items.isEmpty else { return [] }
        let currentItems = groups.first { $0.0 == selectedType }?.1 ?? []
        guard currentItems.isEmpty, let firstPopulatedGroup = groups.first(where: { !$0.1.isEmpty }) else {
            return currentItems
        }
        selectedType = firstPopulatedGroup.0
        return firstPopulatedGroup.1
    }

    private func syncDetailSelection(using targetItems: [ContextCatalogItem]? = nil) {
        let nextItems = targetItems ?? selectedItems
        guard let firstItem = nextItems.first else {
            store.selectedAssetID = nil
            return
        }
        store.focusAsset(path: firstItem.asset.path)
    }
}

private struct MemoryTypeNavigator: View {
    @EnvironmentObject private var store: AssetStore
    let groups: [(AgentMemoryType, [ContextCatalogItem])]
    @Binding var selectedType: AgentMemoryType

    private let columns = [
        GridItem(.adaptive(minimum: 178), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.t(.memoryTypeOverview))
                    .font(.headline)
                Spacer()
                Text(store.t(.chooseMemoryType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(groups, id: \.0) { type, items in
                    MemoryTypeTile(
                        type: type,
                        count: items.count,
                        isSelected: selectedType == type,
                        action: {
                            selectedType = type
                        }
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct MemoryTypeTile: View {
    @EnvironmentObject private var store: AssetStore
    let type: AgentMemoryType
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: memoryTypeIcon(type))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(memoryTypeTint(type))
                    .frame(width: 24, height: 24)
                    .background(memoryTypeTint(type).opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.memoryType(type, language: store.appLanguage))
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("\(count) \(store.t(.items))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 10)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowHitTarget()
            .background(tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor).opacity(0.25))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var tileBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        return Color(nsColor: .windowBackgroundColor)
    }
}

private struct MemoryMigrationOverview: View {
    @EnvironmentObject private var store: AssetStore
    let groups: [MemoryPresenceGroup]

    private var claudeOnlyCount: Int {
        groups.filter { $0.status == .claudeOnly }.count
    }

    private var codexOnlyCount: Int {
        groups.filter { $0.status == .codexOnly }.count
    }

    private var bothSidesCount: Int {
        groups.filter { $0.status == .bothSides }.count
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.indigo)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(memoryMigrationOverviewTitle(language: store.appLanguage))
                        .font(.headline)
                    Text(memoryMigrationOverviewDescription(language: store.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                MemoryMigrationMetric(
                    title: memoryPresenceStatusTitle(.claudeOnly, language: store.appLanguage),
                    count: claudeOnlyCount,
                    systemImage: "terminal",
                    tint: .orange
                )
                MemoryMigrationMetric(
                    title: memoryPresenceStatusTitle(.codexOnly, language: store.appLanguage),
                    count: codexOnlyCount,
                    systemImage: "scope",
                    tint: .blue
                )
                MemoryMigrationMetric(
                    title: memoryPresenceStatusTitle(.bothSides, language: store.appLanguage),
                    count: bothSidesCount,
                    systemImage: "checkmark.seal",
                    tint: .green
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct MemoryMigrationMetric: View {
    let title: String
    let count: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25))
        }
    }
}

private struct MemoryMigrationStatusBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.green.opacity(0.22))
            }
    }
}

private struct MemoryPresenceGroupRow: View {
    @EnvironmentObject private var store: AssetStore
    @State private var presentedMigrationDraft: MemoryMigrationDraft?
    @State private var isHovering = false
    let group: MemoryPresenceGroup

    private var isSelected: Bool {
        guard let selectedAssetID = store.selectedAssetID else { return false }
        return group.items.contains { $0.asset.id == selectedAssetID }
    }

    private var migrationDraft: MemoryMigrationDraft? {
        if let claudeItem = group.migratableClaudeItem,
           let plan = store.memoryMigrationPlan(for: claudeItem.asset, to: .codex) {
            return MemoryMigrationDraft(
                asset: claudeItem.asset,
                target: .codex,
                plan: plan,
                existingTargetPath: store.existingMemoryTargetPath(
                    for: claudeItem.asset,
                    to: .codex,
                    plannedDestinationPath: plan.destinationPath
                )
            )
        }

        if let codexItem = group.migratableCodexItem,
           let plan = store.memoryMigrationPlan(for: codexItem.asset, to: .claude) {
            return MemoryMigrationDraft(
                asset: codexItem.asset,
                target: .claude,
                plan: plan,
                existingTargetPath: store.existingMemoryTargetPath(
                    for: codexItem.asset,
                    to: .claude,
                    plannedDestinationPath: plan.destinationPath
                )
            )
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.indigo)
                    .frame(width: 18)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)

                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                BadgeView(
                                    text: memoryPresenceStatusTitle(group.status, language: store.appLanguage),
                                    tint: memoryPresenceStatusTint(group.status)
                                )

                                if group.items.count > 1 {
                                    CountBadge(count: group.items.count, tint: .secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let migrationDraft {
                            MemoryMigrationCompactButton(
                                draft: migrationDraft,
                                open: { draft in
                                    presentedMigrationDraft = draft
                                }
                            )
                            .padding(.top, -2)
                            .opacity(isSelected || isHovering ? 1 : 0.82)
                        }
                    }

                    if let summary = group.primaryItem?.asset.summary,
                       !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    MemoryPresenceSourceLine(group: group)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                store.focusAsset(path: group.primaryItem?.asset.path)
            }
            .accessibilityAddTraits(.isButton)
        }
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .windowBackgroundColor),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.38))
        }
        .sheet(item: $presentedMigrationDraft) { draft in
            MemoryMigrationDetailSheet(draft: draft)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct MemoryPresenceSourceLine: View {
    @EnvironmentObject private var store: AssetStore
    let group: MemoryPresenceGroup

    var body: some View {
        Group {
            if let claudeItem = group.claudeItems.first {
                MemoryPresencePathRow(title: store.t(.claudeCode), tint: .orange, item: claudeItem)
            } else if let codexItem = group.codexItems.first {
                MemoryPresencePathRow(title: "Codex", tint: .blue, item: codexItem)
            } else if let sharedItem = group.sharedItems.first {
                MemoryPresencePathRow(
                    title: memorySharedLocationTitle(language: store.appLanguage),
                    tint: .green,
                    item: sharedItem
                )
            }
        }
    }
}

private struct MemoryPresencePathRow: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let tint: Color
    let item: ContextCatalogItem

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            BadgeView(text: title, tint: tint)
            PathPreviewLink(
                path: item.asset.path,
                displayPath: item.asset.displayPath,
                font: .caption2.monospaced(),
                foregroundColor: .secondary.opacity(0.7),
                lineLimit: 2,
                language: store.appLanguage
            )
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
    }
}

private struct FocusedMemoryTypeSection: View {
    @EnvironmentObject private var store: AssetStore
    let type: AgentMemoryType
    let items: [ContextCatalogItem]
    let groups: [MemoryPresenceGroup]
    let visibleGroups: ArraySlice<MemoryPresenceGroup>
    let hasMoreItems: Bool
    let visibleCount: Int
    let showMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: memoryTypeIcon(type))
                    .foregroundStyle(memoryTypeTint(type))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.memoryType(type, language: store.appLanguage))
                        .font(.headline)
                    Text(L10n.memoryTypeDescription(type, language: store.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)
                CountBadge(count: items.count, tint: items.isEmpty ? .secondary : memoryTypeTint(type))
            }

            if items.isEmpty {
                Text(store.t(.noContextItems))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                HStack {
                    Text(String(format: store.t(.showingItems), visibleCount, groups.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                LazyVStack(spacing: 6) {
                    ForEach(visibleGroups) { group in
                        MemoryPresenceGroupRow(group: group)
                    }
                }

                if hasMoreItems {
                    Button(action: showMore) {
                        Label(store.t(.showMore), systemImage: "chevron.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct ContextSectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SkillVisibilityControl: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        HStack(spacing: 8) {
            Label(store.t(.userSkillsOnly), systemImage: "wand.and.stars")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            if store.bundledSkillCount > 0 && !store.includeBundledSkills {
                Text(String(format: store.t(.bundledSkillsHidden), store.bundledSkillCount))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.includeBundledSkills.toggle()
            } label: {
                Label(
                    store.includeBundledSkills ? store.t(.hideBundledSkills) : store.t(.showBundledSkills),
                    systemImage: store.includeBundledSkills ? "eye.slash" : "eye"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct ContextItemRow: View {
    @EnvironmentObject private var store: AssetStore
    let item: ContextCatalogItem

    private var isSelected: Bool {
        store.selectedAssetID == item.asset.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: assetKindIcon(item.asset.kind))
                .foregroundStyle(contextRoleTint(item.role))
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.asset.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    BadgeView(text: L10n.assetKind(item.asset.kind, language: store.appLanguage), tint: contextRoleTint(item.role))
                    if let skillInstallOrigin = item.loadRoute.skillInstallOrigin {
                        BadgeView(
                            text: L10n.skillInstallOrigin(skillInstallOrigin, language: store.appLanguage),
                            tint: skillInstallOriginTint(skillInstallOrigin)
                        )
                    }
                    BadgeView(text: ownerLabel(item.asset.owner), tint: ownerTint(item.asset.owner))
                }

                Text(item.asset.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    PathPreviewLink(
                        path: item.asset.path,
                        displayPath: item.asset.displayPath,
                        font: .caption2.monospaced(),
                        foregroundColor: .secondary.opacity(0.65),
                        language: store.appLanguage
                    )
                    Spacer()
                    CompactStatusPills(flags: item.asset.statusFlags)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowHitTarget()
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .onTapGesture {
            store.focusAsset(path: item.asset.path)
        }
    }

    private func ownerLabel(_ owner: AgentOwner) -> String {
        owner == .claude ? store.t(.claudeCode) : L10n.agentOwner(owner, language: store.appLanguage)
    }
}

private struct CompactStatusPills: View {
    @EnvironmentObject private var store: AssetStore
    let flags: [AssetStatusFlag]

    var body: some View {
        HStack(spacing: 4) {
            if flags.isEmpty {
                Text(store.t(.ok))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(flags.prefix(2)) { flag in
                    BadgeView(text: L10n.shortStatusFlag(flag, language: store.appLanguage), tint: statusTint(flag))
                }
            }
        }
    }

    private func statusTint(_ flag: AssetStatusFlag) -> Color {
        switch flag {
        case .duplicate: .purple
        case .stalePath, .secretRisk, .unreadable: .red
        case .hasScripts: .green
        case .needsSummary, .largeFile: .orange
        }
    }
}

private struct AssemblyPipeline: View {
    @EnvironmentObject private var store: AssetStore
    let surface: AgentOwner
    let catalog: ContextCatalog

    private var steps: [ContextAssemblyStep] {
        visibleAssemblySteps(for: surface, catalog: catalog, store: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(surface == .claude ? store.t(.claudeCode) : L10n.agentOwner(surface, language: store.appLanguage), systemImage: surfaceIcon(surface))
                    .font(.headline)
                Spacer()
                CountBadge(count: steps.count, tint: ownerTint(surface))
            }

            if steps.isEmpty {
                Text(store.t(.contextPipelineEmpty))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        AssemblyStepRow(index: index + 1, step: step)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }
}

private struct AssemblyStepRow: View {
    @EnvironmentObject private var store: AssetStore
    let index: Int
    let step: ContextAssemblyStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                store.focusAsset(path: step.items.first?.asset.path)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(contextRoleTint(step.role), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(contextRoleTitle(step.role, language: store.appLanguage)) · \(assemblyLayerTitle(step.layer, language: store.appLanguage))")
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text("\(step.items.count) \(store.t(.items))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rowHitTarget(cornerRadius: 7)
                }
                .buttonStyle(.plain)

            ForEach(Array(step.items.prefix(3))) { item in
                Button {
                    store.focusAsset(path: item.asset.path)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: assetKindIcon(item.asset.kind))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(item.asset.title)
                            .lineLimit(1)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rowHitTarget(cornerRadius: 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@MainActor
private func visibleAssemblySteps(
    for surface: AgentOwner,
    catalog: ContextCatalog,
    store: AssetStore
) -> [ContextAssemblyStep] {
    let memoryItems = catalog.memoryItems.filter { $0.surfaces.contains(surface) }
    let capabilityItems = store.visibleCapabilityItems.filter { $0.surfaces.contains(surface) }
    let items = memoryItems + capabilityItems

    return AgentContextRole.allCases.flatMap { role in
        AgentContextLayer.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { layer in
                let layerItems = items.filter { $0.role == role && $0.layer == layer }
                guard !layerItems.isEmpty else { return nil }
                return ContextAssemblyStep(surface: surface, role: role, layer: layer, items: layerItems)
            }
    }
}

private func itemTitleSort(_ left: ContextCatalogItem, _ right: ContextCatalogItem) -> Bool {
    left.asset.title.localizedStandardCompare(right.asset.title) == .orderedAscending
}

private func contextRoleTitle(_ role: AgentContextRole, language: AppLanguage) -> String {
    switch role {
    case .memory:
        L10n.text(.contextRoleMemory, language: language)
    case .capability:
        L10n.text(.contextRoleCapability, language: language)
    }
}

private func memoryLayerTitle(_ layer: AgentContextLayer, language: AppLanguage) -> String {
    switch layer {
    case .global:
        L10n.text(.longTermMemory, language: language)
    case .project:
        L10n.text(.projectMemory, language: language)
    case .workspace:
        L10n.text(.workspaceMemory, language: language)
    case .shared:
        L10n.text(.sharedContext, language: language)
    case .pluginProvided:
        L10n.text(.pluginProvidedContext, language: language)
    case .configuration:
        L10n.text(.configurationContext, language: language)
    case .session:
        L10n.text(.sessionContext, language: language)
    }
}

private func assemblyLayerTitle(_ layer: AgentContextLayer, language: AppLanguage) -> String {
    switch layer {
    case .global:
        L10n.text(.contextLayerGlobal, language: language)
    case .project:
        L10n.text(.contextLayerProject, language: language)
    case .workspace:
        L10n.text(.contextLayerWorkspace, language: language)
    case .shared:
        L10n.text(.sharedContext, language: language)
    case .pluginProvided:
        L10n.text(.pluginProvidedContext, language: language)
    case .configuration:
        L10n.text(.configurationContext, language: language)
    case .session:
        L10n.text(.sessionContext, language: language)
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

private func capabilityCategoryTitle(_ category: ContextCapabilityCategory, language: AppLanguage) -> String {
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

private func capabilityCategoryDescription(_ category: ContextCapabilityCategory, language: AppLanguage) -> String {
    switch (category, language) {
    case (.userSkills, .simplifiedChinese):
        "优先处理用户安装、迁移或项目本地维护的 Skill。"
    case (.mcpTools, .simplifiedChinese):
        "MCP 配置生成工具注册，不和 Skill 混在同一个列表里。"
    case (.localCapabilities, .simplifiedChinese):
        "用户侧命令、插件、脚本和配置，通常用于运行时或工作流接入。"
    case (.officialCapabilities, .simplifiedChinese):
        "来自 Figma、Vercel、Netlify、Build macOS Apps 等官方或精选插件包，默认作为低优先级基线。"
    case (.otherCapabilities, .simplifiedChinese):
        "暂时无法归入主要处理队列的能力文件，先保留为待确认。"
    case (.userSkills, _):
        "Prioritize skills the user installed, migrated, or maintains locally."
    case (.mcpTools, _):
        "MCP configuration creates tool registrations and stays separate from skills."
    case (.localCapabilities, _):
        "User-side commands, plugins, scripts, and config for runtime or workflow wiring."
    case (.officialCapabilities, _):
        "Official or curated bundles such as Figma, Vercel, Netlify, and Build macOS Apps are treated as low-priority baseline."
    case (.otherCapabilities, _):
        "Capability files that do not fit the main review queues yet."
    }
}

private func capabilityCategoryDisplayDescription(_ section: ContextCapabilitySection, language: AppLanguage) -> String {
    let description = capabilityCategoryDescription(section.category, language: language)
    switch language {
    case .simplifiedChinese:
        return "\(section.groups.count) 组 · \(description)"
    case .english:
        return "\(section.groups.count) groups · \(description)"
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

private func capabilityCategoryTint(_ category: ContextCapabilityCategory) -> Color {
    switch category {
    case .userSkills: .teal
    case .mcpTools: .orange
    case .localCapabilities: .blue
    case .officialCapabilities: .secondary
    case .otherCapabilities: .secondary
    }
}

private func lowPriorityLabel(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "低优先级" : "Low Priority"
}

private func memoryMigrationOverviewTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Memory availability"
    case .simplifiedChinese:
        "记忆在两边的存在情况"
    }
}

private func memoryMigrationOverviewDescription(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Check whether a memory exists in Claude Code, Codex, or both before copying one-sided memories to the other side."
    case .simplifiedChinese:
        "先看每条记忆是在 Claude Code、Codex，还是两边都有；只在一边的记忆可以再复制到另一边。"
    }
}

private func memoryPresenceStatusTitle(_ status: MemoryPresenceStatus, language: AppLanguage) -> String {
    switch (status, language) {
    case (.claudeOnly, .simplifiedChinese):
        "仅 Claude Code"
    case (.codexOnly, .simplifiedChinese):
        "仅 Codex"
    case (.bothSides, .simplifiedChinese):
        "两边都有"
    case (.sharedOnly, .simplifiedChinese):
        "共享来源"
    case (.unknown, .simplifiedChinese):
        "未知来源"
    case (.claudeOnly, _):
        "Claude Code only"
    case (.codexOnly, _):
        "Codex only"
    case (.bothSides, _):
        "Both sides"
    case (.sharedOnly, _):
        "Shared source"
    case (.unknown, _):
        "Unknown source"
    }
}

private func memoryPresenceStatusTint(_ status: MemoryPresenceStatus) -> Color {
    switch status {
    case .claudeOnly:
        .orange
    case .codexOnly:
        .blue
    case .bothSides:
        .green
    case .sharedOnly:
        .teal
    case .unknown:
        .secondary
    }
}

private func memorySharedLocationTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Shared"
    case .simplifiedChinese:
        "共享"
    }
}

private func groupingBasisPrefix(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "归组依据：" : "Basis:"
}

private func groupingBasisTitle(_ kind: ContextCapabilityGroupingBasisKind, language: AppLanguage) -> String {
    switch (kind, language) {
    case (.skillDirectory, .simplifiedChinese):
        "单个 SKILL.md 目录"
    case (.pluginBundle, .simplifiedChinese):
        "同一插件包内的 skills/ 目录"
    case (.repositorySkillDirectory, .simplifiedChinese):
        "同一仓库型 skills/<repo>/ 目录"
    case (.sameNameSkillCopies, .simplifiedChinese):
        "同名 SKILL.md 副本聚合展示，运行时不合并"
    case (.skillNameFamily, .simplifiedChinese):
        "相同主题命名的 flat skills"
    case (.mcpConfiguration, .simplifiedChinese):
        "MCP 配置文件"
    case (.parentDirectory, .simplifiedChinese):
        "同一父目录"
    case (.skillDirectory, _):
        "Single SKILL.md directory"
    case (.pluginBundle, _):
        "Same plugin skills/ directory"
    case (.repositorySkillDirectory, _):
        "Same repository-style skills/<repo>/ directory"
    case (.sameNameSkillCopies, _):
        "Same-name SKILL.md copies grouped for display only"
    case (.skillNameFamily, _):
        "Flat skills with the same topic naming"
    case (.mcpConfiguration, _):
        "MCP configuration file"
    case (.parentDirectory, _):
        "Same parent directory"
    }
}

private func groupingBasisSourceLabel(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "官方依据" : "Source"
}

private func viewOnlyGroupingLabel(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "仅整理视图" : "View only"
}

private func sourceHelpText(basis: ContextCapabilityGroupingBasis, language: AppLanguage) -> String {
    guard let sourceLocation = basis.sourceLocation else {
        return groupingBasisSourceLabel(language: language)
    }
    return "\(groupingBasisSourceLabel(language: language)): \(sourceLocation)"
}

private func capabilityGroupCountLabel(_ group: ContextCapabilityGroup, language: AppLanguage) -> String {
    if group.kindCounts.count == 1,
       let kind = group.kindCounts.keys.first {
        return "\(group.items.count) \(L10n.assetKind(kind, language: language))"
    }
    return "\(group.items.count) items"
}

private func capabilityGroupPreview(_ group: ContextCapabilityGroup, language: AppLanguage) -> String {
    if group.items.count == 1,
       let item = group.items.first,
       !item.asset.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return item.asset.summary
    }

    let names = group.items
        .map(\.asset.title)
        .filter { !$0.isEmpty && $0.localizedCaseInsensitiveCompare(group.title) != .orderedSame }
        .prefix(3)

    if !names.isEmpty {
        let joined = names.joined(separator: " · ")
        if group.items.count > names.count {
            return "\(joined) · +\(group.items.count - names.count)"
        }
        return joined
    }

    let basis = groupingBasisTitle(group.groupingBasis.kind, language: language)
    let summary = capabilityGroupSummary(group, language: language)
    return summary.isEmpty ? basis : "\(summary) · \(basis)"
}

private func capabilityGroupSummary(_ group: ContextCapabilityGroup, language: AppLanguage) -> String {
    group.kindCounts
        .sorted { left, right in
            if assetKindSortIndex(left.key) != assetKindSortIndex(right.key) {
                return assetKindSortIndex(left.key) < assetKindSortIndex(right.key)
            }
            return left.key.rawValue < right.key.rawValue
        }
        .map { "\($0.value) \(L10n.assetKind($0.key, language: language))" }
        .joined(separator: " · ")
}

private func capabilityKindTint(_ kind: AssetKind) -> Color {
    switch kind {
    case .skill: .teal
    case .command: .blue
    case .mcp, .config: .orange
    case .plugin: .purple
    case .script: .green
    case .rule: .red
    case .instruction: .indigo
    case .memory: .indigo
    case .session: .orange
    case .unknown: .secondary
    }
}

private func displayPath(_ path: String) -> String {
    path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
}

private func contextLayerIcon(_ layer: AgentContextLayer) -> String {
    switch layer {
    case .global: "globe"
    case .project: "folder"
    case .workspace: "rectangle.3.group"
    case .shared: "person.2"
    case .pluginProvided: "puzzlepiece.extension"
    case .configuration: "switch.2"
    case .session: "clock.arrow.circlepath"
    }
}

private func contextRoleIcon(_ role: AgentContextRole) -> String {
    switch role {
    case .memory: "brain.head.profile"
    case .capability: "wand.and.stars"
    }
}

private func contextRoleTint(_ role: AgentContextRole) -> Color {
    switch role {
    case .memory: .indigo
    case .capability: .teal
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

private func memoryTypeTint(_ type: AgentMemoryType) -> Color {
    switch type {
    case .longTerm: .indigo
    case .project: .blue
    case .workspace: .cyan
    case .automation: .green
    case .preference: .pink
    case .sessionHistory: .orange
    case .shared: .teal
    case .instructions: .purple
    case .contextRules: .red
    case .pluginProvided: .mint
    }
}

private func surfaceIcon(_ surface: AgentOwner) -> String {
    switch surface {
    case .claude: "terminal"
    case .codex: "cube.transparent"
    case .agents: "person.2.wave.2"
    case .project: "folder"
    case .unknown: "questionmark.folder"
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

private func skillInstallOriginTint(_ origin: SkillInstallOrigin) -> Color {
    switch origin {
    case .preset: .blue
    case .officialPlugin: .teal
    case .userInstalled: .purple
    case .projectLocal: .orange
    case .unknown: .secondary
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
