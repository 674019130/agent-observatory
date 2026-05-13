import AgentObservatoryCore
import AppKit
import SwiftUI

struct OrganizerRunHero: View {
    @EnvironmentObject private var store: AssetStore
    let run: OrganizerRun
    let isBusy: Bool
    let onViewClassificationMap: () -> Void
    let onReviewActionPack: (OrganizerActionPack) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    store.prepareOrganizerRun()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.white)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.t(.organizeNow))
                                .font(.title3.weight(.semibold))
                            Text(run.summary.isEmpty ? store.t(.mapUsesCurrentIndex) : run.summary)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)

                Menu {
                    Button {
                        store.buildOrganizationMap()
                        onViewClassificationMap()
                    } label: {
                        Label(store.t(.presetClassify), systemImage: "square.grid.2x2")
                    }
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(store.organizerRunMarkdown(), forType: .string)
                        store.markOrganizerBriefCopied()
                    } label: {
                        Label(store.t(.presetCopyBrief), systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
                .disabled(isBusy)
                .help(store.t(.moreCleanupActions))
            }

            OrganizerRunMetricGrid(run: run)

            if !run.actionPacks.isEmpty {
                OrganizerActionPackList(
                    packs: run.actionPacks.prefix(4).map { $0 },
                    onReview: onReviewActionPack
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.35))
        }
    }
}

private struct OrganizerRunMetricGrid: View {
    @EnvironmentObject private var store: AssetStore
    let run: OrganizerRun

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
            OrganizerRunMetric(title: store.t(.assets), value: run.totalAssetCount, tint: .blue)
            OrganizerRunMetric(title: store.t(.duplicates), value: run.duplicateAssetCount, tint: .orange)
            OrganizerRunMetric(title: store.t(.hidden), value: run.noiseAssetCount, tint: .purple)
            OrganizerRunMetric(title: store.t(.secrets), value: run.sensitiveAssetCount, tint: .red)
            OrganizerRunMetric(title: store.t(.stalePaths), value: run.stalePathAssetCount, tint: .yellow)
        }
    }
}

private struct OrganizerRunMetric: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct OrganizerActionPackList: View {
    let packs: [OrganizerActionPack]
    let onReview: ((OrganizerActionPack) -> Void)?

    init(
        packs: [OrganizerActionPack],
        onReview: ((OrganizerActionPack) -> Void)? = nil
    ) {
        self.packs = packs
        self.onReview = onReview
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(packs) { pack in
                OrganizerActionPackRow(pack: pack, onReview: onReview)
            }
        }
    }
}

struct OrganizerActionPackRow: View {
    @EnvironmentObject private var store: AssetStore
    let pack: OrganizerActionPack
    let onReview: ((OrganizerActionPack) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(pack.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    CountBadge(count: pack.assetPaths.count, tint: tint)
                    Spacer()
                    BadgeView(text: L10n.organizerActionPackRisk(pack.risk, language: store.appLanguage), tint: tint)
                }

                Text(pack.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    BadgeView(
                        text: pack.canExecuteAutomatically ? store.t(.organizerRunAutomatic) : store.t(.organizerRunManualReview),
                        tint: pack.canExecuteAutomatically ? .green : .secondary
                    )
                    if pack.isReversible {
                        BadgeView(text: store.t(.organizerRunReversible), tint: .blue)
                    }
                    if pack.requiresHumanReview {
                        BadgeView(text: store.t(.organizerRunProtected), tint: .secondary)
                    }
                    if pack.requiresHumanReview, let onReview {
                        Spacer(minLength: 8)
                        Button {
                            onReview(pack)
                        } label: {
                            Label(store.t(.organizerRunReviewPack), systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: String {
        switch pack.kind {
        case .mergeDuplicates:
            "square.on.square"
        case .hideNoise:
            "eye.slash"
        case .reviewSensitive:
            "lock.shield"
        case .reviewUnreadable:
            "xmark.octagon"
        case .clarifyUnknown:
            "text.magnifyingglass"
        case .reviewStalePaths:
            "arrow.triangle.branch"
        }
    }

    private var tint: Color {
        switch pack.risk {
        case .low:
            .green
        case .medium:
            .orange
        case .high:
            .red
        }
    }
}

struct OrganizerRunReviewSheet: View {
    @EnvironmentObject private var store: AssetStore
    @State private var inspectedActionPack: OrganizerActionPack?
    let run: OrganizerRun
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: run.hasExecutablePacks ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(run.hasExecutablePacks ? .green : .secondary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t(.organizerRunReviewTitle))
                        .font(.title2.weight(.semibold))
                    Text(store.t(.organizerRunReviewSubtitle))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if run.actionPacks.isEmpty {
                    Label(store.t(.organizerRunNoActions), systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    OrganizerActionPackList(packs: run.actionPacks) { pack in
                        inspectedActionPack = pack
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button {
                    onViewDetails()
                } label: {
                    Label(store.t(.organizerRunViewDetails), systemImage: "sidebar.right")
                }

                Spacer()

                Button(store.t(.cancel)) {
                    store.dismissOrganizerRunReview()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    store.confirmOrganizerRunExecution()
                } label: {
                    Label(store.t(.organizerRunAgreeAndApply), systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!run.hasExecutablePacks)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
        .sheet(item: $inspectedActionPack) { pack in
            OrganizerActionPackReviewSheet(pack: pack)
                .environmentObject(store)
        }
    }
}

struct OrganizerActionPackReviewSheet: View {
    @EnvironmentObject private var store: AssetStore
    @Environment(\.dismiss) private var dismiss
    let pack: OrganizerActionPack

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.t(.actionPackReviewTitle))
                        .font(.title2.weight(.semibold))
                    Text(store.t(.actionPackReviewSubtitle))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(pack.title)
                        .font(.headline)
                    CountBadge(count: pack.assetPaths.count, tint: tint)
                    Spacer()
                    BadgeView(text: L10n.organizerActionPackRisk(pack.risk, language: store.appLanguage), tint: tint)
                }

                Text(guidance)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Label(store.t(.affectedFiles), systemImage: "doc.text.magnifyingglass")
                    .font(.headline)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(pack.assetPaths, id: \.self) { path in
                            PathPreviewLink(
                                path: path,
                                font: .system(.caption, design: .monospaced),
                                foregroundColor: .secondary,
                                language: store.appLanguage
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 220)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pack.assetPaths.joined(separator: "\n"), forType: .string)
                } label: {
                    Label(store.t(.copyAffectedPaths), systemImage: "doc.on.clipboard")
                }

                Spacer()

                Button(store.t(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    store.selectAsset(path: pack.assetPaths.first)
                    dismiss()
                } label: {
                    Label(store.t(.openFirstAffectedFile), systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pack.assetPaths.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
    }

    private var guidance: String {
        switch pack.kind {
        case .reviewSensitive:
            store.t(.sensitiveActionGuidance)
        case .reviewUnreadable:
            store.t(.unreadableActionGuidance)
        case .clarifyUnknown:
            store.t(.clarifyActionGuidance)
        case .reviewStalePaths:
            store.t(.stalePathActionGuidance)
        case .mergeDuplicates, .hideNoise:
            pack.summary
        }
    }

    private var icon: String {
        switch pack.kind {
        case .mergeDuplicates:
            "square.on.square"
        case .hideNoise:
            "eye.slash"
        case .reviewSensitive:
            "lock.shield"
        case .reviewUnreadable:
            "xmark.octagon"
        case .clarifyUnknown:
            "text.magnifyingglass"
        case .reviewStalePaths:
            "arrow.triangle.branch"
        }
    }

    private var tint: Color {
        switch pack.risk {
        case .low:
            .green
        case .medium:
            .orange
        case .high:
            .red
        }
    }
}
