import AgentObservatoryCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        List {
            Section {
                SidebarFilterRow(
                    title: store.t(.dashboard),
                    systemImage: "gauge.with.dots.needle.67percent",
                    count: store.dashboardSummary.topRisks.count,
                    isSelected: store.selectedSection == .dashboard
                ) {
                    store.showDashboard()
                }
            }

            Section(store.t(.management)) {
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

            Section(store.t(.sources)) {
                SidebarFilterRow(
                    title: store.t(.allSources),
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

            Section(store.t(.categories)) {
                SidebarFilterRow(
                    title: store.t(.allCategories),
                    systemImage: "tray.full",
                    count: store.visibleAssets.count,
                    isSelected: store.selectedSection == .assets && store.selectedKind == nil
                ) {
                    store.select(kind: nil)
                }

                ForEach(AssetKind.allCases.filter { $0 != .unknown }) { kind in
                    SidebarFilterRow(
                        title: kind.rawValue,
                        systemImage: icon(for: kind),
                        count: store.summary.kinds[kind, default: 0],
                        isSelected: store.selectedSection == .assets && store.selectedKind == kind
                    ) {
                        store.select(kind: kind)
                    }
                }
            }

            Section(store.t(.health)) {
                SidebarFilterRow(
                    title: store.t(.allWarnings),
                    systemImage: "exclamationmark.triangle",
                    count: store.summary.warnings,
                    isSelected: store.selectedSection == .assets && store.selectedHealth == .warnings
                ) {
                    store.select(health: store.selectedHealth == .warnings ? nil : .warnings)
                }

                ForEach(HealthFilter.allCases.filter { $0 != .warnings }) { filter in
                    SidebarFilterRow(
                        title: filter.title(language: store.appLanguage),
                        systemImage: filter.systemImage,
                        count: store.healthCount(for: filter),
                        isSelected: store.selectedSection == .assets && store.selectedHealth == filter
                    ) {
                        store.select(health: store.selectedHealth == filter ? nil : filter)
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
                        Text(path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
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
