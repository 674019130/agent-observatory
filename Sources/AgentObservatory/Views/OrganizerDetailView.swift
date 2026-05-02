import AgentObservatoryCore
import AppKit
import SwiftUI

struct OrganizerDetailView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        Group {
            if let group = store.selectedCleanupGroup {
                CleanupReviewGroupDetail(group: group)
            } else if let recommendation = store.selectedOrganizationRecommendation {
                OrganizerRecommendationDetail(recommendation: recommendation)
            } else if let bucket = store.selectedOrganizationBucket {
                OrganizerBucketDetail(bucket: bucket)
            } else {
                EmptyStateView(
                    title: store.t(.organizerInspector),
                    message: store.t(.organizerInspectorMessage),
                    systemImage: "sidebar.right"
                )
            }
        }
        .navigationTitle(store.t(.organizerInspector))
    }
}

private struct CleanupReviewGroupDetail: View {
    @EnvironmentObject private var store: AssetStore
    let group: CleanupReviewGroup

    private var assets: [AgentAsset] {
        group.assetPaths.compactMap { path in
            store.assets.first { $0.path == path }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorPanel(title: store.t(.cleanupReview), systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            BadgeView(text: L10n.cleanupAction(group.action, language: store.appLanguage), tint: actionTint)
                            BadgeView(text: L10n.cleanupRisk(group.risk, language: store.appLanguage), tint: riskTint)
                            CountBadge(count: group.assetPaths.count, tint: .teal)
                            Spacer()
                        }

                        Text(group.title)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(group.summary)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if group.canApplyAutomatically {
                            Toggle(
                                store.t(.approveForApply),
                                isOn: Binding(
                                    get: { store.isCleanupGroupApproved(group) },
                                    set: { store.setCleanupGroupApproved(group, approved: $0) }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                }

                InspectorPanel(title: store.t(.cleanupEvidence), systemImage: "checkmark.seal") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(group.evidence, id: \.self) { evidence in
                            Label(evidence, systemImage: "checkmark")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                InspectorPanel(title: store.t(.affectedAssets), systemImage: "tray.full") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(assets) { asset in
                            Button {
                                store.selectAsset(path: asset.path)
                            } label: {
                                OrganizerAssetSummary(asset: asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if store.approvedCleanupGroupCount > 0 {
                    InspectorPanel(title: store.t(.manualFollowUp), systemImage: "play.circle") {
                        Button {
                            store.applyApprovedCleanupGroups()
                        } label: {
                            Label(store.t(.applyApprovedCleanup), systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var actionTint: Color {
        switch group.action {
        case .archive:
            .orange
        case .hide:
            .purple
        case .merge:
            .blue
        case .review:
            .yellow
        case .keep:
            .green
        }
    }

    private var riskTint: Color {
        switch group.risk {
        case .low:
            .green
        case .medium:
            .orange
        case .high:
            .red
        }
    }
}

private struct OrganizerRecommendationDetail: View {
    @EnvironmentObject private var store: AssetStore
    let recommendation: OrganizationRecommendation

    private var primaryAsset: AgentAsset? {
        store.assets.first { $0.path == recommendation.primaryAssetPath }
    }

    private var relatedAssets: [AgentAsset] {
        recommendation.relatedAssetPaths.compactMap { path in
            store.assets.first { $0.path == path }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorPanel(title: store.t(.recommendationDetail), systemImage: "sparkles.rectangle.stack") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            BadgeView(text: L10n.organizationAction(recommendation.action, language: store.appLanguage), tint: actionTint)
                            BadgeView(text: "\(store.t(.confidence)) \(Int((recommendation.confidence * 100).rounded()))%", tint: .secondary)
                            Spacer()
                        }

                        Text(recommendation.title)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(recommendation.reason)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Toggle(
                            store.t(.approveForApply),
                            isOn: Binding(
                                get: { store.isOrganizationRecommendationApproved(recommendation) },
                                set: { store.setOrganizationRecommendationApproved(recommendation, approved: $0) }
                            )
                        )
                        .toggleStyle(.checkbox)
                    }
                }

                InspectorPanel(title: store.t(.primaryAsset), systemImage: "doc.text.magnifyingglass") {
                    if let primaryAsset {
                        OrganizerAssetSummary(asset: primaryAsset)
                    } else {
                        Text(displayPath(recommendation.primaryAssetPath))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Button {
                            store.selectAsset(path: recommendation.primaryAssetPath)
                        } label: {
                            Label(store.t(.openPrimaryAsset), systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(recommendation.primaryAssetPath, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .help(store.t(.copyPath))

                        Spacer()
                    }
                }

                InspectorPanel(title: store.t(.relatedAssets), systemImage: "link") {
                    if relatedAssets.isEmpty {
                        Text(store.t(.noOutgoingReferences))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(relatedAssets) { asset in
                                Button {
                                    store.selectAsset(path: asset.path)
                                } label: {
                                    OrganizerAssetSummary(asset: asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                InspectorPanel(title: store.t(.manualFollowUp), systemImage: "person.crop.circle.badge.checkmark") {
                    Text(store.t(.manualOnlyNotice))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        store.applyApprovedOrganizationActions()
                    } label: {
                        Label(store.t(.applyApproved), systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(store.approvedOrganizationRecommendationCount == 0 || store.isOrganizing)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var actionTint: Color {
        switch recommendation.action {
        case .keep:
            .green
        case .merge:
            .blue
        case .archive:
            .orange
        case .hide:
            .purple
        case .review:
            .yellow
        }
    }
}

private struct OrganizerBucketDetail: View {
    @EnvironmentObject private var store: AssetStore
    let bucket: OrganizationBucket

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorPanel(title: store.t(.bucketDetail), systemImage: "square.stack.3d.up") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            BadgeView(text: bucket.audience, tint: .blue)
                            BadgeView(text: L10n.assetKind(bucket.kind, language: store.appLanguage), tint: .teal)
                            CountBadge(count: bucket.assets.count, tint: .teal)
                            Spacer()
                        }

                        Text(bucket.title)
                            .font(.title3.weight(.semibold))

                        Text(bucket.summary)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                InspectorPanel(title: store.t(.affectedAssets), systemImage: "tray.full") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(bucket.assets) { digest in
                            Button {
                                store.selectAsset(path: digest.path)
                            } label: {
                                OrganizerDigestSummary(digest: digest)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct OrganizerAssetSummary: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(asset.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                BadgeView(text: L10n.agentOwner(asset.owner, language: store.appLanguage), tint: ownerTint(asset.owner))
                BadgeView(text: L10n.assetKind(asset.kind, language: store.appLanguage), tint: .blue)
            }

            Text(asset.displayPath)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .textSelection(.enabled)

            if !asset.summary.isEmpty {
                Text(asset.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OrganizerDigestSummary: View {
    @EnvironmentObject private var store: AssetStore
    let digest: OrganizationAssetDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(digest.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                BadgeView(text: L10n.agentOwner(digest.owner, language: store.appLanguage), tint: ownerTint(digest.owner))
            }

            Text(displayPath(digest.path))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .textSelection(.enabled)

            Text(digest.aiSummary ?? digest.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func ownerTint(_ owner: AgentOwner) -> Color {
    switch owner {
    case .claude:
        .orange
    case .codex:
        .blue
    case .agents:
        .green
    case .project:
        .teal
    case .unknown:
        .secondary
    }
}

private func displayPath(_ path: String) -> String {
    path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
}
