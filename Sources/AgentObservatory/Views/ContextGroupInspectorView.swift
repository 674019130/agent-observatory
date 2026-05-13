import AgentObservatoryCore
import SwiftUI

struct ContextGroupInspectorView: View {
    @EnvironmentObject private var store: AssetStore
    let node: ContextTreeNode

    private var items: [ContextCatalogItem] {
        node.items
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(node.title)
                        .font(.system(size: 26, weight: .semibold))
                        .lineLimit(2)
                    Spacer()
                    BadgeView(text: "\(items.count) \(store.t(.items))", tint: contextTreeAccentColor(node.accent))
                }

                if !node.subtitle.isEmpty {
                    Text(node.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    groupOverview
                    loadRouteSummary
                    sampleFiles
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(node.title)
    }

    private var groupOverview: some View {
        InspectorPanel(title: store.t(.overview), systemImage: node.systemImage) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    BadgeView(text: "\(node.memoryCount) \(store.t(.memories))", tint: .indigo)
                    BadgeView(text: "\(node.capabilityCount) \(store.t(.capabilities))", tint: .teal)
                }

                InfoGrid(rows: [
                    (store.t(.usedBy), usedBySummary),
                    (store.t(.layer), layerSummary),
                    (store.t(.source), sourceSummary)
                ])
            }
        }
    }

    private var loadRouteSummary: some View {
        InspectorPanel(title: store.t(.loadRoute), systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 12) {
                InfoGrid(rows: [
                    (store.t(.loadedInto), destinationSummary),
                    (store.t(.loadedHow), triggerSummary),
                    (store.t(.promptPlacement), promptMaterialSummary)
                ])
            }
        }
    }

    private var sampleFiles: some View {
        InspectorPanel(title: store.t(.affectedFiles), systemImage: "doc.text") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.prefix(12)) { item in
                    Button {
                        store.focusContextAsset(path: item.asset.path)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: assetKindIcon(item.asset.kind))
                                .foregroundStyle(item.role == .memory ? .indigo : .teal)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.asset.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(item.asset.displayPath)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .rowHitTarget(cornerRadius: 7)
                    }
                    .buttonStyle(.plain)
                }

                if items.count > 12 {
                    Text(String(format: store.t(.showingItems), 12, items.count))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var usedBySummary: String {
        let owners = uniqueOwners(items.flatMap(\.surfaces))
        guard !owners.isEmpty else { return store.t(.unknown) }
        return owners.map { $0 == .claude ? store.t(.claudeCode) : L10n.agentOwner($0, language: store.appLanguage) }
            .joined(separator: ", ")
    }

    private var layerSummary: String {
        summarized(items.map(\.layer)) { assemblyLayerTitle($0, language: store.appLanguage) }
    }

    private var sourceSummary: String {
        summarized(items.map(\.asset.owner)) { owner in
            owner == .claude ? store.t(.claudeCode) : L10n.agentOwner(owner, language: store.appLanguage)
        }
    }

    private var destinationSummary: String {
        summarized(items.map(\.loadRoute.destination)) { L10n.loadDestination($0, language: store.appLanguage) }
    }

    private var triggerSummary: String {
        summarized(items.map(\.loadRoute.trigger)) { L10n.loadTrigger($0, language: store.appLanguage) }
    }

    private var promptMaterialSummary: String {
        let promptMaterialCount = items.filter(\.loadRoute.destination.isPromptMaterial).count
        let registryCount = items.count - promptMaterialCount
        if promptMaterialCount == 0 {
            return store.t(.registryMaterial)
        }
        if registryCount == 0 {
            return store.t(.promptMaterial)
        }
        return "\(promptMaterialCount) \(store.t(.promptMaterial)) · \(registryCount) \(store.t(.registryMaterial))"
    }

    private func summarized<T: Hashable>(_ values: [T], label: (T) -> String) -> String {
        let counts = Dictionary(grouping: values, by: { $0 })
            .map { (key: $0.key, count: $0.value.count) }
            .sorted { left, right in
                if left.count != right.count {
                    return left.count > right.count
                }
                return label(left.key).localizedStandardCompare(label(right.key)) == .orderedAscending
            }

        return counts.prefix(3)
            .map { "\($0.count) \(label($0.key))" }
            .joined(separator: " · ")
    }

    private func uniqueOwners(_ owners: [AgentOwner]) -> [AgentOwner] {
        var seen: Set<AgentOwner> = []
        return owners.filter { seen.insert($0).inserted }
    }
}

private struct InfoGrid: View {
    let rows: [(String, String)]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.fixed(112), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ],
            spacing: 10
        ) {
            ForEach(rows, id: \.0) { label, value in
                Text(label)
                    .foregroundStyle(.secondary)
                Text(value)
                    .textSelection(.enabled)
            }
        }
        .font(.callout)
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
    case .neutral: .secondary
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
