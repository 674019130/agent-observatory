import AgentObservatoryCore
import AppKit
import SwiftUI

struct SkillTriggerRadarView: View {
    @EnvironmentObject private var store: AssetStore

    private var groupedConflicts: [(SkillTriggerConflictSeverity, [SkillTriggerConflict])] {
        SkillTriggerConflictSeverity.allCases.compactMap { severity in
            let conflicts = store.skillTriggerConflicts.filter { $0.severity == severity }
            return conflicts.isEmpty ? nil : (severity, conflicts)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                OfficialDocTipsPanel(
                    tips: OfficialDocTips.tips(
                        for: .triggerRadar,
                        language: store.appLanguage
                    )
                )
                metrics

                if store.skillTriggerConflicts.isEmpty {
                    EmptyRadarState()
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(groupedConflicts, id: \.0) { severity, conflicts in
                            conflictSection(severity: severity, conflicts: conflicts)
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(store.t(.triggerRadar))
        .onAppear {
            guard store.selectedSkillTriggerConflictID == nil,
                  let first = store.skillTriggerConflicts.first else {
                return
            }
            store.selectSkillTriggerConflict(first)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.red.opacity(0.12))
                Image(systemName: "scope")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.t(.triggerRadar))
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(1)
                Text(store.t(.triggerRadarSubtitle))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            BadgeView(text: store.t(.includedBundledBaseline), tint: .blue)
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            RadarMetricTile(
                title: store.t(.highRisk),
                value: store.highSkillTriggerConflictCount,
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )
            RadarMetricTile(
                title: store.t(.mediumRisk),
                value: store.mediumSkillTriggerConflictCount,
                systemImage: "exclamationmark.circle.fill",
                tint: .orange
            )
            RadarMetricTile(
                title: store.t(.affectedSkills),
                value: store.skillTriggerRadarAffectedSkillCount,
                systemImage: "wand.and.stars",
                tint: .teal
            )
        }
    }

    private func conflictSection(
        severity: SkillTriggerConflictSeverity,
        conflicts: [SkillTriggerConflict]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.skillTriggerConflictSeverity(severity, language: store.appLanguage))
                    .font(.headline)
                CountBadge(count: conflicts.count, tint: severityTint(severity))
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(conflicts) { conflict in
                    SkillTriggerConflictRow(
                        conflict: conflict,
                        isSelected: store.selectedSkillTriggerConflict?.id == conflict.id
                    ) {
                        store.selectSkillTriggerConflict(conflict)
                    }
                }
            }
        }
    }
}

private struct RadarMetricTile: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct SkillTriggerConflictRow: View {
    @EnvironmentObject private var store: AssetStore
    let conflict: SkillTriggerConflict
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "scope")
                        .foregroundStyle(severityTint(conflict.severity))
                    Text(conflict.primaryAsset.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text("/")
                        .foregroundStyle(.tertiary)
                    Text(conflict.competingAsset.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 10)
                    BadgeView(
                        text: L10n.skillTriggerConflictSeverity(conflict.severity, language: store.appLanguage),
                        tint: severityTint(conflict.severity)
                    )
                }

                HStack(spacing: 8) {
                    BadgeView(text: L10n.agentOwner(conflict.primaryAsset.owner, language: store.appLanguage), tint: ownerTint(conflict.primaryAsset.owner))
                    BadgeView(text: L10n.agentOwner(conflict.competingAsset.owner, language: store.appLanguage), tint: ownerTint(conflict.competingAsset.owner))
                    if !conflict.sharedSurfaces.isEmpty {
                        Text(conflict.sharedSurfaces.map { $0 == .claude ? store.t(.claudeCode) : L10n.agentOwner($0, language: store.appLanguage) }.joined(separator: " + "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(Int(conflict.score * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !conflict.sharedTerms.isEmpty {
                    Text(conflict.sharedTerms.prefix(6).joined(separator: "  "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rowHitTarget()
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: isSelected ? 1.2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyRadarState: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 42))
                .foregroundStyle(.green)
            Text(store.t(.conflictFree))
                .font(.title3.weight(.semibold))
            Text(store.t(.conflictFreeMessage))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

struct SkillTriggerConflictDetailView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var didCopyAgentPrompt = false
    let conflict: SkillTriggerConflict

    private var comparison: SkillTriggerContractComparison {
        SkillTriggerContractComparator().comparison(
            for: conflict,
            language: store.appLanguage
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                ContractSummaryPanel(comparison: comparison)

                ForEach(comparison.sections, id: \.kind) { section in
                    ContractComparisonPanel(
                        section: section,
                        primaryTitle: conflict.primaryAsset.title,
                        competingTitle: conflict.competingAsset.title
                    )
                }

                advancedDetails

                InspectorPanel(title: store.t(.exportAgentPrompt), systemImage: "doc.on.clipboard") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.t(.exportAgentPromptDescription))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button {
                                copyAgentPrompt()
                            } label: {
                                Label(store.t(.copyAgentPrompt), systemImage: "doc.on.clipboard")
                            }

                            if didCopyAgentPrompt {
                                Label(store.t(.agentPromptCopied), systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(store.t(.triggerRadar))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                BadgeView(
                    text: L10n.skillTriggerConflictSeverity(conflict.severity, language: store.appLanguage),
                    tint: severityTint(conflict.severity)
                )
                BadgeView(text: "\(store.t(.confidenceScore)) \(Int(conflict.score * 100))%", tint: .blue)
            }

            Text(comparison.headline)
                .font(.title2.weight(.semibold))
                .lineLimit(2)

            Text("\(conflict.primaryAsset.title) / \(conflict.competingAsset.title)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var advancedDetails: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                InspectorPanel(title: store.t(.conflictEvidence), systemImage: "text.magnifyingglass") {
                    VStack(alignment: .leading, spacing: 12) {
                        signalGrid
                        if !conflict.sharedTerms.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(store.t(.sharedTerms))
                                    .font(.subheadline.weight(.semibold))
                                FlowTags(values: conflict.sharedTerms, tint: .blue)
                            }
                        }
                    }
                }

                InspectorPanel(title: store.t(.competingSkills), systemImage: "wand.and.stars") {
                    VStack(spacing: 10) {
                        DetailSkillCard(
                            title: store.t(.primarySkill),
                            asset: conflict.primaryAsset,
                            route: conflict.primaryRoute,
                            buttonTitle: store.t(.openPrimarySkill)
                        ) {
                            store.focusContextAsset(path: conflict.primaryAsset.path)
                        }

                        DetailSkillCard(
                            title: store.t(.competingSkill),
                            asset: conflict.competingAsset,
                            route: conflict.competingRoute,
                            buttonTitle: store.t(.openCompetingSkill)
                        ) {
                            store.focusContextAsset(path: conflict.competingAsset.path)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label(store.t(.advancedDetails), systemImage: "slider.horizontal.3")
                .font(.headline)
                .padding(.vertical, 3)
                .rowHitTarget(cornerRadius: 7)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }

    private var signalGrid: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(store.t(.conflictSignals))
                .font(.subheadline.weight(.semibold))
            ForEach(conflict.signals, id: \.self) { signal in
                Label(L10n.skillTriggerConflictSignal(signal, language: store.appLanguage), systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func copyAgentPrompt() {
        let prompt = SkillTriggerConflictPromptExporter().prompt(
            for: conflict,
            language: store.appLanguage
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        didCopyAgentPrompt = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didCopyAgentPrompt = false
        }
    }
}

private struct ContractSummaryPanel: View {
    @EnvironmentObject private var store: AssetStore
    let comparison: SkillTriggerContractComparison

    var body: some View {
        InspectorPanel(title: store.t(.triggerContract), systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                Text(comparison.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(comparison.recommendedAction, systemImage: "sparkles")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ContractComparisonPanel: View {
    @EnvironmentObject private var store: AssetStore
    let section: SkillTriggerContractSection
    let primaryTitle: String
    let competingTitle: String

    var body: some View {
        InspectorPanel(title: section.title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ContractTextColumn(
                        title: store.t(.primarySkill),
                        skillTitle: primaryTitle,
                        text: section.primaryText,
                        tint: .blue
                    )

                    Divider()

                    ContractTextColumn(
                        title: store.t(.competingSkill),
                        skillTitle: competingTitle,
                        text: section.competingText,
                        tint: .orange
                    )
                }

                if !section.sharedTerms.isEmpty {
                    FlowTags(values: section.sharedTerms, tint: .blue)
                }

                Text(section.takeaway)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var systemImage: String {
        switch section.kind {
        case .trigger: "target"
        case .responsibility: "square.split.2x1"
        case .loading: "arrow.triangle.branch"
        }
    }
}

private struct ContractTextColumn: View {
    let title: String
    let skillTitle: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(skillTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailSkillCard: View {
    @EnvironmentObject private var store: AssetStore
    let title: String
    let asset: AgentAsset
    let route: ContextLoadRoute
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                BadgeView(text: L10n.skillInstallOrigin(route.skillInstallOrigin ?? .unknown, language: store.appLanguage), tint: .blue)
            }

            Text(asset.title)
                .font(.headline)
                .lineLimit(2)

            PathPreviewLink(
                path: asset.path,
                displayPath: asset.displayPath,
                font: .caption.monospaced(),
                foregroundColor: .secondary,
                lineLimit: 2,
                language: store.appLanguage
            )

            HStack(spacing: 8) {
                Button(buttonTitle, action: action)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.path)])
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .compactHitTarget()
                }
                .help(store.t(.showInFinder))
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FlowTags: View {
    let values: [String]
    let tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(values.prefix(10), id: \.self) { value in
                BadgeView(text: value, tint: tint)
            }
        }
    }
}

private func severityTint(_ severity: SkillTriggerConflictSeverity) -> Color {
    switch severity {
    case .high: .red
    case .medium: .orange
    case .low: .yellow
    }
}

private func ownerTint(_ owner: AgentOwner) -> Color {
    switch owner {
    case .claude: .orange
    case .codex: .blue
    case .agents: .green
    case .project: .purple
    case .unknown: .secondary
    }
}
