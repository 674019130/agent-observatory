import AgentObservatoryCore
import AppKit
import SwiftUI

struct CleanupExecutionPreviewSheet: View {
    @EnvironmentObject private var store: AssetStore
    let preview: CleanupExecutionPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: preview.hasExecutableActions ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(preview.hasExecutableActions ? .green : .secondary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t(.cleanupPreviewTitle))
                        .font(.title2.weight(.semibold))
                    Text(store.t(.cleanupPreviewSubtitle))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            BadgeView(
                text: L10n.cleanupGoal(preview.goal, language: store.appLanguage),
                tint: .blue
            )

            VStack(alignment: .leading, spacing: 10) {
                if preview.hasExecutableActions {
                    ForEach(previewLines, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Label(store.t(.cleanupPreviewNoAutomaticChanges), systemImage: "info.circle")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                Button(store.t(.cancel)) {
                    store.dismissCleanupExecutionPreview()
                }
                .keyboardShortcut(.cancelAction)

                Button(preview.hasExecutableActions ? store.t(.cleanupPreviewAgree) : store.t(.cleanupPreviewDone)) {
                    store.confirmCleanupExecutionPreview()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
    }

    private var previewLines: [String] {
        var lines: [String] = []
        if preview.hideCount > 0 {
            lines.append(String(format: store.t(.cleanupPreviewWillHide), preview.hideCount))
        }
        if preview.mergeArchiveCount > 0 {
            lines.append(String(format: store.t(.cleanupPreviewWillMerge), preview.mergeArchiveCount))
        }
        if preview.archiveCount > 0 {
            lines.append(String(format: store.t(.cleanupPreviewWillArchive), preview.archiveCount))
        }
        if preview.manualGroupCount > 0 {
            lines.append(String(format: store.t(.cleanupPreviewManualGroups), preview.manualGroupCount))
        }
        return lines
    }
}

struct AdvisorBriefSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.organizerBrief.headline.isEmpty ? store.t(.noOrganizationMap) : store.organizerBrief.headline)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                BadgeView(
                    text: "\(store.t(.recommendedNextStep)): \(L10n.cleanupGoal(store.organizerBrief.recommendedGoal, language: store.appLanguage))",
                    tint: .blue
                )
            }

            Text(store.organizerBrief.summary.isEmpty ? store.t(.mapUsesCurrentIndex) : store.organizerBrief.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12) {
                BriefBulletColumn(
                    title: store.t(.currentShape),
                    systemImage: "rectangle.3.group",
                    bullets: store.organizerBrief.landscape
                )
                BriefBulletColumn(
                    title: store.t(.priorityFocus),
                    systemImage: "target",
                    bullets: store.organizerBrief.focusAreas
                )
            }
        }
    }
}

private struct BriefBulletColumn: View {
    let title: String
    let systemImage: String
    let bullets: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if bullets.isEmpty {
                Text("-")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(.secondary)
                                .padding(.top, 7)
                            Text(bullet)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct AIRecommendationNotesSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BadgeView(text: "\(store.t(.planSource)): \(L10n.planSource(store.organizationPlan.source, language: store.appLanguage))", tint: .secondary)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                ForEach(store.organizationPlan.recommendations.prefix(8)) { recommendation in
                    Button {
                        store.selectOrganizationRecommendation(recommendation)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                BadgeView(text: L10n.organizationAction(recommendation.action, language: store.appLanguage), tint: actionTint(recommendation.action))
                                if !recommendation.canApplyAutomatically {
                                    BadgeView(text: store.t(.manualRecommendationRequired), tint: .secondary)
                                }
                                Spacer()
                            }

                            Text(recommendation.title)
                                .font(.callout.weight(.semibold))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(recommendation.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(displayPath(recommendation.primaryAssetPath))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionTint(_ action: OrganizationAction) -> Color {
        switch action {
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
}

struct CleanupReviewGroupsSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BadgeView(text: L10n.cleanupGoal(store.cleanupReviewSession.goal, language: store.appLanguage), tint: .secondary)
                Spacer()
                if store.approvedCleanupGroupCount > 0 {
                    Button {
                        store.applyApprovedCleanupGroups()
                    } label: {
                        Label(store.t(.applyApprovedCleanup), systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }

            if store.cleanupReviewSession.groups.isEmpty {
                EmptyOrganizerRow(text: store.t(.noCleanupGroups), systemImage: "checkmark.seal")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.cleanupReviewSession.groups) { group in
                        CleanupReviewGroupRow(group: group)
                    }
                }
            }
        }
    }
}

private struct CleanupReviewGroupRow: View {
    @EnvironmentObject private var store: AssetStore
    let group: CleanupReviewGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if group.canApplyAutomatically {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.isCleanupGroupApproved(group) },
                        set: { store.setCleanupGroupApproved(group, approved: $0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)
                .padding(.top, 2)
            } else {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .padding(.top, 3)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    BadgeView(text: L10n.cleanupAction(group.action, language: store.appLanguage), tint: actionTint)
                    CountBadge(count: group.assetPaths.count, tint: .teal)
                    Spacer()
                    Button {
                        store.selectCleanupGroup(group)
                    } label: {
                        Image(systemName: "sidebar.right")
                            .compactHitTarget()
                    }
                    .buttonStyle(.plain)
                    .help(store.t(.openGroup))
                }

                Text(group.title)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(group.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectCleanupGroup(group)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(store.selectedCleanupGroupID == group.id ? Color.accentColor.opacity(0.75) : actionTint.opacity(0.28))
        }
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
}

struct OrganizerMapSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.organizationMap.totalAssets == 0 {
                EmptyOrganizerRow(
                    text: store.lastOrganizationMapDate == nil ? store.t(.noOrganizationMap) : store.t(.noAssetsIndexed),
                    systemImage: "map"
                )
            } else {
                OrganizerAudienceStrip()
                OrganizerKindStrip()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                    ForEach(store.organizationMap.buckets.prefix(12)) { bucket in
                        Button {
                            store.selectOrganizationBucket(bucket)
                        } label: {
                            OrganizerBucketCard(bucket: bucket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct OrganizerAudienceStrip: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t(.audiences))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(store.organizationMap.audienceCounts.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                    BadgeView(text: "\(entry.key) \(entry.value)", tint: .blue)
                }
            }
        }
    }
}

private struct OrganizerKindStrip: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.t(.categories))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(store.organizationMap.kindCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { entry in
                    BadgeView(text: "\(L10n.assetKind(entry.key, language: store.appLanguage)) \(entry.value)", tint: .teal)
                }
            }
        }
    }
}

private struct OrganizerBucketCard: View {
    @EnvironmentObject private var store: AssetStore
    let bucket: OrganizationBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(bucket.audience)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.assetKind(bucket.kind, language: store.appLanguage))
                        .font(.callout.weight(.semibold))
                }
                Spacer()
                CountBadge(count: bucket.assets.count, tint: .teal)
            }

            Text(bucket.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(bucket.assets.prefix(3)) { asset in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(displayPath(asset.path))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(store.organizationDetailSelection.bucketID == bucket.id ? Color.accentColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct EmptyOrganizerRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

private func displayPath(_ path: String) -> String {
    path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
}
