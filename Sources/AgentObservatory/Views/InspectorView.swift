import AgentObservatoryCore
import AppKit
import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var selectedTab: InspectorTab = .overview

    var body: some View {
        Group {
            if let asset = store.selectedAsset {
                VStack(spacing: 0) {
                    InspectorHeader(asset: asset)
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .padding(.bottom, 12)

                    if let error = store.managementError {
                        ManagementErrorBanner(message: error)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 12)
                    }

                    Picker(store.t(.overview), selection: $selectedTab) {
                        ForEach(InspectorTab.allCases) { tab in
                            Label(tab.title(store: store), systemImage: tab.systemImage).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)

                    ScrollView {
                        tabContent(for: asset)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 22)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                EmptyStateView(
                    title: store.t(.selectAsset),
                    message: store.t(.selectAssetMessage),
                    systemImage: "sidebar.right"
                )
            }
        }
        .navigationTitle(store.selectedAsset?.title ?? store.t(.selectAsset))
    }

    @ViewBuilder
    private func tabContent(for asset: AgentAsset) -> some View {
        switch selectedTab {
        case .overview:
            VStack(alignment: .leading, spacing: 18) {
                SummaryPanel(asset: asset)
                LoadRoutePanel(asset: asset)
                MetadataPanel(asset: asset)
                DiagnosticsPanel(asset: asset)
            }
        case .diff:
            DiffPanel(comparison: store.comparison(for: asset))
        case .impact:
            ImpactPanel(impact: store.impact(for: asset))
        case .history:
            HistoryPanel()
        case .raw:
            PreviewPanel(asset: asset)
        }
    }
}

private enum InspectorTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case diff = "Diff"
    case impact = "Impact"
    case history = "History"
    case raw = "Raw"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: "doc.text.magnifyingglass"
        case .diff: "arrow.left.arrow.right"
        case .impact: "point.3.connected.trianglepath.dotted"
        case .history: "clock.arrow.circlepath"
        case .raw: "doc.plaintext"
        }
    }

    @MainActor
    func title(store: AssetStore) -> String {
        switch self {
        case .overview: store.t(.overview)
        case .diff: store.t(.diff)
        case .impact: store.t(.impact)
        case .history: store.t(.history)
        case .raw: store.t(.raw)
        }
    }
}

private struct InspectorHeader: View {
    @EnvironmentObject private var store: AssetStore
    @State private var isShowingArchiveSheet = false
    @State private var archiveReason = ""
    let asset: AgentAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(asset.title)
                    .font(.system(size: 28, weight: .semibold))
                    .lineLimit(2)
                Spacer()
                BadgeView(text: L10n.agentOwner(asset.owner, language: store.appLanguage), tint: ownerTint)
                BadgeView(text: L10n.assetKind(asset.kind, language: store.appLanguage), tint: .blue)
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(asset.displayPath)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.path)])
                } label: {
                    Label(store.t(.finder), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(asset.path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .compactHitTarget()
                }
                .buttonStyle(.bordered)
                .help(store.t(.copyPath))
                Button {
                    store.hideAsset(asset)
                } label: {
                    Image(systemName: "eye.slash")
                        .compactHitTarget()
                }
                .buttonStyle(.bordered)
                .help(store.t(.hideFromObservatory))
                Button {
                    archiveReason = ""
                    isShowingArchiveSheet = true
                } label: {
                    Image(systemName: "archivebox")
                        .compactHitTarget()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .help(store.t(.archiveFile))
            }
        }
        .sheet(isPresented: $isShowingArchiveSheet) {
            ArchiveConfirmationSheet(
                asset: asset,
                reason: $archiveReason,
                onArchive: {
                    store.archiveAsset(asset, reason: archiveReason)
                    archiveReason = ""
                    isShowingArchiveSheet = false
                },
                onCancel: {
                    archiveReason = ""
                    isShowingArchiveSheet = false
                }
            )
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

private struct SummaryPanel: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        InspectorPanel(title: store.t(.whatItDoes), systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                if let aiSummary = store.aiSummaries[asset.contentHash] {
                    Text(aiSummary)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(asset.summary)
                        .font(.body)
                        .foregroundStyle(asset.statusFlags.contains(.needsSummary) ? .secondary : .primary)
                        .textSelection(.enabled)
                }

                if let error = store.aiErrors[asset.contentHash] {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button {
                        store.enrichSelectedAsset()
                    } label: {
                        if store.enrichingAssetID == asset.id {
                            Label(store.t(.explaining), systemImage: "hourglass")
                        } else {
                            Label(store.t(.explainWithOpenAI), systemImage: "sparkles")
                        }
                    }
                    .disabled(store.enrichingAssetID != nil || !OpenAIPayloadGuard.isSafeForAI(asset))
                    .buttonStyle(.borderedProminent)

                    Text(store.t(.usesRedactedPreviewTextOnly))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LoadRoutePanel: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    private var route: ContextLoadRoute {
        ContextLoadAnalyzer().route(for: asset)
    }

    var body: some View {
        InspectorPanel(title: store.t(.loadRoute), systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.loadRouteDescription(route, language: store.appLanguage))
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                LazyVGrid(
                    columns: [
                        GridItem(.fixed(112), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ],
                    spacing: 10
                ) {
                    MetadataRow(
                        label: store.t(.loadedInto),
                        value: L10n.loadDestination(route.destination, language: store.appLanguage)
                    )
                    MetadataRow(
                        label: store.t(.loadedHow),
                        value: L10n.loadTrigger(route.trigger, language: store.appLanguage)
                    )
                    MetadataRow(
                        label: store.t(.promptPlacement),
                        value: route.destination.isPromptMaterial ? store.t(.promptMaterial) : store.t(.registryMaterial)
                    )
                    MetadataRow(
                        label: store.t(.layer),
                        value: L10n.contextLayer(route.layer, language: store.appLanguage)
                    )
                    if let role = route.role {
                        MetadataRow(
                            label: store.t(.kind),
                            value: L10n.contextRole(role, language: store.appLanguage)
                        )
                    }
                    if let skillInstallOrigin = route.skillInstallOrigin {
                        MetadataRow(
                            label: store.t(.skillSource),
                            value: L10n.skillInstallOrigin(skillInstallOrigin, language: store.appLanguage)
                        )
                    }
                }

                if let skillInstallOrigin = route.skillInstallOrigin {
                    Label(
                        L10n.skillInstallOriginDescription(skillInstallOrigin, language: store.appLanguage),
                        systemImage: "wand.and.stars"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !route.surfaces.isEmpty {
                    HStack(spacing: 7) {
                        Text(store.t(.usedBy))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(route.surfaces) { surface in
                            BadgeView(
                                text: surface == .claude ? store.t(.claudeCode) : L10n.agentOwner(surface, language: store.appLanguage),
                                tint: tint(for: surface)
                            )
                        }
                    }
                }

                Label(store.t(.inferredFromPathAndType), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tint(for owner: AgentOwner) -> Color {
        switch owner {
        case .claude: .orange
        case .codex: .blue
        case .agents: .green
        case .project: .teal
        case .unknown: .secondary
        }
    }
}

private struct MetadataPanel: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        InspectorPanel(title: store.t(.metadata), systemImage: "info.circle") {
            LazyVGrid(columns: [GridItem(.fixed(110), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                MetadataRow(label: store.t(.owner), value: L10n.agentOwner(asset.owner, language: store.appLanguage))
                MetadataRow(label: store.t(.kind), value: L10n.assetKind(asset.kind, language: store.appLanguage))
                MetadataRow(label: store.t(.scope), value: asset.scope)
                MetadataRow(label: store.t(.modified), value: asset.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? store.t(.unknown))
                MetadataRow(label: store.t(.size), value: ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file))
                MetadataRow(label: store.t(.hash), value: asset.contentHash)
                if let trigger = asset.trigger {
                    MetadataRow(label: store.t(.trigger), value: trigger)
                }
            }
        }
    }
}

private struct DiagnosticsPanel: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        InspectorPanel(title: store.t(.diagnostics), systemImage: "stethoscope") {
            if asset.statusFlags.isEmpty {
                Label(store.t(.noLocalIssuesDetected), systemImage: "checkmark.seal")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(asset.statusFlags) { flag in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: flag))
                                .foregroundStyle(tint(for: flag))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.statusFlag(flag, language: store.appLanguage))
                                    .font(.callout.weight(.semibold))
                                Text(L10n.statusFlagMessage(flag, language: store.appLanguage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func icon(for flag: AssetStatusFlag) -> String {
        switch flag {
        case .duplicate: "rectangle.on.rectangle"
        case .stalePath: "arrow.triangle.branch"
        case .hasScripts: "chevron.left.forwardslash.chevron.right"
        case .needsSummary: "text.bubble"
        case .secretRisk: "lock.trianglebadge.exclamationmark"
        case .largeFile: "externaldrive.badge.exclamationmark"
        case .unreadable: "xmark.octagon"
        }
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

private struct DiffPanel: View {
    @EnvironmentObject private var store: AssetStore
    let comparison: AssetComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorPanel(title: store.t(.claudeCodexDrift), systemImage: "arrow.left.arrow.right") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(comparison.base.owner.rawValue)
                                .font(.headline)
                            Text(comparison.base.displayPath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        DiffStatusBadge(status: comparison.status)
                    }

                    if let counterpart = comparison.counterpart {
                        Button {
                            store.selectAsset(path: counterpart.path)
                        } label: {
                            Label(counterpart.displayPath, systemImage: "arrow.uturn.forward")
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Label(store.t(.noCounterpartFound), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            if comparison.counterpart != nil {
                InspectorPanel(title: store.t(.fieldChanges), systemImage: "list.bullet.rectangle") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(comparison.rows) { row in
                            DiffRowView(row: row)
                        }
                    }
                }
            }
        }
    }
}

private struct DiffRowView: View {
    @EnvironmentObject private var store: AssetStore
    let row: AssetDiffRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.diffField(row.field, language: store.appLanguage))
                    .font(.callout.weight(.semibold))
                Spacer()
                BadgeView(text: L10n.diffRowStatus(row.status, language: store.appLanguage), tint: tint)
            }

            HStack(alignment: .top, spacing: 10) {
                DiffValueBox(title: store.t(.base), value: row.leftValue)
                DiffValueBox(title: store.t(.counterpart), value: row.rightValue)
            }
        }
        .padding(.vertical, 4)
    }

    private var tint: Color {
        switch row.status {
        case .same: .green
        case .changed: .orange
        case .missingLeft, .missingRight: .red
        }
    }
}

private struct DiffValueBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "-" : value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct DiffStatusBadge: View {
    @EnvironmentObject private var store: AssetStore
    let status: AssetComparisonStatus

    var body: some View {
        BadgeView(text: L10n.comparisonStatus(status, language: store.appLanguage), tint: tint)
    }

    private var tint: Color {
        switch status {
        case .same: .green
        case .changed: .orange
        case .missingCounterpart: .red
        }
    }
}

private struct ImpactPanel: View {
    @EnvironmentObject private var store: AssetStore
    let impact: AssetImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorPanel(title: store.t(.impact), systemImage: "point.3.connected.trianglepath.dotted") {
                HStack(spacing: 8) {
                    GraphNode(title: "\(impact.incomingReferences.count)", subtitle: store.t(.incoming), tint: .blue)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    GraphNode(title: store.t(.current), subtitle: store.t(.asset), tint: .teal)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    GraphNode(title: "\(impact.outgoingReferences.count)", subtitle: store.t(.outgoing), tint: .green)
                    if impact.missingReferenceCount > 0 {
                        GraphNode(title: "\(impact.missingReferenceCount)", subtitle: store.t(.missing), tint: .red)
                    }
                }
            }

            ReferenceListPanel(
                title: store.t(.incomingReferences),
                systemImage: "arrow.down.left.and.arrow.up.right",
                emptyMessage: store.t(.noIncomingReferences),
                links: impact.incomingReferences,
                direction: .incoming
            )

            ReferenceListPanel(
                title: store.t(.outgoingReferences),
                systemImage: "arrow.up.right",
                emptyMessage: store.t(.noOutgoingReferences),
                links: impact.outgoingReferences,
                direction: .outgoing
            )
        }
    }
}

private enum ReferenceDirection {
    case incoming
    case outgoing
}

private struct ReferenceListPanel: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let systemImage: String
    let emptyMessage: String
    let links: [AssetDependencyLink]
    let direction: ReferenceDirection

    var body: some View {
        InspectorPanel(title: title, systemImage: systemImage) {
            if links.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(links) { link in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: link.isMissing ? "questionmark.diamond" : "link")
                                .foregroundStyle(link.isMissing ? .red : .secondary)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(primaryText(for: link))
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                                Text(link.reference)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if link.isStaleReference {
                                BadgeView(text: store.t(.stale), tint: .red)
                            }
                            if link.isMissing {
                                BadgeView(text: store.t(.missing), tint: .orange)
                            }
                            if link.targetPath != nil || direction == .incoming {
                                Button {
                                    store.selectAsset(path: direction == .incoming ? link.sourcePath : link.targetPath)
                                } label: {
                                    Image(systemName: "arrow.right.circle")
                                        .compactHitTarget()
                                }
                                .buttonStyle(.borderless)
                                .help(store.t(.openRelatedAsset))
                                .disabled(direction == .outgoing && link.targetPath == nil)
                            }
                        }
                    }
                }
            }
        }
    }

    private func primaryText(for link: AssetDependencyLink) -> String {
        switch direction {
        case .incoming:
            return link.sourceTitle
        case .outgoing:
            return link.targetTitle ?? store.t(.unresolvedReference)
        }
    }
}

private struct HistoryPanel: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InspectorPanel(title: store.t(.indexState), systemImage: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        store.isIndexStale ? store.t(.indexStaleMessage) : store.t(.indexCurrentMessage),
                        systemImage: store.isIndexStale ? "exclamationmark.triangle" : "checkmark.seal"
                    )
                    .foregroundStyle(store.isIndexStale ? .orange : .green)

                    if let date = store.lastFileEventDate {
                        Text("\(store.t(.lastFileEvent)): \(date.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }

                    if !store.lastFileEventPaths.isEmpty {
                        ForEach(store.lastFileEventPaths, id: \.self) { path in
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            ChangeListPanel(title: store.t(.added), systemImage: "plus.circle", changes: store.lastChangeSummary.added, tint: .green)
            ChangeListPanel(title: store.t(.changed), systemImage: "circle.dashed", changes: store.lastChangeSummary.changed, tint: .orange)
            ChangeListPanel(title: store.t(.removed), systemImage: "minus.circle", changes: store.lastChangeSummary.removed, tint: .red)
        }
    }
}

private struct ChangeListPanel: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let systemImage: String
    let changes: [AssetChange]
    let tint: Color

    var body: some View {
        InspectorPanel(title: title, systemImage: systemImage) {
            if changes.isEmpty {
                Text(store.t(.noChangesInLatestComparison))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(changes) { change in
                        HStack(spacing: 8) {
                            BadgeView(text: change.owner.shortName, tint: tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.title)
                                    .font(.callout.weight(.medium))
                                Text(change.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PreviewPanel: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset
    @State private var rawContent: RawContentResult?
    @State private var isLoading = false

    var body: some View {
        InspectorPanel(title: store.t(.rawContent), systemImage: "doc.plaintext") {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    ProgressView(store.t(.loadingFullContent))
                        .controlSize(.small)
                } else if let rawContent {
                    if rawContent.isSensitive {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                rawContent.isRedactedPreview ? store.t(.redactedLocalPreviewNote) : rawContent.text,
                                systemImage: "lock.trianglebadge.exclamationmark"
                            )
                            .foregroundStyle(.orange)

                            if rawContent.isRedactedPreview {
                                ScrollView([.vertical, .horizontal]) {
                                    Text(rawContent.text.isEmpty ? store.t(.emptyFile) : rawContent.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minHeight: 180, maxHeight: 420)
                            } else {
                                Button {
                                    Task {
                                        await loadRawContent(allowLargeFile: false, allowSensitivePreview: true)
                                    }
                                } label: {
                                    Label(store.t(.showRedactedLocalPreview), systemImage: "eye")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else if rawContent.isTooLarge {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(rawContent.text, systemImage: "externaldrive.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            Button {
                                Task {
                                    await loadRawContent(allowLargeFile: true, allowSensitivePreview: false)
                                }
                            } label: {
                                Label(store.t(.loadFullContent), systemImage: "doc.plaintext")
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if rawContent.isUnreadable {
                        Label(rawContent.text, systemImage: "xmark.octagon")
                            .foregroundStyle(.red)
                    } else {
                        ScrollView([.vertical, .horizontal]) {
                            Text(rawContent.text.isEmpty ? store.t(.emptyFile) : rawContent.text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 260, maxHeight: 620)
                    }
                } else {
                    Text(store.t(.noRawContentLoaded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(asset.path)-\(asset.contentHash)") {
            await loadRawContent(allowLargeFile: false, allowSensitivePreview: false)
        }
    }

    @MainActor
    private func loadRawContent(allowLargeFile: Bool, allowSensitivePreview: Bool) async {
        isLoading = true
        rawContent = nil
        let path = asset.path
        let language = store.appLanguage
        let forceSensitive = asset.statusFlags.contains(.secretRisk)
        let result = await Task.detached(priority: .userInitiated) {
            RawContentReader().read(
                path: path,
                allowLargeFile: allowLargeFile,
                allowSensitivePreview: allowSensitivePreview,
                forceSensitive: forceSensitive,
                language: language
            )
        }.value
        rawContent = result
        isLoading = false
    }
}

private struct DependencyGraph: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        HStack(spacing: 8) {
            GraphNode(title: asset.title, subtitle: L10n.assetKind(asset.kind, language: store.appLanguage), tint: .blue)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            GraphNode(title: "\(asset.dependencies.count + asset.relatedFiles.count)", subtitle: store.t(.links), tint: .green)
        }
    }
}

private struct GraphNode: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.24))
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        Text(label)
            .foregroundStyle(.secondary)
        Text(value)
            .textSelection(.enabled)
            .lineLimit(2)
    }
}
