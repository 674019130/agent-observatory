import AgentObservatoryCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        let summary = store.dashboardSummary

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DashboardHeader(summary: summary)
                IndexHealthSection(summary: summary)
                RiskQueueSection(risks: summary.topRisks)
                DriftSection(drift: summary.drift)
                RecentChangesSection(changes: summary.recentChanges)
                DependencyHotspotsSection(hotspots: summary.dependencyHotspots)
                AICoverageSection(coverage: summary.aiCoverage)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(store.t(.dashboard))
    }
}

private struct DashboardHeader: View {
    @EnvironmentObject private var store: AssetStore
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.t(.dashboard))
                        .font(.system(size: 28, weight: .semibold))
                    Text(store.t(.dashboardSubtitle))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.scan()
                } label: {
                    Label(store.isIndexStale ? store.t(.refreshStaleIndex) : store.t(.refresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isScanning)
            }

            if store.isIndexStale {
                Label(store.t(.sourceFilesChangedAfterScan), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            } else if summary.indexHealth.totalAssets == 0 {
                Label(store.t(.noAssetsIndexed), systemImage: "tray")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }
}

private struct IndexHealthSection: View {
    @EnvironmentObject private var store: AssetStore
    let summary: DashboardSummary

    var body: some View {
        DashboardSection(title: store.t(.indexHealth), systemImage: "checkmark.seal") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                MetricTile(
                    title: summary.indexHealth.isStale ? store.t(.stale) : store.t(.indexCurrent),
                    subtitle: store.t(.indexState),
                    value: summary.indexHealth.isStale ? "!" : store.t(.ok),
                    systemImage: summary.indexHealth.isStale ? "exclamationmark.triangle" : "checkmark.seal",
                    tint: summary.indexHealth.isStale ? .orange : .green
                ) {
                    if summary.indexHealth.isStale {
                        store.scan()
                    }
                }

                MetricTile(
                    title: store.t(.assets),
                    subtitle: store.t(.currentIndex),
                    value: "\(summary.indexHealth.totalAssets)",
                    systemImage: "tray.full",
                    tint: .blue
                ) {
                    store.showAssets()
                }

                MetricTile(
                    title: store.t(.warnings),
                    subtitle: store.t(.needsAttention),
                    value: "\(summary.indexHealth.warningCount)",
                    systemImage: "exclamationmark.triangle",
                    tint: summary.indexHealth.warningCount > 0 ? .orange : .green
                ) {
                    store.select(health: .warnings)
                }

                MetricTile(
                    title: store.t(.sources),
                    subtitle: "\(summary.indexHealth.existingSourceCount) \(store.t(.exists))",
                    value: "\(summary.indexHealth.activeSourceCount)",
                    systemImage: "folder.badge.gearshape",
                    tint: .teal
                ) {
                    store.showAssets()
                }
            }
        }
    }
}

private struct RiskQueueSection: View {
    @EnvironmentObject private var store: AssetStore
    let risks: [DashboardRiskItem]

    var body: some View {
        DashboardSection(title: store.t(.riskQueue), systemImage: "list.bullet.clipboard") {
            if risks.isEmpty {
                EmptyDashboardRow(text: store.t(.noDashboardRisks), systemImage: "checkmark.seal")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(risks) { risk in
                        Button {
                            store.openRisk(risk)
                        } label: {
                            RiskRow(risk: risk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DriftSection: View {
    @EnvironmentObject private var store: AssetStore
    let drift: DashboardDriftSummary

    var body: some View {
        DashboardSection(title: store.t(.claudeCodexDrift), systemImage: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    DriftCounter(title: store.t(.changed), count: drift.changed, tint: .orange)
                    DriftCounter(title: store.t(.missing), count: drift.missingCounterpart, tint: .red)
                    DriftCounter(title: store.t(.same), count: drift.same, tint: .green)
                }

                ProgressView(value: drift.total == 0 ? 0 : Double(drift.same), total: Double(max(1, drift.total)))
                    .tint(.green)

                HStack {
                    Text("\(drift.total) \(store.t(.comparableNames))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        store.select(health: .duplicates)
                    } label: {
                        Label(store.t(.reviewRelated), systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

private struct RecentChangesSection: View {
    @EnvironmentObject private var store: AssetStore
    let changes: AssetChangeSummary

    var body: some View {
        DashboardSection(title: store.t(.recentChanges), systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    DriftCounter(title: store.t(.added), count: changes.added.count, tint: .green)
                    DriftCounter(title: store.t(.changed), count: changes.changed.count, tint: .orange)
                    DriftCounter(title: store.t(.removed), count: changes.removed.count, tint: .red)
                }

                let visibleChanges = Array((changes.added + changes.changed + changes.removed).prefix(5))
                if visibleChanges.isEmpty {
                    EmptyDashboardRow(text: store.t(.noRecentChanges), systemImage: "clock")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleChanges) { change in
                            Button {
                                store.openChange(change)
                            } label: {
                                ChangeRow(change: change)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct DependencyHotspotsSection: View {
    @EnvironmentObject private var store: AssetStore
    let hotspots: [DashboardDependencyHotspot]

    var body: some View {
        DashboardSection(title: store.t(.dependencyHotspots), systemImage: "point.3.connected.trianglepath.dotted") {
            if hotspots.isEmpty {
                EmptyDashboardRow(text: store.t(.noDependencyHotspots), systemImage: "link")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(hotspots.prefix(6)) { hotspot in
                        Button {
                            store.openHotspot(hotspot)
                        } label: {
                            HotspotRow(hotspot: hotspot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct AICoverageSection: View {
    @EnvironmentObject private var store: AssetStore
    let coverage: DashboardAICoverage

    var body: some View {
        DashboardSection(title: store.t(.aiCoverage), systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int((coverage.ratio * 100).rounded()))%")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("\(coverage.explained) \(store.t(.explained)), \(coverage.missing) \(store.t(.missing))")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: coverage.ratio)
                    .tint(.purple)
            }
        }
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricTile: View {
    let title: String
    let subtitle: String
    let value: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RiskRow: View {
    @EnvironmentObject private var store: AssetStore
    let risk: DashboardRiskItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            BadgeView(text: L10n.riskSeverity(risk.severity, language: store.appLanguage), tint: severityTint)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(risk.assetTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    BadgeView(text: L10n.riskCategory(risk.category, language: store.appLanguage), tint: categoryTint)
                }
                Text(localizedRiskMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowHitTarget()
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var severityTint: Color {
        switch risk.severity {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .secondary
        }
    }

    private var categoryTint: Color {
        switch risk.category {
        case .missingDependency, .staleReference, .stalePath: .red
        case .sensitiveFile, .unreadable: .orange
        case .duplicate, .largeFile: .purple
        case .needsSummary: .blue
        }
    }

    private var localizedRiskMessage: String {
        guard store.appLanguage == .simplifiedChinese else { return risk.message }
        switch risk.category {
        case .missingDependency:
            return risk.message.replacingOccurrences(of: "Missing reference: ", with: "缺失引用：")
        case .staleReference:
            return "引用仍指向 Claude 时期路径。"
        case .sensitiveFile:
            return L10n.text(.secretRiskMessage, language: store.appLanguage)
        case .unreadable:
            return L10n.text(.unreadableMessage, language: store.appLanguage)
        case .stalePath:
            return "文件内容仍引用 Claude 时期路径。"
        case .duplicate:
            return "另一个已索引资产拥有相同的规范化身份。"
        case .largeFile:
            return "由于文件较大，预览已被限制。"
        case .needsSummary:
            return L10n.text(.needsSummaryMessage, language: store.appLanguage)
        }
    }
}

private struct DriftCounter: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChangeRow: View {
    let change: AssetChange

    var body: some View {
        HStack(spacing: 8) {
            BadgeView(text: change.owner.shortName, tint: ownerTint(change.owner))
            VStack(alignment: .leading, spacing: 2) {
                Text(change.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(displayPath(change.path))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowHitTarget(cornerRadius: 7)
    }
}

private struct HotspotRow: View {
    @EnvironmentObject private var store: AssetStore
    let hotspot: DashboardDependencyHotspot

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            BadgeView(text: hotspot.owner.shortName, tint: ownerTint(hotspot.owner))
            VStack(alignment: .leading, spacing: 2) {
                Text(hotspot.assetTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text("\(hotspot.incomingCount) \(store.t(.incoming)), \(hotspot.missingOutgoingCount) \(store.t(.missing)), \(hotspot.staleReferenceCount) \(store.t(.stale))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowHitTarget(cornerRadius: 7)
    }
}

private struct EmptyDashboardRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

private func ownerTint(_ owner: AgentOwner) -> Color {
    switch owner {
    case .claude: .orange
    case .codex: .blue
    case .agents: .green
    case .project: .teal
    case .unknown: .secondary
    }
}

private func displayPath(_ path: String) -> String {
    path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
}
