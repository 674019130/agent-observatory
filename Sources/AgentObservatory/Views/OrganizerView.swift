import AgentObservatoryCore
import SwiftUI

struct OrganizerView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var isInventoryExpanded = false
    @State private var isAISuggestionsExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CleanupReviewHeader()

                if let error = store.organizerError {
                    ManagementErrorBanner(message: error)
                }

                CleanupReviewMetrics()
                CleanupReviewGroupsSection()
                if !store.organizationPlan.recommendations.isEmpty {
                    DisclosureGroup(isExpanded: $isAISuggestionsExpanded) {
                        AIRecommendationNotesSection()
                            .padding(.top, 12)
                    } label: {
                        Label(store.t(.organizationPlan), systemImage: "sparkles")
                            .font(.headline)
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.45))
                    }
                }

                DisclosureGroup(isExpanded: $isInventoryExpanded) {
                    OrganizerMapSection()
                        .padding(.top, 12)
                } label: {
                    Label(store.t(.inventoryEvidence), systemImage: "map")
                        .font(.headline)
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(store.t(.aiOrganizer))
    }
}

private struct CleanupReviewHeader: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.t(.cleanupReview))
                    .font(.system(size: 28, weight: .semibold))
                Text(store.t(.cleanupReviewSubtitle))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(store.t(.cleanupGoal))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker(store.t(.cleanupGoal), selection: $store.cleanupReviewGoal) {
                    ForEach(CleanupReviewGoal.allCases) { goal in
                        Text(L10n.cleanupGoal(goal, language: store.appLanguage)).tag(goal)
                    }
                }
                .pickerStyle(.segmented)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    CleanupReviewButtons()
                }

                VStack(alignment: .leading, spacing: 8) {
                    CleanupReviewButtons()
                }
            }

            HStack(spacing: 10) {
                if store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing ? .primary : .secondary)
                    .lineLimit(2)
                Spacer()
            }

            if store.cleanupReviewSession.createdAt.timeIntervalSince1970 > 0 {
                Text("\(store.t(.updated)) \(store.cleanupReviewSession.createdAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusText: String {
        if store.isBuildingCleanupReview {
            return store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) }
                ?? store.t(.scanningForCleanupReview)
        }
        if store.isBuildingOrganizationMap {
            return store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) }
                ?? store.t(.scanningForOrganizationMap)
        }
        return store.organizerStatus ?? store.t(.cleanupReviewSubtitle)
    }
}

private struct CleanupReviewButtons: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        Button {
            store.startCleanupReview()
        } label: {
            Label(store.t(.startCleanupReview), systemImage: "checklist.checked")
        }
        .buttonStyle(.borderedProminent)
        .disabled(store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing)

        Button {
            store.generateOrganizationRecommendations(useAI: true)
        } label: {
            Label(store.t(.askAIForPlan), systemImage: "sparkles")
        }
        .buttonStyle(.bordered)
        .disabled(store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing)

        Button {
            store.buildOrganizationMap()
        } label: {
            Label(store.t(.buildMap), systemImage: "map")
        }
        .buttonStyle(.bordered)
        .disabled(store.isBuildingCleanupReview || store.isBuildingOrganizationMap || store.isOrganizing)
    }
}

private struct CleanupReviewMetrics: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            OrganizerMetric(
                title: store.t(.cleanupGroups),
                value: "\(store.cleanupReviewSession.groups.count)",
                systemImage: "checklist",
                tint: .blue
            )
            OrganizerMetric(
                title: store.t(.affectedAssets),
                value: "\(store.cleanupReviewAffectedAssetCount)",
                systemImage: "tray.full",
                tint: .teal
            )
            OrganizerMetric(
                title: store.t(.executableActions),
                value: "\(store.executableCleanupGroupCount)",
                systemImage: "play.circle",
                tint: .orange
            )
            OrganizerMetric(
                title: store.t(.approved),
                value: "\(store.approvedCleanupGroupCount)",
                systemImage: "checkmark.circle",
                tint: .green
            )
        }
    }
}

private struct OrganizerMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Spacer()
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct AIRecommendationNotesSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BadgeView(text: "\(store.t(.planSource)): \(store.organizationPlan.source)", tint: .secondary)
                Spacer()
            }

            ForEach(store.organizationPlan.recommendations.prefix(8)) { recommendation in
                Button {
                    store.selectOrganizationRecommendation(recommendation)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        BadgeView(text: L10n.organizationAction(recommendation.action, language: store.appLanguage), tint: actionTint(recommendation.action))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.title)
                                .font(.callout.weight(.semibold))
                                .lineLimit(2)
                            Text(recommendation.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(displayPath(recommendation.primaryAssetPath))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
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

private struct CleanupReviewGroupsSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(store.t(.cleanupGroups), systemImage: "checklist")
                    .font(.headline)
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

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    BadgeView(text: L10n.cleanupAction(group.action, language: store.appLanguage), tint: actionTint)
                    BadgeView(text: L10n.cleanupRisk(group.risk, language: store.appLanguage), tint: riskTint)
                    CountBadge(count: group.assetPaths.count, tint: .teal)
                    Spacer()
                    Button {
                        store.selectCleanupGroup(group)
                    } label: {
                        Image(systemName: "sidebar.right")
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
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Label(store.t(.cleanupEvidence), systemImage: "checkmark.seal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(group.evidence.prefix(3), id: \.self) { evidence in
                        Text(evidence)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(group.assetPaths.prefix(4), id: \.self) { path in
                        Text(displayPath(path))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
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

private struct OrganizerMapSection: View {
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
