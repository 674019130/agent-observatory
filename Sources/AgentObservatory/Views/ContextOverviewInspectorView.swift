import AgentObservatoryCore
import Charts
import SwiftUI

struct ContextOverviewInspectorView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var animateIn = false
    @State private var selectedWeightItemID: ContextWeightItem.ID?
    @State private var hoveredWeightItemID: ContextWeightItem.ID?

    private var snapshot: ContextOverviewSnapshot {
        ContextOverviewSnapshot(store: store)
    }

    var body: some View {
        ContextWeightRankingExperience(
            snapshot: snapshot,
            selectedItemID: $selectedWeightItemID,
            hoveredItemID: $hoveredWeightItemID,
            animateIn: animateIn
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(contextWeightTitle(language: store.appLanguage))
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) {
                animateIn = true
            }
        }
        .onChange(of: snapshot.signature) { _, _ in
            selectedWeightItemID = nil
            hoveredWeightItemID = nil
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
    let promptPreviews: [SystemPromptPreview]
    let promptMaterialCount: Int
    let registryItemCount: Int
    let estimatedTokenCount: Int
    let rankedContextFiles: [ContextWeightItem]
    let rankedContextSections: [ContextWeightSection]
    let rankedTokenTotal: Int

    @MainActor init(store: AssetStore) {
        let catalog = store.contextCatalog
        let memoryGroups = MemoryMigrationPlanner().groups(items: catalog.memoryItems)
        let capabilitySections = ContextCapabilityGrouper().sections(items: catalog.capabilityItems)
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let memoryItems = catalog.memoryItems.filter { query.isEmpty || $0.asset.matchesSearch(query: query) }
        let capabilityItems = store.visibleCapabilityItems.filter { query.isEmpty || $0.asset.matchesSearch(query: query) }
        let promptCatalog = ContextCatalog(
            memoryItems: memoryItems,
            capabilityItems: capabilityItems,
            assemblySteps: []
        )
        let previewBuilder = SystemPromptPreviewBuilder()
        let previews = [AgentOwner.claude, .codex].map { surface in
            previewBuilder.preview(
                surface: surface,
                catalog: promptCatalog,
                visibleCapabilityItems: capabilityItems
            )
        }

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
        promptPreviews = previews
        promptMaterialCount = previews.reduce(0) { $0 + $1.promptMaterialItemCount }
        registryItemCount = previews.reduce(0) { $0 + $1.registryItemCount }
        estimatedTokenCount = previews.reduce(0) { $0 + $1.estimatedTokenCount }
        let rankedFiles = contextWeightItems(from: memoryItems + capabilityItems)
        rankedContextFiles = rankedFiles
        rankedContextSections = contextWeightSections(from: rankedFiles)
        rankedTokenTotal = max(1, rankedFiles.reduce(0) { $0 + $1.tokenCount })
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
            Int(aiCoverage.ratio * 100),
            promptMaterialCount,
            registryItemCount,
            estimatedTokenCount,
            rankedTokenTotal,
            rankedContextFiles.first?.tokenCount ?? 0,
            rankedContextSections.first?.tokenTotal ?? 0
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

private struct ContextWeightItem: Identifiable {
    let id: String
    let asset: AgentAsset
    let tokenCount: Int
    let destinations: [ContextLoadDestination]
    let layers: [AgentContextLayer]
    let surfaces: [AgentOwner]
    let roles: [AgentContextRole]

    var isPromptMaterial: Bool {
        destinations.contains(where: \.isPromptMaterial)
    }
}

private struct ContextWeightSection: Identifiable {
    var id: AgentOwner { owner }
    let owner: AgentOwner
    let items: [ContextWeightItem]
    let tokenTotal: Int
}

private struct ContextWeightRankingExperience: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    @Binding var selectedItemID: ContextWeightItem.ID?
    @Binding var hoveredItemID: ContextWeightItem.ID?
    let animateIn: Bool

    private var activeItem: ContextWeightItem? {
        let activeID = hoveredItemID ?? selectedItemID
        if let activeID,
           let item = snapshot.rankedContextFiles.first(where: { $0.id == activeID }) {
            return item
        }
        return snapshot.rankedContextFiles.first
    }

    private var activeOwnerTokenTotal: Int {
        guard let activeItem else { return snapshot.rankedTokenTotal }
        return snapshot.rankedContextSections.first { $0.owner == activeItem.asset.owner }?.tokenTotal ?? snapshot.rankedTokenTotal
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ContextWeightHero(snapshot: snapshot, animateIn: animateIn)

                    ContextWeightRankingList(
                        sections: snapshot.rankedContextSections,
                        totalTokenCount: snapshot.rankedTokenTotal,
                        selectedItemID: $selectedItemID,
                        hoveredItemID: $hoveredItemID
                    )
                    .frame(minWidth: 560)

                    ContextWeightActionStrip(snapshot: snapshot)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ContextWeightDetailPanel(
                item: activeItem,
                ownerTokenCount: activeOwnerTokenTotal,
                totalTokenCount: snapshot.rankedTokenTotal
            )
            .frame(width: 360)
            .padding(.leading, 16)
            .padding(.trailing, 22)
            .padding(.vertical, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct ContextWeightHero: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    let animateIn: Bool

    private var topShare: Double {
        guard let top = snapshot.rankedContextFiles.first else { return 0 }
        return Double(top.tokenCount) / Double(max(1, snapshot.rankedTokenTotal))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                Image(systemName: "list.number")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(contextWeightTitle(language: store.appLanguage))
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                Text(contextWeightBriefSubtitle(language: store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                ContextWeightMetric(
                    title: contextWeightText("Top", "最大", language: store.appLanguage),
                    value: contextWeightPercent(topShare),
                    systemImage: "chart.pie",
                    tint: .blue
                )
                ContextWeightMetric(
                    title: contextWeightText("Apps", "应用", language: store.appLanguage),
                    value: "\(snapshot.rankedContextSections.count)",
                    systemImage: "rectangle.3.group",
                    tint: .teal
                )
                ContextWeightMetric(
                    title: "Token",
                    value: contextWeightCompactNumber(snapshot.rankedTokenTotal),
                    systemImage: "number",
                    tint: .secondary
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35))
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
    }
}

private struct ContextWeightMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 13)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ContextWeightRankingList: View {
    @EnvironmentObject private var store: AssetStore
    let sections: [ContextWeightSection]
    let totalTokenCount: Int
    @Binding var selectedItemID: ContextWeightItem.ID?
    @Binding var hoveredItemID: ContextWeightItem.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(contextWeightText("Largest files by application", "按应用查看最大文件", language: store.appLanguage))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(contextWeightText("\(sections.count) apps", "\(sections.count) 个应用", language: store.appLanguage))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if sections.isEmpty {
                EmptyStateView(
                    title: contextWeightText("No context files", "暂无上下文文件", language: store.appLanguage),
                    message: contextWeightText("Refresh the index or enable more sources.", "刷新索引或启用更多来源。", language: store.appLanguage),
                    systemImage: "tray"
                )
                .frame(minHeight: 320)
            } else {
                VStack(spacing: 12) {
                    ForEach(sections) { section in
                        ContextWeightSectionBlock(
                            section: section,
                            totalTokenCount: totalTokenCount,
                            selectedItemID: $selectedItemID,
                            hoveredItemID: $hoveredItemID
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38))
        }
    }
}

private struct ContextWeightSectionBlock: View {
    @EnvironmentObject private var store: AssetStore
    let section: ContextWeightSection
    let totalTokenCount: Int
    @Binding var selectedItemID: ContextWeightItem.ID?
    @Binding var hoveredItemID: ContextWeightItem.ID?

    private var visibleItems: [ContextWeightItem] {
        Array(section.items.prefix(5))
    }

    private var remainingCount: Int {
        max(0, section.items.count - visibleItems.count)
    }

    private var ownerShare: Double {
        Double(section.tokenTotal) / Double(max(1, totalTokenCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 9) {
                Image(systemName: contextWeightOwnerIcon(section.owner))
                    .foregroundStyle(ownerTint(section.owner))
                    .frame(width: 22)
                Text(L10n.agentOwner(section.owner, language: store.appLanguage))
                    .font(.callout.weight(.semibold))
                CountBadge(count: section.items.count, tint: ownerTint(section.owner))
                Spacer()
                Text(contextWeightPercent(ownerShare))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(contextWeightCompactNumber(section.tokenTotal))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(nsColor: .separatorColor).opacity(0.16))
                    Capsule()
                        .fill(ownerTint(section.owner).gradient)
                        .frame(width: max(4, proxy.size.width * CGFloat(max(0.01, min(1, ownerShare)))))
                }
            }
            .frame(height: 5)

            VStack(spacing: 7) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    ContextWeightRow(
                        rank: index + 1,
                        item: item,
                        share: Double(item.tokenCount) / Double(max(1, section.tokenTotal)),
                        isSelected: selectedItemID == item.id,
                        isHovered: hoveredItemID == item.id
                    ) {
                        selectedItemID = selectedItemID == item.id ? nil : item.id
                    }
                    .onHover { hovering in
                        hoveredItemID = hovering ? item.id : nil
                    }
                }

                if remainingCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis")
                        Text(contextWeightText(
                            "\(remainingCount) smaller files in this application are hidden.",
                            "此应用还有 \(remainingCount) 个更小的文件未展示。",
                            language: store.appLanguage
                        ))
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                }
            }
        }
        .padding(12)
        .background(ownerTint(section.owner).opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ownerTint(section.owner).opacity(0.16))
        }
    }
}

private struct ContextWeightRow: View {
    @EnvironmentObject private var store: AssetStore
    let rank: Int
    let item: ContextWeightItem
    let share: Double
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    private var tint: Color {
        contextWeightTint(for: item)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 12) {
                    Text("\(rank)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .frame(width: 24, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(item.asset.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            BadgeView(text: L10n.assetKind(item.asset.kind, language: store.appLanguage), tint: tint)
                            if item.isPromptMaterial {
                                BadgeView(text: "Prompt", tint: .blue)
                            }
                        }

                        Text(item.asset.displayPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(contextWeightPercent(share))
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                        Text(contextWeightCompactNumber(item.tokenCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .frame(width: 62, alignment: .trailing)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(nsColor: .separatorColor).opacity(0.22))
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: max(4, proxy.size.width * CGFloat(max(0.01, min(1, share)))))
                    }
                }
                .frame(height: 6)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((isSelected || isHovered ? tint : Color(nsColor: .separatorColor)).opacity(isSelected ? 0.72 : 0.34), lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(isSelected || isHovered ? 0.10 : 0.035), radius: isSelected || isHovered ? 10 : 4, y: isSelected || isHovered ? 6 : 2)
        }
        .buttonStyle(.plain)
    }
}

private struct ContextWeightDetailPanel: View {
    @EnvironmentObject private var store: AssetStore
    let item: ContextWeightItem?
    let ownerTokenCount: Int
    let totalTokenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(.blue)
                Text(contextWeightText("File detail", "文件详情", language: store.appLanguage))
                    .font(.headline)
                Spacer()
            }

            if let item {
                let ownerShare = Double(item.tokenCount) / Double(max(1, ownerTokenCount))
                let globalShare = Double(item.tokenCount) / Double(max(1, totalTokenCount))

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.asset.title)
                            .font(.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            BadgeView(text: L10n.agentOwner(item.asset.owner, language: store.appLanguage), tint: ownerTint(item.asset.owner))
                            BadgeView(text: L10n.assetKind(item.asset.kind, language: store.appLanguage), tint: contextWeightTint(for: item))
                            BadgeView(text: contextWeightPercent(ownerShare), tint: .blue)
                        }

                        PathPreviewLink(
                            path: item.asset.path,
                            font: .caption.monospaced(),
                            foregroundColor: .secondary,
                            lineLimit: 1,
                            language: store.appLanguage
                        )

                        Divider()

                        ContextWeightDetailMetric(label: "Token", value: contextWeightCompactNumber(item.tokenCount))
                        ContextWeightDetailMetric(
                            label: contextWeightText("In app", "应用内占比", language: store.appLanguage),
                            value: contextWeightPercent(ownerShare)
                        )
                        ContextWeightDetailMetric(
                            label: contextWeightText("Global", "全局占比", language: store.appLanguage),
                            value: contextWeightPercent(globalShare)
                        )
                        ContextWeightDetailMetric(
                            label: contextWeightText("Placement", "位置", language: store.appLanguage),
                            value: contextWeightPlacementText(item, language: store.appLanguage)
                        )

                        if !item.asset.summary.isEmpty {
                            Divider()
                            Text(item.asset.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !item.asset.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            Text(contextWeightPreview(item.asset.preview))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            store.focusContextAsset(path: item.asset.path)
                        } label: {
                            Label(contextWeightText("Open asset detail", "打开资产详情", language: store.appLanguage), systemImage: "arrow.right.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.trailing, 2)
                }
            } else {
                Text(contextWeightText(
                    "Select a row to inspect why it takes context space.",
                    "选择一行，查看它为什么占上下文空间。",
                    language: store.appLanguage
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38))
        }
    }
}

private struct ContextWeightDetailMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ContextWeightActionStrip: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            PromptStackActionButton(
                title: contextWeightText("Prompt Preview", "Prompt 预览", language: store.appLanguage),
                detail: contextWeightText("map / copy / zoom", "地图 / 复制 / 缩放", language: store.appLanguage),
                systemImage: "doc.text.magnifyingglass",
                tint: .blue
            ) {
                store.showSystemPromptPreview()
            }

            PromptStackActionButton(
                title: contextWeightText("One-sided Memory", "单边记忆", language: store.appLanguage),
                detail: "\(snapshot.oneSidedMemoryCount)",
                systemImage: "arrow.left.arrow.right",
                tint: snapshot.oneSidedMemoryCount > 0 ? .orange : .green
            ) {
                store.showMemories()
            }

            PromptStackActionButton(
                title: contextWeightText("User Skills", "用户 Skill", language: store.appLanguage),
                detail: "\(snapshot.userCapabilityGroups)",
                systemImage: "wand.and.stars",
                tint: .teal
            ) {
                store.showCapabilities()
            }

            PromptStackActionButton(
                title: contextWeightText("LLM Export", "LLM 导出", language: store.appLanguage),
                detail: "Markdown",
                systemImage: "square.and.arrow.up",
                tint: .purple
            ) {
                store.presentLLMContextPack(.currentView)
            }
        }
    }
}

private struct PromptStackLayer: Identifiable {
    let id: String
    let surface: AgentOwner
    let section: SystemPromptPreviewSection
    let title: String
    let subtitle: String
    let routeDescription: String
    let tint: Color
    let systemImage: String

    var itemCount: Int { section.items.count }
    var tokenCount: Int { section.estimatedTokenCount }
    var isPromptMaterial: Bool { section.isPromptMaterial }
    var firstPath: String? { section.items.first?.asset.path }
}

private struct PromptStackExperience: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    @Binding var selectedLayerID: PromptStackLayer.ID?
    @Binding var hoveredLayerID: PromptStackLayer.ID?
    let animateIn: Bool

    private var allLayers: [PromptStackLayer] {
        snapshot.promptPreviews.flatMap { promptStackLayers(for: $0, language: store.appLanguage) }
    }

    private var activeLayer: PromptStackLayer? {
        let activeID = hoveredLayerID ?? selectedLayerID
        guard let activeID else { return allLayers.first }
        return allLayers.first { $0.id == activeID } ?? allLayers.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PromptStackHero(snapshot: snapshot, animateIn: animateIn)

            HStack(alignment: .top, spacing: 18) {
                PromptStackWorkbench(
                    snapshot: snapshot,
                    selectedLayerID: $selectedLayerID,
                    hoveredLayerID: $hoveredLayerID,
                    animateIn: animateIn
                )
                .frame(minWidth: 560)

                PromptStackLayerInspector(
                    layer: activeLayer,
                    lockedLayerID: selectedLayerID,
                    snapshot: snapshot
                )
                .frame(width: 340)
            }

            PromptStackActionStrip(snapshot: snapshot)
        }
    }
}

private struct PromptStackHero: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    let animateIn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.linearGradient(
                        colors: [
                            Color.blue.opacity(0.18),
                            Color.indigo.opacity(0.11),
                            Color.orange.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text(promptStackTitle(language: store.appLanguage))
                    .font(.title2.weight(.semibold))
                Text(promptStackSubtitle(snapshot: snapshot, language: store.appLanguage))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)

            HStack(spacing: 8) {
                PromptStackMetric(
                    title: promptStackText("Prompt", "提示词", language: store.appLanguage),
                    value: snapshot.promptMaterialCount,
                    systemImage: "text.alignleft",
                    tint: .blue
                )
                PromptStackMetric(
                    title: promptStackText("Registry", "注册表", language: store.appLanguage),
                    value: snapshot.registryItemCount,
                    systemImage: "list.bullet.rectangle",
                    tint: .orange
                )
                PromptStackMetric(
                    title: "Token",
                    value: snapshot.estimatedTokenCount,
                    systemImage: "number",
                    tint: .secondary
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35))
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
    }
}

private struct PromptStackMetric: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.caption2.weight(.medium))

            Text(promptStackCompactNumber(value))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(minWidth: 92, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PromptStackWorkbench: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot
    @Binding var selectedLayerID: PromptStackLayer.ID?
    @Binding var hoveredLayerID: PromptStackLayer.ID?
    let animateIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(promptStackText("Live prompt stack", "实时 Prompt 堆栈", language: store.appLanguage))
                    .font(.headline)
                Text(promptStackText("click to pin a layer", "点击锁定一层", language: store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(snapshot.promptPreviews, id: \.surface) { preview in
                    PromptStackColumn(
                        preview: preview,
                        selectedLayerID: $selectedLayerID,
                        hoveredLayerID: $hoveredLayerID,
                        animateIn: animateIn
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38))
        }
    }
}

private struct PromptStackColumn: View {
    @EnvironmentObject private var store: AssetStore
    let preview: SystemPromptPreview
    @Binding var selectedLayerID: PromptStackLayer.ID?
    @Binding var hoveredLayerID: PromptStackLayer.ID?
    let animateIn: Bool

    private var layers: [PromptStackLayer] {
        promptStackLayers(for: preview, language: store.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: promptStackSurfaceIcon(preview.surface))
                    .foregroundStyle(ownerTint(preview.surface))
                    .frame(width: 22)
                Text(promptStackSurfaceTitle(preview.surface, language: store.appLanguage))
                    .font(.headline)
                CountBadge(count: preview.totalItemCount, tint: ownerTint(preview.surface))
                Spacer()
            }

            if layers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(promptStackText("No visible context", "没有可见上下文", language: store.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                VStack(spacing: -8) {
                    ForEach(Array(layers.prefix(9).enumerated()), id: \.element.id) { index, layer in
                        PromptStackPlate(
                            layer: layer,
                            depth: index,
                            isSelected: selectedLayerID == layer.id,
                            isHovered: hoveredLayerID == layer.id,
                            animateIn: animateIn
                        ) {
                            selectedLayerID = selectedLayerID == layer.id ? nil : layer.id
                        }
                        .onHover { hovering in
                            hoveredLayerID = hovering ? layer.id : nil
                        }
                    }

                    if layers.count > 9 {
                        PromptStackOverflowRow(
                            hiddenCount: layers.count - 9,
                            language: store.appLanguage
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ownerTint(preview.surface).opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ownerTint(preview.surface).opacity(0.18))
        }
    }
}

private struct PromptStackPlate: View {
    let layer: PromptStackLayer
    let depth: Int
    let isSelected: Bool
    let isHovered: Bool
    let animateIn: Bool
    let action: () -> Void

    private var lift: CGFloat {
        isSelected || isHovered ? -3 : 0
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 11) {
                Image(systemName: layer.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(layer.tint)
                    .frame(width: 28, height: 28)
                    .background(layer.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(layer.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if layer.isPromptMaterial {
                            BadgeView(text: "prompt", tint: .blue)
                        }
                    }

                    Text(layer.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(layer.itemCount)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Text(promptStackCompactNumber(layer.tokenCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke((isSelected || isHovered ? layer.tint : Color(nsColor: .separatorColor)).opacity(isSelected ? 0.72 : 0.34), lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(isSelected || isHovered ? 0.13 : 0.055), radius: isSelected || isHovered ? 12 : 6, y: isSelected || isHovered ? 7 : 3)
            .offset(x: CGFloat(depth % 3) * 5, y: lift)
            .scaleEffect(animateIn ? 1 : 0.985, anchor: .top)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut(duration: 0.22), value: isSelected)
            .animation(.easeOut(duration: 0.16), value: isHovered)
        }
        .buttonStyle(.plain)
    }
}

private struct PromptStackOverflowRow: View {
    let hiddenCount: Int
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
            Text(promptStackText("+ \(hiddenCount) more layers in full preview", "+ \(hiddenCount) 层在完整预览中", language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PromptStackLayerInspector: View {
    @EnvironmentObject private var store: AssetStore
    let layer: PromptStackLayer?
    let lockedLayerID: PromptStackLayer.ID?
    let snapshot: ContextOverviewSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: lockedLayerID == nil ? "cursorarrow.rays" : "pin")
                    .foregroundStyle(.blue)
                Text(promptStackText("Layer detail", "层详情", language: store.appLanguage))
                    .font(.headline)
                Spacer()
            }

            if let layer {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: layer.systemImage)
                            .foregroundStyle(layer.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(layer.title)
                                .font(.callout.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(promptStackSurfaceTitle(layer.surface, language: store.appLanguage))
                                .font(.caption)
                                .foregroundStyle(ownerTint(layer.surface))
                        }
                    }

                    HStack(spacing: 8) {
                        BadgeView(
                            text: L10n.loadDestination(layer.section.destination, language: store.appLanguage),
                            tint: layer.tint
                        )
                        BadgeView(
                            text: layer.isPromptMaterial
                                ? promptStackText("enters prompt", "进入 Prompt", language: store.appLanguage)
                                : promptStackText("registry/support", "注册/支持", language: store.appLanguage),
                            tint: layer.isPromptMaterial ? .blue : .secondary
                        )
                    }

                    Text(layer.routeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    PromptStackInspectorMetricRow(
                        label: promptStackText("Items", "项目", language: store.appLanguage),
                        value: "\(layer.itemCount)"
                    )
                    PromptStackInspectorMetricRow(
                        label: "Token",
                        value: promptStackCompactNumber(layer.tokenCount)
                    )

                    if !layer.section.items.isEmpty {
                        Divider()
                        Text(promptStackText("Source samples", "来源样例", language: store.appLanguage))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(layer.section.items.prefix(4)) { item in
                            Button {
                                store.focusContextAsset(path: item.asset.path)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.asset.title)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    PathPreviewLink(
                                        path: item.asset.path,
                                        font: .caption2.monospaced(),
                                        foregroundColor: .secondary,
                                        language: store.appLanguage
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text(promptStackText(
                    "Hover or click a layer to inspect where it lands in the local prompt preview.",
                    "悬浮或点击一层，查看它会落到本地 Prompt 预览的哪里。",
                    language: store.appLanguage
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.38))
        }
    }
}

private struct PromptStackInspectorMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct PromptStackActionStrip: View {
    @EnvironmentObject private var store: AssetStore
    let snapshot: ContextOverviewSnapshot

    var body: some View {
        HStack(spacing: 10) {
            PromptStackActionButton(
                title: promptStackText("Open full prompt preview", "打开完整 Prompt 预览", language: store.appLanguage),
                detail: promptStackText("map, copy, zoom", "地图、复制、缩放", language: store.appLanguage),
                systemImage: "doc.text.magnifyingglass",
                tint: .blue
            ) {
                store.showSystemPromptPreview()
            }

            PromptStackActionButton(
                title: promptStackText("Review one-sided memories", "检查单边记忆", language: store.appLanguage),
                detail: "\(snapshot.oneSidedMemoryCount)",
                systemImage: "arrow.left.arrow.right",
                tint: snapshot.oneSidedMemoryCount > 0 ? .orange : .green
            ) {
                store.showMemories()
            }

            PromptStackActionButton(
                title: promptStackText("User skill groups", "用户 Skill 组", language: store.appLanguage),
                detail: "\(snapshot.userCapabilityGroups)",
                systemImage: "wand.and.stars",
                tint: .teal
            ) {
                store.showCapabilities()
            }
        }
    }
}

private struct PromptStackActionButton: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.16))
            }
        }
        .buttonStyle(.plain)
    }
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

private func contextWeightItems(from items: [ContextCatalogItem]) -> [ContextWeightItem] {
    var grouped: [String: [ContextCatalogItem]] = [:]
    for item in items {
        grouped[item.asset.path, default: []].append(item)
    }

    return grouped.values.compactMap { groupedItems in
        guard let first = groupedItems.first else { return nil }
        let destinations = contextWeightUnique(groupedItems.map(\.loadRoute.destination)) {
            contextWeightDestinationSortIndex($0) < contextWeightDestinationSortIndex($1)
        }
        let layers = contextWeightUnique(groupedItems.map(\.layer)) {
            $0.sortIndex < $1.sortIndex
        }
        let surfaces = contextWeightUnique(groupedItems.flatMap(\.surfaces)) {
            $0.rawValue < $1.rawValue
        }
        let roles = contextWeightUnique(groupedItems.map(\.role)) {
            contextWeightRoleSortIndex($0) < contextWeightRoleSortIndex($1)
        }

        return ContextWeightItem(
            id: first.asset.path,
            asset: first.asset,
            tokenCount: contextWeightEstimatedTokens(for: first.asset),
            destinations: destinations,
            layers: layers,
            surfaces: surfaces,
            roles: roles
        )
    }
    .sorted { left, right in
        if left.tokenCount != right.tokenCount {
            return left.tokenCount > right.tokenCount
        }
        return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
    }
}

private func contextWeightSections(from items: [ContextWeightItem]) -> [ContextWeightSection] {
    Dictionary(grouping: items, by: { $0.asset.owner })
        .map { owner, ownerItems in
            let sortedItems = ownerItems.sorted { left, right in
                if left.tokenCount != right.tokenCount {
                    return left.tokenCount > right.tokenCount
                }
                return left.asset.displayPath.localizedStandardCompare(right.asset.displayPath) == .orderedAscending
            }

            return ContextWeightSection(
                owner: owner,
                items: sortedItems,
                tokenTotal: sortedItems.reduce(0) { $0 + $1.tokenCount }
            )
        }
        .sorted { left, right in
            let leftIndex = contextWeightOwnerSortIndex(left.owner)
            let rightIndex = contextWeightOwnerSortIndex(right.owner)
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            if left.tokenTotal != right.tokenTotal {
                return left.tokenTotal > right.tokenTotal
            }
            return left.owner.rawValue < right.owner.rawValue
        }
}

private func contextWeightUnique<T: Hashable>(_ values: [T], sortedBy: (T, T) -> Bool) -> [T] {
    Array(Set(values)).sorted(by: sortedBy)
}

private func contextWeightEstimatedTokens(for asset: AgentAsset) -> Int {
    let text = [
        asset.title,
        asset.summary,
        asset.trigger ?? "",
        asset.preview
    ]
    .joined(separator: "\n")
    .trimmingCharacters(in: .whitespacesAndNewlines)

    return max(1, text.count / 4)
}

private func contextWeightRoleSortIndex(_ role: AgentContextRole) -> Int {
    switch role {
    case .memory:
        0
    case .capability:
        1
    }
}

private func contextWeightDestinationSortIndex(_ destination: ContextLoadDestination) -> Int {
    switch destination {
    case .systemPrompt:
        0
    case .memoryBlock:
        1
    case .projectContextBlock:
        2
    case .workspaceContextBlock:
        3
    case .pluginInstructionBlock:
        4
    case .skillRegistry:
        5
    case .commandRegistry:
        6
    case .toolRegistry:
        7
    case .pluginRegistry:
        8
    case .configuration:
        9
    case .sessionArchive:
        10
    case .supportFile:
        11
    case .indexOnly:
        12
    }
}

private func contextWeightOwnerSortIndex(_ owner: AgentOwner) -> Int {
    switch owner {
    case .claude:
        0
    case .codex:
        1
    case .agents:
        2
    case .project:
        3
    case .unknown:
        4
    }
}

private func contextWeightOwnerIcon(_ owner: AgentOwner) -> String {
    switch owner {
    case .claude:
        "terminal"
    case .codex:
        "cube.transparent"
    case .agents:
        "person.2.wave.2"
    case .project:
        "folder"
    case .unknown:
        "questionmark.folder"
    }
}

private func contextWeightTitle(language: AppLanguage) -> String {
    contextWeightText("Context Weight by App", "按应用查看上下文占比", language: language)
}

private func contextWeightSubtitle(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    if snapshot.rankedContextFiles.isEmpty {
        return contextWeightText(
            "Refresh the index to see which local files take the most prompt-preview space.",
            "刷新索引后，这里会显示哪些本地文件最占 Prompt 预览空间。",
            language: language
        )
    }

    let topTitle = snapshot.rankedContextFiles.first?.asset.title ?? ""
    return contextWeightText(
        "Grouped by app, then ranked by estimated token share so oversized memories, skills, and registries surface first.",
        "先按应用分组，再按估算 token 占比排序。当前全局第一名：\(topTitle)",
        language: language
    )
}

private func contextWeightBriefSubtitle(language: AppLanguage) -> String {
    contextWeightText(
        "Largest prompt files, grouped by app.",
        "按应用聚合最占 Prompt 的文件。",
        language: language
    )
}

private func contextWeightText(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
    switch language {
    case .english:
        english
    case .simplifiedChinese:
        simplifiedChinese
    }
}

private func contextWeightCompactNumber(_ value: Int) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", Double(value) / 1_000_000)
    }
    if value >= 10_000 {
        return String(format: "%.1fk", Double(value) / 1_000)
    }
    return "\(value)"
}

private func contextWeightPercent(_ value: Double) -> String {
    if value >= 0.995 {
        return "100%"
    }
    if value >= 0.1 {
        return "\(Int((value * 100).rounded()))%"
    }
    return String(format: "%.1f%%", value * 100)
}

private func contextWeightTint(for item: ContextWeightItem) -> Color {
    if item.isPromptMaterial {
        return .blue
    }
    if item.destinations.contains(.toolRegistry) {
        return .orange
    }
    if item.destinations.contains(.skillRegistry) {
        return .teal
    }
    return ownerTint(item.asset.owner)
}

private func contextWeightPlacementText(_ item: ContextWeightItem, language: AppLanguage) -> String {
    item.destinations
        .prefix(2)
        .map { L10n.loadDestination($0, language: language) }
        .joined(separator: " / ")
}

private func contextWeightPreview(_ preview: String) -> String {
    let text = preview.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count > 520 else { return text }
    return String(text.prefix(520)).trimmingCharacters(in: .whitespacesAndNewlines) + "\n..."
}

private func promptStackLayers(for preview: SystemPromptPreview, language: AppLanguage) -> [PromptStackLayer] {
    preview.sections.map { section in
        let route = promptStackRoute(for: section)
        return PromptStackLayer(
            id: "\(preview.surface.rawValue)-\(section.id)",
            surface: preview.surface,
            section: section,
            title: promptStackLayerTitle(section, language: language),
            subtitle: "\(L10n.contextLayer(section.layer, language: language)) · \(L10n.contextRole(section.role, language: language))",
            routeDescription: L10n.loadRouteDescription(route, language: language),
            tint: promptStackDestinationTint(section.destination),
            systemImage: promptStackDestinationIcon(section.destination)
        )
    }
}

private func promptStackRoute(for section: SystemPromptPreviewSection) -> ContextLoadRoute {
    ContextLoadRoute(
        role: section.role,
        layer: section.layer,
        surfaces: section.items.first?.surfaces ?? [],
        destination: section.destination,
        trigger: section.items.first?.loadRoute.trigger ?? .observatoryIndex,
        skillInstallOrigin: section.items.first?.loadRoute.skillInstallOrigin
    )
}

private func promptStackLayerTitle(_ section: SystemPromptPreviewSection, language: AppLanguage) -> String {
    if section.items.count == 1, let item = section.items.first {
        return item.asset.title
    }

    switch section.destination {
    case .systemPrompt:
        return promptStackText("Entry Instructions", "入口指令", language: language)
    case .memoryBlock:
        return promptStackText("Long-term Memory", "长期记忆", language: language)
    case .projectContextBlock:
        return promptStackText("Project Context", "项目上下文", language: language)
    case .workspaceContextBlock:
        return promptStackText("Workspace Context", "工作区上下文", language: language)
    case .pluginInstructionBlock:
        return promptStackText("Plugin Instructions", "插件指令", language: language)
    case .skillRegistry:
        return "Skill Registry"
    case .commandRegistry:
        return "Command Registry"
    case .toolRegistry:
        return "MCP Tools"
    case .pluginRegistry:
        return "Plugin Registry"
    case .configuration:
        return promptStackText("Configuration", "配置", language: language)
    case .sessionArchive:
        return promptStackText("Session Archive", "会话历史", language: language)
    case .supportFile:
        return promptStackText("Support Files", "支持文件", language: language)
    case .indexOnly:
        return promptStackText("Index-only", "仅索引", language: language)
    }
}

private func promptStackDestinationTint(_ destination: ContextLoadDestination) -> Color {
    switch destination {
    case .systemPrompt:
        .blue
    case .memoryBlock:
        .indigo
    case .projectContextBlock, .workspaceContextBlock:
        .teal
    case .pluginInstructionBlock, .pluginRegistry:
        .orange
    case .skillRegistry:
        .cyan
    case .commandRegistry:
        .pink
    case .toolRegistry:
        .orange
    case .configuration:
        .gray
    case .sessionArchive:
        .purple
    case .supportFile, .indexOnly:
        .secondary
    }
}

private func promptStackDestinationIcon(_ destination: ContextLoadDestination) -> String {
    switch destination {
    case .systemPrompt:
        "text.badge.checkmark"
    case .memoryBlock:
        "brain.head.profile"
    case .projectContextBlock:
        "folder"
    case .workspaceContextBlock:
        "square.grid.2x2"
    case .pluginInstructionBlock:
        "puzzlepiece.extension"
    case .skillRegistry:
        "wand.and.stars"
    case .commandRegistry:
        "terminal"
    case .toolRegistry:
        "point.3.connected.trianglepath.dotted"
    case .pluginRegistry:
        "shippingbox"
    case .configuration:
        "gearshape"
    case .sessionArchive:
        "clock.arrow.circlepath"
    case .supportFile:
        "doc.on.doc"
    case .indexOnly:
        "magnifyingglass"
    }
}

private func promptStackSurfaceTitle(_ surface: AgentOwner, language: AppLanguage) -> String {
    surface == .claude ? "Claude Code" : L10n.agentOwner(surface, language: language)
}

private func promptStackSurfaceIcon(_ surface: AgentOwner) -> String {
    switch surface {
    case .claude:
        "terminal"
    case .codex:
        "cube.transparent"
    case .agents:
        "person.2.wave.2"
    case .project:
        "folder"
    case .unknown:
        "questionmark.folder"
    }
}

private func promptStackTitle(language: AppLanguage) -> String {
    promptStackText("Prompt Stack", "Prompt 堆栈", language: language)
}

private func promptStackSubtitle(snapshot: ContextOverviewSnapshot, language: AppLanguage) -> String {
    if snapshot.promptMaterialCount == 0 && snapshot.registryItemCount == 0 {
        return promptStackText(
            "Refresh the index to build a local stack of files that can shape Claude Code and Codex behavior.",
            "刷新索引后，这里会把影响 Claude Code 和 Codex 行为的本地文件堆成可检查的调用栈。",
            language: language
        )
    }

    return promptStackText(
        "A debugger-style view of which local files become prompt material, registries, tools, or support context.",
        "像调试器一样看清哪些本地文件会成为提示词材料、注册表、工具或支持上下文。",
        language: language
    )
}

private func promptStackCompactNumber(_ value: Int) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", Double(value) / 1_000_000)
    }
    if value >= 10_000 {
        return String(format: "%.1fk", Double(value) / 1_000)
    }
    return "\(value)"
}

private func promptStackText(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
    switch language {
    case .english:
        english
    case .simplifiedChinese:
        simplifiedChinese
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
