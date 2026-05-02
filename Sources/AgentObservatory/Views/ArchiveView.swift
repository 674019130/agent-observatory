import AgentObservatoryCore
import AppKit
import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var store: AssetStore

    private var archivedAssets: [ArchivedAsset] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.archivedAssets }
        return store.archivedAssets.filter { asset in
            [
                asset.title,
                asset.originalPath,
                asset.archivedPath,
                asset.owner.rawValue,
                asset.kind.rawValue,
                asset.reason
            ]
            .joined(separator: "\n")
            .lowercased()
            .contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ArchiveHeader(count: archivedAssets.count)

            if let error = store.managementError {
                ManagementErrorBanner(message: error)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            if archivedAssets.isEmpty {
                EmptyStateView(
                    title: store.t(.noArchivedAssets),
                    message: store.t(.noArchivedAssetsMessage),
                    systemImage: "archivebox"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(archivedAssets) { archivedAsset in
                            ArchivedAssetRow(archivedAsset: archivedAsset)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(store.t(.archive))
    }
}

private struct ArchiveHeader: View {
    @EnvironmentObject private var store: AssetStore
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Label(store.t(.archive), systemImage: "archivebox")
                .font(.headline)
            CountBadge(count: count, tint: .orange)
            Spacer()
            Text(store.t(.restoreArchivedFilesHint))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct ArchivedAssetRow: View {
    @EnvironmentObject private var store: AssetStore
    let archivedAsset: ArchivedAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconTint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(archivedAsset.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(archivedAsset.displayOriginalPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 10)

                BadgeView(text: archivedAsset.owner.shortName, tint: ownerTint)
                BadgeView(text: L10n.assetKind(archivedAsset.kind, language: store.appLanguage), tint: .blue)
            }

            HStack(alignment: .top, spacing: 8) {
                Label(archivedAsset.reason, systemImage: "text.quote")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Text(archivedAsset.archivedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                Button {
                    store.restoreArchivedAsset(archivedAsset)
                } label: {
                    Label(store.t(.restore), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: archivedAsset.archivedPath)])
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .help(store.t(.showInFinder))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(archivedAsset.originalPath, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help(store.t(.copyOriginalPath))

                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
        .contextMenu {
            Button(store.t(.restore)) {
                store.restoreArchivedAsset(archivedAsset)
            }
            Button(store.t(.showInFinder)) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: archivedAsset.archivedPath)])
            }
            Button(store.t(.copyOriginalPath)) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(archivedAsset.originalPath, forType: .string)
            }
        }
    }

    private var icon: String {
        switch archivedAsset.kind {
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
        switch archivedAsset.kind {
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
        switch archivedAsset.owner {
        case .claude: .orange
        case .codex: .blue
        case .agents: .green
        case .project: .teal
        case .unknown: .secondary
        }
    }
}
