import AgentObservatoryCore
import AppKit
import SwiftUI

struct AssetListView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var assetPendingArchive: AgentAsset?
    @State private var archiveReason = ""

    var body: some View {
        VStack(spacing: 0) {
            AssetListHeader()

            if let error = store.managementError {
                ManagementErrorBanner(message: error)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            if let selectedAsset = store.selectedAsset, !store.filteredAssets.isEmpty {
                AssetManagementActionBar(
                    asset: selectedAsset,
                    onHide: {
                        store.hideAsset(selectedAsset)
                    },
                    onArchive: {
                        archiveReason = ""
                        assetPendingArchive = selectedAsset
                    }
                )
            }

            if store.isScanning && store.assets.isEmpty {
                ScanningEmptyState()
            } else if store.filteredAssets.isEmpty {
                AssetListEmptyState()
            } else {
                Table(store.filteredAssets, selection: $store.selectedAssetID) {
                    TableColumn(store.t(.name)) { asset in
                        AssetNameCell(asset: asset)
                    }
                    .width(min: 220, ideal: 300)

                    TableColumn(store.t(.kind)) { asset in
                        Text(L10n.assetKind(asset.kind, language: store.appLanguage))
                            .foregroundStyle(.secondary)
                    }
                    .width(90)

                    TableColumn(store.t(.source)) { asset in
                        BadgeView(text: asset.owner.shortName, tint: ownerTint(for: asset.owner))
                    }
                    .width(88)

                    TableColumn(store.t(.status)) { asset in
                        StatusPillGroup(
                            flags: asset.statusFlags,
                            language: store.appLanguage,
                            okTitle: store.t(.ok)
                        )
                    }
                    .width(min: 140, ideal: 220)

                    TableColumn(store.t(.modified)) { asset in
                        Text(asset.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? store.t(.unknown))
                            .foregroundStyle(.secondary)
                    }
                    .width(105)

                    TableColumn(store.t(.size)) { asset in
                        Text(ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .width(86)
                }
                .contextMenu {
                    if let asset = store.selectedAsset {
                        Button(store.t(.showInFinder)) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.path)])
                        }
                        Button(store.t(.copyPath)) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(asset.path, forType: .string)
                        }
                        Divider()
                        Button(store.t(.hideFromObservatory)) {
                            store.hideAsset(asset)
                        }
                        Button("\(store.t(.archiveAction))...") {
                            archiveReason = ""
                            assetPendingArchive = asset
                        }
                    }
                }
            }
        }
        .navigationTitle(store.t(.assets))
        .sheet(item: $assetPendingArchive) { asset in
            ArchiveConfirmationSheet(
                asset: asset,
                reason: $archiveReason,
                onArchive: {
                    store.archiveAsset(asset, reason: archiveReason)
                    archiveReason = ""
                    assetPendingArchive = nil
                },
                onCancel: {
                    archiveReason = ""
                    assetPendingArchive = nil
                }
            )
        }
    }

    private func ownerTint(for owner: AgentOwner) -> Color {
        switch owner {
        case .claude: .orange
        case .codex: .blue
        case .agents: .green
        case .project: .teal
        case .unknown: .secondary
        }
    }
}

private struct AssetManagementActionBar: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset
    let onHide: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label(asset.displayPath, systemImage: "filemenu.and.selection")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button(action: onHide) {
                Label(store.t(.hide), systemImage: "eye.slash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: onArchive) {
                Label(store.t(.archiveAction), systemImage: "archivebox")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct ScanningEmptyState: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            Text(store.t(.scanningSelectedSources))
                .font(.title3.weight(.semibold))

            if let progress = store.scanProgress {
                Text(L10n.scanProgressMessage(progress, language: store.appLanguage))
                    .foregroundStyle(.secondary)

                if let rootProgress = progress.rootProgress {
                    ProgressView(value: rootProgress)
                        .frame(width: 260)
                }

                Text("\(progress.sourceLabel) • \(store.t(.visited)) \(progress.filesVisited) • \(store.t(.found)) \(progress.assetsFound)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(progress.currentPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 420)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AssetListHeader: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker(store.t(.owner), selection: $store.selectedOwner) {
                    Text(store.t(.all)).tag(AgentOwner?.none)
                    Text(L10n.agentOwner(.claude, language: store.appLanguage)).tag(AgentOwner?.some(.claude))
                    Text(L10n.agentOwner(.codex, language: store.appLanguage)).tag(AgentOwner?.some(.codex))
                    Text(L10n.agentOwner(.agents, language: store.appLanguage)).tag(AgentOwner?.some(.agents))
                    Text(L10n.agentOwner(.project, language: store.appLanguage)).tag(AgentOwner?.some(.project))
                }
                .pickerStyle(.segmented)
                .frame(width: 330)

                Spacer()

                if hasActiveFilters {
                    Button {
                        store.resetFilters()
                    } label: {
                        Label(store.t(.reset), systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Text("\(store.filteredAssets.count) \(store.t(.items))")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if store.selectedHealth != nil || store.summary.warnings > 0 {
                HealthDashboardStrip()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .background(.bar)
    }

    private var hasActiveFilters: Bool {
        store.selectedOwner != nil
            || store.selectedKind != nil
            || store.selectedHealth != nil
            || !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AssetListEmptyState: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(store.t(.noMatchingAssets))
                .font(.title3.weight(.semibold))
            Text(store.t(.noMatchingAssetsMessage))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                store.resetFilters()
            } label: {
                Label(store.t(.resetFilters), systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

private struct HealthDashboardStrip: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        HStack(spacing: 8) {
            ForEach(HealthFilter.allCases) { filter in
                Button {
                    store.select(health: store.selectedHealth == filter ? nil : filter)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filter.systemImage)
                        Text(filter.title(language: store.appLanguage))
                        Text("\(store.healthCount(for: filter))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(store.selectedHealth == filter ? .accentColor : .secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct AssetNameCell: View {
    let asset: AgentAsset

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(iconTint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(asset.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(asset.displayPath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch asset.kind {
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

    private var iconTint: Color {
        switch asset.kind {
        case .memory: .indigo
        case .skill: .teal
        case .command: .blue
        case .config, .mcp: .orange
        case .rule: .purple
        case .script: .green
        default: .secondary
        }
    }
}

private struct StatusPillGroup: View {
    let flags: [AssetStatusFlag]
    let language: AppLanguage
    let okTitle: String

    var body: some View {
        if flags.isEmpty {
            Label(okTitle, systemImage: "checkmark.seal")
                .foregroundStyle(.green)
                .font(.caption)
        } else {
            HStack(spacing: 4) {
                ForEach(flags.prefix(2)) { flag in
                    BadgeView(text: shortLabel(for: flag), tint: tint(for: flag))
                }
                if flags.count > 2 {
                    BadgeView(text: "+\(flags.count - 2)", tint: .secondary)
                }
            }
        }
    }

    private func shortLabel(for flag: AssetStatusFlag) -> String {
        L10n.shortStatusFlag(flag, language: language)
    }

    private func tint(for flag: AssetStatusFlag) -> Color {
        switch flag {
        case .duplicate: .purple
        case .stalePath, .secretRisk, .unreadable: .red
        case .hasScripts: .green
        case .needsSummary, .largeFile: .orange
        }
    }
}

private struct AssetRow: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconTint)
                    .frame(width: 18)
                Text(asset.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                BadgeView(text: L10n.assetKind(asset.kind, language: store.appLanguage), tint: .blue)
            }

            Text(asset.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                BadgeView(text: asset.owner.shortName, tint: ownerTint)
                ForEach(asset.statusFlags.prefix(3)) { flag in
                    BadgeView(text: L10n.statusFlag(flag, language: store.appLanguage), tint: tint(for: flag))
                }
                Spacer()
                Text(asset.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? store.t(.unknown))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(asset.displayPath)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
    }

    private var icon: String {
        switch asset.kind {
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

    private var iconTint: Color {
        switch asset.kind {
        case .memory: .indigo
        case .skill: .teal
        case .command: .blue
        case .config, .mcp: .orange
        case .rule: .purple
        case .script: .green
        default: .secondary
        }
    }

    private var ownerTint: Color {
        switch asset.owner {
        case .claude: .orange
        case .codex: .blue
        case .agents: .green
        case .project: .teal
        case .unknown: .secondary
        }
    }

    private func tint(for flag: AssetStatusFlag) -> Color {
        switch flag {
        case .duplicate: .purple
        case .stalePath, .secretRisk: .red
        case .hasScripts: .green
        case .needsSummary, .largeFile, .unreadable: .orange
        }
    }
}
