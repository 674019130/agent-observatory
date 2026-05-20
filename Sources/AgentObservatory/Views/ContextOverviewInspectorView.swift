import AgentObservatoryCore
import Charts
import SwiftUI

struct ContextOverviewInspectorView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var animateIn = false

    private var snapshot: ContextOverviewSnapshot {
        ContextOverviewSnapshot(store: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ContextBriefHero(snapshot: snapshot, animateIn: animateIn)
                ContextMixChartCard(snapshot: snapshot, animateIn: animateIn)
                ContextPriorityBrief(snapshot: snapshot)
                ContextNextBestActions(snapshot: snapshot)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(briefTitle(language: store.appLanguage))
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) {
                animateIn = true
            }
        }
        .onChange(of: snapshot.signature) { _, _ in
            animateIn = false
            withAnimation(.easeOut(duration: 0.65).delay(0.05)) {
                animateIn = true
            }
        }
    }
}

private struct ContextOverviewSnapshot {
    let totalAssets: Int
    let memoryCount: Int
    let capabilityCount: Int
    let mcpCount: Int
    let assemblyCount: Int
    let warningCount: Int
    let isIndexStale: Bool
    let topRisks: [DashboardRiskItem]
    let highConflictCount: Int
    let triggerConflictCount: Int
    let oneSidedMemoryCount: Int
    let bothSidesMemoryCount: Int
    let userCapabilityGroups: Int
    let officialCapabilityGroups: Int
    let aiCoverage: DashboardAICoverage
    let surfaceCounts: [(owner: AgentOwner, count: Int)]

    @MainActor init(store: AssetStore) {
        let catalog = store.contextCatalog
        let memoryGroups = MemoryMigrationPlanner().groups(items: catalog.memoryItems)
        let capabilitySections = ContextCapabilityGrouper().sections(items: catalog.capabilityItems)

        totalAssets = store.visibleAssets.count
        memoryCount = catalog.memoryItems.count
        mcpCount = catalog.capabilityItems.filter { $0.asset.kind == .mcp }.count
        capabilityCount = catalog.capabilityItems.filter { $0.asset.kind != .mcp }.count
        assemblyCount = catalog.assemblySteps.count
        warningCount = store.dashboardSummary.indexHealth.warningCount
        isIndexStale = store.dashboardSummary.indexHealth.isStale
        topRisks = Array(store.dashboardSummary.topRisks.prefix(3))
        highConflictCount = store.highSkillTriggerConflictCount
        triggerConflictCount = store.skillTriggerConflicts.count
        oneSidedMemoryCount = memoryGroups.filter { $0.status == .claudeOnly || $0.status == .codexOnly }.count
        bothSidesMemoryCount = memoryGroups.filter { $0.status == .bothSides }.count
        userCapabilityGroups = capabilitySections.first { $0.category == .userSkills }?.groups.count ?? 0
        officialCapabilityGroups = capabilitySections.first { $0.category == .officialCapabilities }?.groups.count ?? 0
        aiCoverage = store.dashboardSummary.aiCoverage
        surfaceCounts = AgentOwner.allCases
            .filter { $0 != .unknown }
            .map { owner in (owner: owner, count: store.summary.sources[owner, default: 0]) }
            .filter { $0.count > 0 }
            .sorted { left, right in
                if left.count != right.count { return left.count > right.count }
                return left.owner.rawValue < right.owner.rawValue
            }
    }

    var readinessScore: Int {
        guard totalAssets > 0 else { return 0 }
        var score = 100
        if isIndexStale { score -= 16 }
        score -= min(28, Int((Double(warningCount) / Double(max(totalAssets, 1))) * 120))
        score -= min(20, oneSidedMemoryCount * 2)
        score -= min(18, highConflictCount * 4)
        return max(0, min(100, score))
    }

    var signature: String {
        [
            totalAssets,
            memoryCount,
            capabilityCount,
            mcpCount,
            assemblyCount,
            warningCount,
            oneSidedMemoryCount,
            highConflictCount,
            userCapabilityGroups,
            officialCapabilityGroups,
            Int(aiCoverage.ratio * 100)
        ]
        .map(String.init)
        .joined(separator: "-")
    }

    func mixSlices(language: AppLanguage) -> [ContextMixSlice] {
        [
            ContextMixSlice(title: L10n.text(.memories, language: language), count: memoryCount, tint: .indigo),
            ContextMixSlice(title: L10n.text(.capabilities, language: language), count: capabilityCount, tint: .teal),
            ContextMixSlice(title: "MCP", count: mcpCount, tint: .orange),
            ContextMixSlice(title: L10n.text(.assembly, language: language), count: assemblyCount, tint: .blue)
        ]
        .filter { $0.count > 0 }
    }
}

private struct ContextMixSlice: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let tint: Color
}

private struct ContextBriefHero: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    let animateIn: Bool

    private var progress: Double {
        animateIn ? Double(snapshot.readinessScore) / 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            readinessTint(snapshot.readinessScore).gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(snapshot.readinessScore)")
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("/100")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    Text(briefTitle(language: store.appLanguage))
                        .font(.title3.weight(.semibold))
                    Text(briefSubtitle(snapshot: snapshot, language: store.appLanguage))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                BriefMetricPill(
                    title: store.t(.assets),
                    value: snapshot.totalAssets,
                    systemImage: "tray.full",
                    tint: .blue
                )
                BriefMetricPill(
                    title: store.t(.warnings),
                    value: snapshot.warningCount,
                    systemImage: "exclamationmark.triangle",
                    tint: snapshot.warningCount > 0 ? .orange : .green
                )
                BriefMetricPill(
                    title: store.t(.riskQueue),
                    value: snapshot.topRisks.count,
                    systemImage: "list.bullet.clipboard",
                    tint: snapshot.topRisks.isEmpty ? .green : .red
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.34))
        }
    }
}

private struct BriefMetricPill: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.11), in: Capsule())
    }
}

private struct ContextMixChartCard: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    let animateIn: Bool

    private var slices: [ContextMixSlice] {
        snapshot.mixSlices(language: store.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContextBriefCardHeader(
                title: contextMixTitle(language: store.appLanguage),
                subtitle: contextMixSubtitle(language: store.appLanguage),
                systemImage: "chart.bar.xaxis",
                tint: .blue
            )

            if slices.isEmpty {
                Label(store.t(.noAssetsIndexed), systemImage: "tray")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart(slices) { slice in
                    BarMark(
                        x: .value(contextMixCountAxis(language: store.appLanguage), animateIn ? slice.count : 0),
                        y: .value(contextMixDomainAxis(language: store.appLanguage), slice.title)
                    )
                    .foregroundStyle(slice.tint.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(slice.count)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let title = value.as(String.self) {
                                Text(title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(max(132, slices.count * 34)))
            }
        }
        .briefCard()
    }
}

private struct ContextPriorityBrief: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContextBriefCardHeader(
                title: priorityBriefTitle(language: store.appLanguage),
                subtitle: priorityBriefSubtitle(language: store.appLanguage),
                systemImage: "list.bullet.clipboard",
                tint: .orange
            )

            VStack(spacing: 8) {
                PrioritySignalRow(
                    title: memorySyncTileTitle(language: store.appLanguage),
                    metric: "\(snapshot.oneSidedMemoryCount)",
                    detail: memorySyncTileDetail(snapshot: snapshot, language: store.appLanguage),
                    label: memorySyncPriorityLabel(snapshot: snapshot, language: store.appLanguage),
                    systemImage: "arrow.left.arrow.right",
                    tint: snapshot.oneSidedMemoryCount > 0 ? .orange : .green
                ) {
                    store.showMemories()
                }

                PrioritySignalRow(
                    title: radarTileTitle(language: store.appLanguage),
                    metric: "\(snapshot.triggerConflictCount)",
                    detail: radarTileDetail(snapshot: snapshot, language: store.appLanguage),
                    label: radarPriorityLabel(snapshot: snapshot, language: store.appLanguage),
                    systemImage: "scope",
                    tint: snapshot.highConflictCount > 0 ? .red : (snapshot.triggerConflictCount > 0 ? .orange : .green)
                ) {
                    store.showTriggerRadar()
                }

                PrioritySignalRow(
                    title: userCapabilityTileTitle(language: store.appLanguage),
                    metric: "\(snapshot.userCapabilityGroups)",
                    detail: userCapabilityTileDetail(snapshot: snapshot, language: store.appLanguage),
                    label: userCapabilityPriorityLabel(language: store.appLanguage),
                    systemImage: "wand.and.stars",
                    tint: .teal
                ) {
                    store.showCapabilities()
                }

                PrioritySignalRow(
                    title: aiCoverageTitle(language: store.appLanguage),
                    metric: "\(Int((snapshot.aiCoverage.ratio * 100).rounded()))%",
                    detail: aiCoverageDetail(snapshot: snapshot, language: store.appLanguage),
                    label: aiCoveragePriorityLabel(snapshot: snapshot, language: store.appLanguage),
                    systemImage: "sparkles",
                    tint: snapshot.aiCoverage.missing > 0 ? .purple : .green
                ) {
                    store.showAssets()
                }
            }
        }
        .briefCard()
    }
}

private struct PrioritySignalRow: View {
    let title: String
    let metric: String
    let detail: String
    let label: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        BadgeView(text: label, tint: tint)
                    }

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(metric)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.18))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ContextNextBestActions: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContextBriefCardHeader(
                title: nextActionTitle(language: store.appLanguage),
                subtitle: nextActionSubtitle(language: store.appLanguage),
                systemImage: "checklist",
                tint: .orange
            )

            VStack(alignment: .leading, spacing: 8) {
                if snapshot.isIndexStale {
                    OverviewActionRow(
                        title: store.t(.refreshStaleIndex),
                        detail: store.t(.sourceFilesChangedAfterScan),
                        systemImage: "arrow.clockwise",
                        tint: .orange
                    ) {
                        store.scan()
                    }
                }

                if snapshot.topRisks.isEmpty && !snapshot.isIndexStale {
                    OverviewStableRow(language: store.appLanguage)
                } else {
                    ForEach(snapshot.topRisks) { risk in
                        OverviewRiskRow(risk: risk) {
                            store.openRisk(risk)
                        }
                    }
                }
            }

            if !snapshot.surfaceCounts.isEmpty {
                Divider()
                SurfaceBalanceStrip(surfaceCounts: snapshot.surfaceCounts)
            }
        }
        .briefCard()
    }
}

private struct ContextBriefCardHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct OverviewActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(9)
            .rowHitTarget(cornerRadius: 7)
        }
        .buttonStyle(.plain)
    }
}

private struct OverviewRiskRow: View {
    @EnvironmentObject private var store: AssetStore
    let risk: DashboardRiskItem
    let action: () -> Void

    private var tint: Color {
        switch risk.severity {
        case .critical, .high:
            .red
        case .medium:
            .orange
        case .low:
            .secondary
        }
    }

    var body: some View {
        OverviewActionRow(
            title: risk.assetTitle,
            detail: "\(L10n.riskCategory(risk.category, language: store.appLanguage)) · \(risk.message)",
            systemImage: "exclamationmark.triangle",
            tint: tint,
            action: action
        )
    }
}

private struct OverviewStableRow: View {
    let language: AppLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.green)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(stableTitle(language: language))
                    .font(.callout.weight(.medium))
                Text(stableDetail(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(9)
    }
}

private struct SurfaceBalanceStrip: View {
    @EnvironmentObject private var store: AssetStore
    let surfaceCounts: [(owner: AgentOwner, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(surfaceBalanceTitle(language: store.appLanguage))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(surfaceCounts, id: \.owner) { item in
                HStack(spacing: 8) {
                    Text(L10n.agentOwner(item.owner, language: store.appLanguage))
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 86, alignment: .leading)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(ownerTint(item.owner).gradient)
                            .frame(width: max(6, proxy.size.width * CGFloat(item.count) / CGFloat(maxSurfaceCount)))
                    }
                    .frame(height: 7)
                    Text("\(item.count)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private var maxSurfaceCount: Int {
        max(1, surfaceCounts.map(\.count).max() ?? 1)
    }
}

private struct BriefCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.38))
            }
    }
}

private extension View {
    func briefCard() -> some View {
        modifier(BriefCardModifier())
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

private func readinessTint(_ score: Int) -> Color {
    switch score {
    case 86...:
        .green
    case 68...:
        .orange
    default:
        .red
    }
}

private func briefTitle(language: AppLanguage) -> String {
    switch language {
    case .english:
        "Context Brief"
    case .simplifiedChinese:
        "上下文态势"
    }
}

private func briefSubtitle(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    if snapshot.totalAssets == 0 {
        return language == .simplifiedChinese
            ? "刷新索引后，这里会展示上下文结构、风险和迁移机会。"
            : "Refresh the index to see structure, risks, and migration opportunities."
    }
    if snapshot.isIndexStale {
        return language == .simplifiedChinese
            ? "索引已经过期，先刷新会让下面的判断更可信。"
            : "The index is stale. Refresh first so the signals below are trustworthy."
    }
    if snapshot.topRisks.isEmpty && snapshot.oneSidedMemoryCount == 0 {
        return language == .simplifiedChinese
            ? "当前最重要的上下文信号稳定，可以继续按左侧分类深入查看。"
            : "The most important context signals are stable. Use the left rail to drill in."
    }
    return language == .simplifiedChinese
        ? "优先看风险、单边记忆和用户导入能力，官方基线暂时放低优先级。"
        : "Prioritize risks, one-sided memories, and user-imported skills; keep official baselines lower priority."
}

private func contextMixTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "上下文构成" : "Context Mix"
}

private func contextMixSubtitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "只看会影响 agent 行为的核心域。" : "Only the core domains that change agent behavior."
}

private func contextMixCountAxis(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "数量" : "Count"
}

private func contextMixDomainAxis(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "域" : "Domain"
}

private func priorityBriefTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "优先处理队列" : "Priority Queue"
}

private func priorityBriefSubtitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "按影响排序，只保留会改变下一步操作的信号。" : "Ranked by impact, keeping only signals that should change your next action."
}

private func memorySyncTileTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "单边记忆" : "One-sided Memories"
}

private func memorySyncTileDetail(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    switch language {
    case .english:
        "\(snapshot.bothSidesMemoryCount) aligned across both tools; decide whether the one-sided files should migrate."
    case .simplifiedChinese:
        "\(snapshot.bothSidesMemoryCount) 条已经两边都有；单边项需要决定是否迁移。"
    }
}

private func memorySyncPriorityLabel(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    if snapshot.oneSidedMemoryCount == 0 {
        return language == .simplifiedChinese ? "已对齐" : "Aligned"
    }
    return language == .simplifiedChinese ? "可迁移" : "Migration"
}

private func userCapabilityTileTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "用户能力组" : "User Skill Groups"
}

private func userCapabilityTileDetail(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    switch language {
    case .english:
        "\(snapshot.officialCapabilityGroups) official groups are baseline; focus on user-imported skill groups first."
    case .simplifiedChinese:
        "\(snapshot.officialCapabilityGroups) 个官方组只是基线，优先看用户导入的能力组。"
    }
}

private func userCapabilityPriorityLabel(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "用户导入" : "User"
}

private func radarTileTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "触发冲突" : "Trigger Conflicts"
}

private func radarTileDetail(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    switch language {
    case .english:
        "\(snapshot.highConflictCount) high-priority conflicts inside \(snapshot.triggerConflictCount) total trigger overlaps."
    case .simplifiedChinese:
        "\(snapshot.triggerConflictCount) 个触发重叠，其中 \(snapshot.highConflictCount) 个高优先级。"
    }
}

private func radarPriorityLabel(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    if snapshot.highConflictCount > 0 {
        return language == .simplifiedChinese ? "高优先级" : "High"
    }
    if snapshot.triggerConflictCount > 0 {
        return language == .simplifiedChinese ? "待确认" : "Review"
    }
    return language == .simplifiedChinese ? "稳定" : "Stable"
}

private func aiCoverageTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "AI 摘要覆盖" : "AI Coverage"
}

private func aiCoverageDetail(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    switch language {
    case .english:
        "\(snapshot.aiCoverage.explained) explained, \(snapshot.aiCoverage.missing) missing; useful when triaging unfamiliar files."
    case .simplifiedChinese:
        "\(snapshot.aiCoverage.explained) 已解释，\(snapshot.aiCoverage.missing) 未覆盖；适合排查陌生文件时补齐。"
    }
}

private func aiCoveragePriorityLabel(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    if snapshot.aiCoverage.missing == 0 {
        return language == .simplifiedChinese ? "已覆盖" : "Covered"
    }
    return language == .simplifiedChinese ? "低优先级" : "Low"
}

private func nextActionTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "下一步最该处理" : "Next Best Actions"
}

private func nextActionSubtitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "这里不列全量问题，只保留最值得先点开的信号。" : "Not every issue; only the signals worth opening first."
}

private func stableTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "没有高优先级风险" : "No high-priority risk"
}

private func stableDetail(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "继续按记忆、能力或 MCP 分类深入即可。" : "Drill into memories, capabilities, or MCP when needed."
}

private func surfaceBalanceTitle(language: AppLanguage) -> String {
    language == .simplifiedChinese ? "工具域覆盖" : "Surface Coverage"
}
