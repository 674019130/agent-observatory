import AgentObservatoryCore
import SwiftUI

private let contextTreeVisibleChildBatchSize = 32

struct ContextTreeView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var expandedNodeIDs: Set<ContextTreeNode.ID> = []
    @State private var expandedNodeIDsBeforeSearch: Set<ContextTreeNode.ID>?

    private var nodes: [ContextTreeNode] {
        store.contextTreeNodes
    }

    private var expansionSignature: String {
        nodes.map { "\($0.id):\($0.items.count)" }.joined(separator: "|")
    }

    @State private var visibleChildLimits: [ContextTreeNode.ID: Int] = [:]

    private var visibleRows: [ContextTreeVisibleRow] {
        ContextTreeVisibleRowsBuilder(
            roots: nodes,
            expandedNodeIDs: expandedNodeIDs,
            visibleChildLimits: visibleChildLimits,
            defaultChildLimit: contextTreeVisibleChildBatchSize
        )
        .rows()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ContextTreeHeader(nodes: nodes)
                OfficialDocTipsPanel(
                    tips: OfficialDocTips.tips(
                        for: .contextOverview,
                        language: store.appLanguage
                    )
                )
                ContextTreeToolbar()

                if nodes.isEmpty {
                    EmptyStateView(
                        title: store.t(.noContextItems),
                        message: store.t(.contextDetailPlaceholderMessage),
                        systemImage: "tray"
                    )
                    .frame(minHeight: 260)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleRows) { row in
                            switch row {
                            case let .node(node, depth):
                                ContextTreeVisibleNodeRow(
                                    node: node,
                                    depth: depth,
                                    isExpanded: expandedNodeIDs.contains(node.id),
                                    isSelected: isSelected(node),
                                    toggle: {
                                        toggleExpanded(node)
                                    },
                                    select: {
                                        store.selectContextTreeNode(node)
                                    }
                                )
                            case let .loadMore(parentID, depth, visibleCount, totalCount):
                                ContextTreeLoadMoreRow(
                                    depth: depth,
                                    visibleCount: visibleCount,
                                    totalCount: totalCount,
                                    loadMore: {
                                        loadMoreChildren(for: parentID, totalCount: totalCount)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(store.t(.contextBrowser))
        .onAppear(perform: syncExpandedNodes)
        .onChange(of: expansionSignature) { _, _ in
            visibleChildLimits = [:]
            syncExpandedNodes()
        }
        .onChange(of: store.searchText) { _, _ in
            visibleChildLimits = [:]
            syncExpandedNodes()
        }
    }

    private func isSelected(_ node: ContextTreeNode) -> Bool {
        if store.selectedContextTreeNodeID == node.id {
            return true
        }
        guard let assetID = node.asset?.id else { return false }
        return assetID == store.selectedAssetID && store.selectedContextTreeNodeID == nil
    }

    private func toggleExpanded(_ node: ContextTreeNode) {
        guard !node.children.isEmpty else { return }
        if expandedNodeIDs.contains(node.id) {
            expandedNodeIDs.remove(node.id)
        } else {
            expandedNodeIDs.insert(node.id)
            visibleChildLimits[node.id] = visibleChildLimits[node.id] ?? contextTreeVisibleChildBatchSize
        }
    }

    private func loadMoreChildren(for parentID: ContextTreeNode.ID, totalCount: Int) {
        let currentLimit = visibleChildLimits[parentID] ?? contextTreeVisibleChildBatchSize
        visibleChildLimits[parentID] = min(
            currentLimit + contextTreeVisibleChildBatchSize,
            totalCount
        )
    }

    private func syncExpandedNodes() {
        let searchableText = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearching = !searchableText.isEmpty
        let expandableIDs = Set(nodes.flatMap(\.flattened).filter { !$0.children.isEmpty }.map(\.id))
        let defaultExpandedIDs = Set(nodes.flatMap(\.defaultExpandedIDs))

        if isSearching {
            if expandedNodeIDsBeforeSearch == nil {
                expandedNodeIDsBeforeSearch = expandedNodeIDs.isEmpty ? defaultExpandedIDs : expandedNodeIDs
            }
            expandedNodeIDs = expandableIDs
            return
        }

        let restoredIDs = expandedNodeIDsBeforeSearch
        expandedNodeIDsBeforeSearch = nil

        if let restoredIDs {
            expandedNodeIDs = restoredIDs.intersection(expandableIDs)
            expandedNodeIDs.formUnion(defaultExpandedIDs)
        } else if expandedNodeIDs.isEmpty {
            expandedNodeIDs = defaultExpandedIDs
        } else {
            expandedNodeIDs = expandedNodeIDs.intersection(expandableIDs)
            expandedNodeIDs.formUnion(defaultExpandedIDs)
        }
        visibleChildLimits = visibleChildLimits.filter { expandableIDs.contains($0.key) }
    }
}

private enum ContextTreeVisibleRow: Identifiable {
    case node(ContextTreeNode, depth: Int)
    case loadMore(parentID: ContextTreeNode.ID, depth: Int, visibleCount: Int, totalCount: Int)

    var id: String {
        switch self {
        case let .node(node, _):
            return "node:\(node.id)"
        case let .loadMore(parentID, _, visibleCount, totalCount):
            return "more:\(parentID):\(visibleCount):\(totalCount)"
        }
    }
}

private struct ContextTreeVisibleRowsBuilder {
    let roots: [ContextTreeNode]
    let expandedNodeIDs: Set<ContextTreeNode.ID>
    let visibleChildLimits: [ContextTreeNode.ID: Int]
    let defaultChildLimit: Int

    func rows() -> [ContextTreeVisibleRow] {
        rows(for: roots, depth: 0)
    }

    private func rows(for nodes: [ContextTreeNode], depth: Int) -> [ContextTreeVisibleRow] {
        var result: [ContextTreeVisibleRow] = []
        result.reserveCapacity(nodes.count)

        for node in nodes {
            result.append(.node(node, depth: depth))

            guard expandedNodeIDs.contains(node.id), !node.children.isEmpty else {
                continue
            }

            let limit = visibleChildLimits[node.id] ?? defaultChildLimit
            let visibleChildren = Array(node.children.prefix(limit))
            result.append(contentsOf: rows(for: visibleChildren, depth: depth + 1))

            if node.children.count > limit {
                result.append(
                    .loadMore(
                        parentID: node.id,
                        depth: depth + 1,
                        visibleCount: min(limit, node.children.count),
                        totalCount: node.children.count
                    )
                )
            }
        }

        return result
    }
}

private struct ContextTreeHeader: View {
    @EnvironmentObject private var store: AssetStore
    let nodes: [ContextTreeNode]

    private var allItems: [ContextCatalogItem] {
        unique(nodes.flatMap(\.items))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t(.contextBrowser))
                        .font(.title3.weight(.semibold))
                    Text(store.t(.contextBrowserSubtitle))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)
            }

            HStack(spacing: 8) {
                ContextTreeMetric(
                    title: store.t(.memories),
                    value: allItems.filter { $0.role == .memory }.count,
                    systemImage: "brain.head.profile",
                    tint: .indigo
                )
                ContextTreeMetric(
                    title: store.t(.capabilities),
                    value: allItems.filter { $0.role == .capability && $0.asset.kind != .mcp }.count,
                    systemImage: "wand.and.stars",
                    tint: .teal
                )
                ContextTreeMetric(
                    title: "MCP",
                    value: allItems.filter { $0.asset.kind == .mcp }.count,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: .orange
                )
                ContextTreeMetric(
                    title: store.t(.assembly),
                    value: store.contextCatalog.assemblySteps.count,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: .blue
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

    private func unique(_ items: [ContextCatalogItem]) -> [ContextCatalogItem] {
        var seen: Set<AgentAsset.ID> = []
        return items.filter { item in
            seen.insert(item.asset.id).inserted
        }
    }
}

private struct ContextTreeMetric: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct ContextTreeToolbar: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        HStack(spacing: 8) {
            if !store.includeBundledSkills {
                Label(store.t(.userSkillsOnly), systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.bundledSkillCount > 0, !store.includeBundledSkills {
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
    }
}

private struct ContextTreeVisibleNodeRow: View {
    @EnvironmentObject private var store: AssetStore
    let node: ContextTreeNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let toggle: () -> Void
    let select: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if node.children.isEmpty {
                Color.clear
                    .frame(width: 18, height: 18)
            } else {
                Button(action: toggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .compactHitTarget()
                }
                .buttonStyle(.plain)
            }

            Button(action: select) {
                HStack(spacing: 9) {
                    Image(systemName: node.systemImage)
                        .foregroundStyle(contextTreeAccentColor(node.accent))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.title)
                            .font(node.isAsset ? .callout : .callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !node.subtitle.isEmpty {
                            Text(node.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    if !node.isAsset {
                        CountBadge(count: node.items.count, tint: contextTreeAccentColor(node.accent))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .rowHitTarget(cornerRadius: 7)
                .background(
                    isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, CGFloat(depth) * 18 + 8)
        .padding(.trailing, 8)
    }
}

private struct ContextTreeLoadMoreRow: View {
    @EnvironmentObject private var store: AssetStore
    let depth: Int
    let visibleCount: Int
    let totalCount: Int
    let loadMore: () -> Void

    var body: some View {
        Button(action: loadMore) {
            Label(
                String(format: store.t(.showingItems), visibleCount, totalCount),
                systemImage: "arrow.down.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .rowHitTarget(cornerRadius: 7)
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(depth) * 18 + 34)
        .padding(.trailing, 8)
        .onAppear {
            DispatchQueue.main.async {
                loadMore()
            }
        }
    }
}

private func contextTreeAccentColor(_ accent: ContextTreeAccent) -> Color {
    switch accent {
    case .claude: .orange
    case .codex: .blue
    case .agents: .green
    case .project: .teal
    case .memory: .indigo
    case .capability: .teal
    case .mcp: .orange
    case .neutral: .secondary
    }
}
