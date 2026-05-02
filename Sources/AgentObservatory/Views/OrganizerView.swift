import AgentObservatoryCore
import SwiftUI

struct OrganizerView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                OrganizerHeader()

                if let error = store.organizerError {
                    ManagementErrorBanner(message: error)
                }

                OrganizerMetrics()
                OrganizerMapSection()
                OrganizerPlanSection()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(store.t(.aiOrganizer))
    }
}

private struct OrganizerHeader: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.t(.aiOrganizer))
                    .font(.system(size: 28, weight: .semibold))
                Text(store.t(.organizerSubtitle))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                OrganizerActionButtons(isVertical: false)
                OrganizerActionButtons(isVertical: true)
            }

            HStack(spacing: 10) {
                if store.isOrganizing || store.isBuildingOrganizationMap {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(store.isOrganizing || store.isBuildingOrganizationMap ? .primary : .secondary)
                    .lineLimit(2)
                Spacer()
                BadgeView(text: store.t(.humanReviewRequired), tint: .orange)
            }

            if let date = store.lastOrganizationMapDate {
                Text("\(store.t(.updated)) \(date.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusText: String {
        if store.isBuildingOrganizationMap {
            return store.scanProgress.map { L10n.scanProgressMessage($0, language: store.appLanguage) }
                ?? store.t(.scanningForOrganizationMap)
        }
        return store.organizerStatus ?? store.t(.manualOnlyNotice)
    }
}

private struct OrganizerActionButtons: View {
    @EnvironmentObject private var store: AssetStore
    let isVertical: Bool

    var body: some View {
        if isVertical {
            VStack(alignment: .leading, spacing: 8) {
                buttons
            }
        } else {
            HStack(spacing: 8) {
                buttons
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            store.buildOrganizationMap()
        } label: {
            Label(store.t(.buildMap), systemImage: "map")
        }
        .buttonStyle(.bordered)
        .disabled(store.isOrganizing || store.isBuildingOrganizationMap)

        Button {
            store.generateOrganizationRecommendations(useAI: false)
        } label: {
            Label(store.t(.localPlan), systemImage: "list.clipboard")
        }
        .buttonStyle(.bordered)
        .disabled(store.isOrganizing || store.isBuildingOrganizationMap)

        Button {
            store.generateOrganizationRecommendations(useAI: true)
        } label: {
            Label(store.t(.askAIForPlan), systemImage: "sparkles")
        }
        .buttonStyle(.borderedProminent)
        .disabled(store.isOrganizing || store.isBuildingOrganizationMap)
    }
}

private struct OrganizerMetrics: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            OrganizerMetric(
                title: store.t(.assets),
                value: "\(store.organizationMap.totalAssets)",
                systemImage: "tray.full",
                tint: .blue
            )
            OrganizerMetric(
                title: store.t(.buckets),
                value: "\(store.organizationMap.buckets.count)",
                systemImage: "square.stack.3d.up",
                tint: .teal
            )
            OrganizerMetric(
                title: store.t(.recommendations),
                value: "\(store.organizationPlan.recommendations.count)",
                systemImage: "list.bullet.clipboard",
                tint: .purple
            )
            OrganizerMetric(
                title: store.t(.approved),
                value: "\(store.approvedOrganizationRecommendationCount)",
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

private struct OrganizerMapSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(store.t(.organizationMap), systemImage: "map")
                .font(.headline)

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
                        OrganizerBucketCard(bucket: bucket)
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
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct OrganizerPlanSection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(store.t(.organizationPlan), systemImage: "list.bullet.clipboard")
                    .font(.headline)
                Spacer()
                BadgeView(text: "\(store.t(.planSource)): \(store.organizationPlan.source)", tint: .secondary)
            }

            Text(store.t(.manualOnlyNotice))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button {
                    store.applyApprovedOrganizationActions()
                } label: {
                    Label(store.t(.applyApproved), systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(store.approvedOrganizationRecommendationCount == 0 || store.isOrganizing)
            }

            if store.organizationPlan.recommendations.isEmpty {
                EmptyOrganizerRow(text: store.t(.noOrganizationRecommendations), systemImage: "sparkles")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.organizationPlan.recommendations) { recommendation in
                        OrganizerRecommendationRow(recommendation: recommendation)
                    }
                }
            }
        }
    }
}

private struct OrganizerRecommendationRow: View {
    @EnvironmentObject private var store: AssetStore
    let recommendation: OrganizationRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { store.isOrganizationRecommendationApproved(recommendation) },
                    set: { store.setOrganizationRecommendationApproved(recommendation, approved: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    BadgeView(text: L10n.organizationAction(recommendation.action, language: store.appLanguage), tint: actionTint)
                    BadgeView(text: "\(store.t(.confidence)) \(Int((recommendation.confidence * 100).rounded()))%", tint: .secondary)
                    Spacer()
                    Button {
                        store.selectAsset(path: recommendation.primaryAssetPath)
                    } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    .buttonStyle(.plain)
                    .help(store.t(.selectAsset))
                }

                Text(recommendation.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)

                Text(recommendation.reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(displayPath(recommendation.primaryAssetPath))
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .textSelection(.enabled)

                if !recommendation.relatedAssetPaths.isEmpty {
                    HStack(spacing: 6) {
                        Label(store.t(.relatedAssets), systemImage: "link")
                            .font(.caption.weight(.semibold))
                        CountBadge(count: recommendation.relatedAssetPaths.count, tint: .purple)
                    }
                    ForEach(recommendation.relatedAssetPaths.prefix(3), id: \.self) { path in
                        Text(displayPath(path))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(actionTint.opacity(0.28))
        }
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
