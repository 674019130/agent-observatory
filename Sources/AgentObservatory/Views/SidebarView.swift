import AgentObservatoryCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        List {
            Section(store.t(.contextBrowser)) {
                SidebarFilterRow(
                    title: store.t(.triggerRadar),
                    systemImage: "scope",
                    count: store.skillTriggerConflicts.count,
                    isSelected: store.selectedSection == .triggerRadar
                ) {
                    store.showTriggerRadar()
                }

                SidebarFilterRow(
                    title: store.t(.overview),
                    systemImage: "rectangle.3.group",
                    count: store.visibleAssets.count,
                    isSelected: store.selectedSection == .contextOverview
                ) {
                    store.showContextOverview()
                }

                SidebarFilterRow(
                    title: store.t(.memories),
                    systemImage: "brain.head.profile",
                    count: store.contextCatalog.memoryItems.count,
                    isSelected: store.selectedSection == .memories
                ) {
                    store.showMemories()
                }

                SidebarFilterRow(
                    title: store.t(.capabilities),
                    systemImage: "wand.and.stars",
                    count: store.visibleNonMCPCapabilityItems.count,
                    isSelected: store.selectedSection == .capabilities
                ) {
                    store.showCapabilities()
                }

                SidebarFilterRow(
                    title: "MCP",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    count: store.visibleMCPItems.count,
                    isSelected: store.selectedSection == .mcpTools
                ) {
                    store.showMCPTools()
                }

                SidebarFilterRow(
                    title: store.t(.assembly),
                    systemImage: "point.3.connected.trianglepath.dotted",
                    count: store.contextCatalog.assemblySteps.count,
                    isSelected: store.selectedSection == .assembly
                ) {
                    store.showAssembly()
                }
            }

            Section(store.t(.surfaces)) {
                SidebarFilterRow(
                    title: store.t(.allFiles),
                    systemImage: "square.grid.2x2",
                    count: store.visibleAssets.count,
                    isSelected: store.selectedSection == .assets && store.selectedOwner == nil
                ) {
                    store.select(owner: nil)
                }

                ForEach(AgentOwner.allCases.filter { $0 != .unknown }) { owner in
                    SidebarFilterRow(
                        title: L10n.agentOwner(owner, language: store.appLanguage),
                        systemImage: icon(for: owner),
                        count: store.summary.sources[owner, default: 0],
                        isSelected: store.selectedSection == .assets && store.selectedOwner == owner
                    ) {
                        store.select(owner: owner)
                    }
                }
            }

            Section(store.t(.management)) {
                SidebarFilterRow(
                    title: store.t(.aiOrganizer),
                    systemImage: "sparkles.rectangle.stack",
                    count: store.cleanupReviewSession.groups.count,
                    isSelected: store.selectedSection == .organizer
                ) {
                    store.showOrganizer()
                }

                SidebarFilterRow(
                    title: store.t(.archive),
                    systemImage: "archivebox",
                    count: store.archivedAssetCount,
                    isSelected: store.selectedSection == .archive
                ) {
                    store.showArchive()
                }

                if store.hiddenAssetCount > 0 {
                    SidebarFilterRow(
                        title: store.t(.hiddenItems),
                        systemImage: "eye.slash",
                        count: store.hiddenAssetCount,
                        isSelected: store.selectedSection == .hidden
                    ) {
                        store.showHidden()
                    }
                }
            }

            Section(store.t(.index)) {
                HStack {
                    Label(store.t(.activeSources), systemImage: "checklist")
                    Spacer()
                    CountBadge(count: store.activeScanSources.count, tint: .blue)
                }
                HStack {
                    Label(store.t(.existingPaths), systemImage: "folder.badge.gearshape")
                    Spacer()
                    CountBadge(count: store.existingScanSourceCount, tint: .green)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(store.t(.appName))
        .safeAreaInset(edge: .bottom) {
            ScanStatusView()
        }
    }

    private func icon(for owner: AgentOwner) -> String {
        switch owner {
        case .claude: "terminal"
        case .codex: "cube.transparent"
        case .agents: "person.2.wave.2"
        case .project: "folder"
        case .unknown: "questionmark.folder"
        }
    }

    private func icon(for kind: AssetKind) -> String {
        switch kind {
        case .skill: "wand.and.stars"
        case .command: "command"
        case .memory: "brain"
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
}

private struct SidebarFilterRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                CountBadge(count: count, tint: isSelected ? .accentColor : .secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .rowHitTarget(cornerRadius: 7)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

private struct ScanStatusView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if store.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) } ?? store.t(.scanningSelectedSources))
                        .lineLimit(1)
                }

                if let progress = store.scanProgress {
                    if let rootProgress = progress.rootProgress {
                        ProgressView(value: rootProgress)
                            .controlSize(.small)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text("\(progress.sourceLabel) • \(progress.rootsCompleted)/\(progress.rootCount) \(store.t(.sources)) • \(progress.filesProcessed)/\(progress.filesDiscovered) \(store.t(.files)) • \(progress.assetsFound) \(store.t(.assets))")
                        .lineLimit(1)

                    if progress.directoriesSkipped > 0 || progress.readErrors > 0 {
                        Text("\(store.t(.skipped)) \(progress.directoriesSkipped) \(store.t(.directories)) • \(progress.readErrors) \(store.t(.readErrors))")
                            .foregroundStyle(progress.readErrors > 0 ? .orange : .secondary)
                            .lineLimit(1)
                    }

                    if !progress.currentPath.isEmpty {
                        Text(progress.currentPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            } else if store.isIndexStale {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(store.t(.indexStaleStatus))
                    }
                    if let path = store.lastFileEventPaths.first {
                        PathPreviewLink(
                            path: path,
                            font: .caption2.monospaced(),
                            foregroundColor: .secondary.opacity(0.65),
                            language: store.appLanguage
                        )
                    }
                }
                .foregroundStyle(.orange)
            } else if let date = store.lastScanDate {
                HStack(spacing: 8) {
                    Image(systemName: store.scanProgress?.phase == .cancelled ? "xmark.circle" : "clock")
                    Text("\(store.t(.updated)) \(date.formatted(date: .omitted, time: .shortened))")
                    if let progress = store.scanProgress {
                        Text("• \(progress.assetsFound) \(store.t(.assets))")
                    }
                }
            } else if store.scanProgress?.phase == .cancelled {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                    Text(store.t(.scanCancelled))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(store.t(.readyToScan))
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
