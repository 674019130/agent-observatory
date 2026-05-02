import AgentObservatoryCore
import AppKit
import SwiftUI

struct HiddenView: View {
    @EnvironmentObject private var store: AssetStore

    private var hiddenAssets: [AgentAsset] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.hiddenAssets }
        return store.hiddenAssets.filter { asset in
            [
                asset.title,
                asset.summary,
                asset.path,
                asset.owner.rawValue,
                asset.kind.rawValue
            ]
            .joined(separator: "\n")
            .lowercased()
            .contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HiddenHeader(count: hiddenAssets.count)

            if let error = store.managementError {
                ManagementErrorBanner(message: error)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            if hiddenAssets.isEmpty {
                EmptyStateView(
                    title: store.t(.noHiddenAssets),
                    message: store.t(.noHiddenAssetsMessage),
                    systemImage: "eye.slash"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(hiddenAssets) { asset in
                            HiddenAssetRow(asset: asset)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(store.t(.hiddenItems))
    }
}

private struct HiddenHeader: View {
    @EnvironmentObject private var store: AssetStore
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Label(store.t(.hiddenItems), systemImage: "eye.slash")
                .font(.headline)
            CountBadge(count: count, tint: .purple)
            Spacer()
            if count > 0 {
                Button {
                    store.unhideAllAssets()
                } label: {
                    Label(store.t(.unhideAll), systemImage: "eye")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct HiddenAssetRow: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconTint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(asset.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(asset.displayPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 10)

                BadgeView(text: L10n.agentOwner(asset.owner, language: store.appLanguage), tint: ownerTint)
                BadgeView(text: L10n.assetKind(asset.kind, language: store.appLanguage), tint: .blue)
            }

            if !asset.summary.isEmpty {
                Text(asset.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button {
                    store.unhideAsset(asset)
                } label: {
                    Label(store.t(.restoreToAssets), systemImage: "eye")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.path)])
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .help(store.t(.showInFinder))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(asset.path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help(store.t(.copyPath))

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
            Button(store.t(.restoreToAssets)) {
                store.unhideAsset(asset)
            }
            Button(store.t(.showInFinder)) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.path)])
            }
            Button(store.t(.copyPath)) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(asset.path, forType: .string)
            }
        }
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
}
