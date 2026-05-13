import AgentObservatoryCore
import SwiftUI

private let memoryTypeVisibleBatchSize = 40

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

    private var filteredItems: [ContextCatalogItem] {
        store.visibleCapabilityItems.filter { item in
            item.asset.matchesSearch(query: store.searchText)
        }
    }

    var body: some View {
        ContextItemCollectionView(
            title: store.t(.capabilities),
            subtitle: store.t(.contextBrowserSubtitle),
            systemImage: "puzzlepiece.extension",
            tint: .teal,
            items: filteredItems,
            groupTitle: { item in capabilityGroupTitle(item, language: store.appLanguage) },
            groupRank: { capabilityGroupRank($0) },
            showsSkillVisibilityControl: true
        )
        .navigationTitle(store.t(.capabilities))
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

private struct ContextItemCollectionView: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let items: [ContextCatalogItem]
    let groupTitle: (ContextCatalogItem) -> String
    let groupRank: (ContextCatalogItem) -> Int
    var showsSkillVisibilityControl = false

    private var groups: [(String, [ContextCatalogItem])] {
        Dictionary(grouping: items, by: groupTitle)
            .map { ($0.key, $0.value.sorted(by: itemTitleSort)) }
            .sorted { left, right in
                let leftRank = left.1.map(groupRank).min() ?? Int.max
                let rightRank = right.1.map(groupRank).min() ?? Int.max
                if leftRank != rightRank {
                    return leftRank < rightRank
                }
                return left.0.localizedStandardCompare(right.0) == .orderedAscending
            }
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

                if showsSkillVisibilityControl {
                    OfficialDocTipsPanel(
                        tips: OfficialDocTips.tips(
                            for: .capabilities,
                            language: store.appLanguage
                        )
                    )

                    SkillVisibilityControl()
                }

                if groups.isEmpty {
                    EmptyStateView(
                        title: store.t(.noContextItems),
                        message: store.t(.contextDetailPlaceholderMessage),
                        systemImage: "tray"
                    )
                    .frame(minHeight: 260)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(groups, id: \.0) { group in
                            ContextItemGroup(title: group.0, items: group.1)
                        }
                    }
                }
            }
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

    private var visibleItems: ArraySlice<ContextCatalogItem> {
        selectedItems.prefix(visibleItemLimit)
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

                MemoryTypeNavigator(
                    groups: groups,
                    selectedType: $selectedType
                )

                FocusedMemoryTypeSection(
                    type: selectedType,
                    items: selectedItems,
                    visibleItems: visibleItems,
                    hasMoreItems: selectedItems.count > visibleItemLimit,
                    visibleCount: min(selectedItems.count, visibleItemLimit),
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

private struct FocusedMemoryTypeSection: View {
    @EnvironmentObject private var store: AssetStore
    let type: AgentMemoryType
    let items: [ContextCatalogItem]
    let visibleItems: ArraySlice<ContextCatalogItem>
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
                    Text(String(format: store.t(.showingItems), visibleCount, items.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                LazyVStack(spacing: 6) {
                    ForEach(visibleItems) { item in
                        ContextItemRow(item: item)
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

private struct ContextItemGroup: View {
    let title: String
    let items: [ContextCatalogItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                CountBadge(count: items.count, tint: .secondary)
            }

            VStack(spacing: 6) {
                ForEach(items) { item in
                    ContextItemRow(item: item)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
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
        Button {
            store.focusAsset(path: item.asset.path)
        } label: {
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
                        Text(item.asset.displayPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
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
        }
        .buttonStyle(.plain)
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

private func capabilityGroupTitle(_ item: ContextCatalogItem, language: AppLanguage) -> String {
    let kind = L10n.assetKind(item.asset.kind, language: language)
    guard item.asset.kind == .skill, let origin = item.loadRoute.skillInstallOrigin else {
        return kind
    }

    return "\(kind) · \(L10n.skillInstallOrigin(origin, language: language))"
}

private func capabilityGroupRank(_ item: ContextCatalogItem) -> Int {
    let baseRank = assetKindSortIndex(item.asset.kind) * 10
    guard item.asset.kind == .skill, let origin = item.loadRoute.skillInstallOrigin else {
        return baseRank + 9
    }

    return baseRank + origin.sortIndex
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
