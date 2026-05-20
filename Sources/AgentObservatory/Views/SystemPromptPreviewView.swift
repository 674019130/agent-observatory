import AgentObservatoryCore
import AppKit
import SwiftUI

private let promptHoverPanelSize = CGSize(width: 340, height: 260)

struct SystemPromptPreviewView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var surfaceMode: PromptSurfaceMode = .both
    @State private var hoveredNodeID: PromptMapNode.ID?
    @State private var pinnedNodeID: PromptMapNode.ID?
    @State private var viewportScale: CGFloat = 1
    @State private var viewportOffset: CGSize = .zero
    @State private var didCopy = false

    private let builder = SystemPromptPreviewBuilder()

    private var previews: [SystemPromptPreview] {
        [.codex, .claude].map { surface in
            promptPreview(for: surface, store: store)
        }
    }

    private var nodes: [PromptMapNode] {
        previews.flatMap { preview in
            promptNodes(for: preview, language: store.appLanguage)
        }
    }

    private var visibleNodes: [PromptMapNode] {
        nodes.filter { surfaceMode.surfaces.contains($0.surface) }
    }

    private var visiblePreviews: [SystemPromptPreview] {
        previews.filter { surfaceMode.surfaces.contains($0.surface) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PromptMapTopBar(
                surfaceMode: $surfaceMode,
                viewportScale: $viewportScale,
                viewportOffset: $viewportOffset,
                didCopy: didCopy,
                metrics: PromptMapMetrics(nodes: visibleNodes),
                copyAction: copyFullPreview
            )
            .onHover { hovering in
                if hovering {
                    hoveredNodeID = nil
                }
            }

            Divider()

            PromptContextMapCanvas(
                nodes: visibleNodes,
                surfaceMode: surfaceMode,
                hoveredNodeID: $hoveredNodeID,
                pinnedNodeID: $pinnedNodeID,
                viewportScale: $viewportScale,
                viewportOffset: $viewportOffset
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: surfaceMode) {
            hoveredNodeID = nil
            pinnedNodeID = nil
            viewportOffset = .zero
            viewportScale = 1
        }
        .onChange(of: viewportScale) {
            hoveredNodeID = nil
        }
        .onChange(of: viewportOffset) {
            hoveredNodeID = nil
        }
        .onChange(of: visibleNodes.map(\.id)) {
            hoveredNodeID = nil
            if let pinnedNodeID, !visibleNodes.contains(where: { $0.id == pinnedNodeID }) {
                self.pinnedNodeID = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            hoveredNodeID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            hoveredNodeID = nil
        }
        .onDisappear {
            hoveredNodeID = nil
            pinnedNodeID = nil
        }
    }

    private func copyFullPreview() {
        let markdown = visiblePreviews
            .map { builder.markdown(for: $0, language: store.appLanguage) }
            .joined(separator: "\n\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)

        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            didCopy = false
        }
    }
}

private enum PromptSurfaceMode: String, CaseIterable, Identifiable {
    case both
    case codex
    case claude

    var id: String { rawValue }

    var surfaces: [AgentOwner] {
        switch self {
        case .both:
            [.codex, .claude]
        case .codex:
            [.codex]
        case .claude:
            [.claude]
        }
    }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.both, .simplifiedChinese): "Both"
        case (.codex, .simplifiedChinese): "Codex"
        case (.claude, .simplifiedChinese): "Claude Code"
        case (.both, _): "Both"
        case (.codex, _): "Codex"
        case (.claude, _): "Claude Code"
        }
    }
}

private struct PromptMapNode: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let surface: AgentOwner
    let role: AgentContextRole
    let layer: AgentContextLayer
    let destination: ContextLoadDestination
    let items: [ContextCatalogItem]
    let tokenCount: Int

    var itemCount: Int { items.count }
    var isPromptMaterial: Bool { destination.isPromptMaterial }
    var firstAsset: AgentAsset? { items.first?.asset }

    var previewExcerpt: String {
        let preview = items.first?.asset.preview.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !preview.isEmpty else { return "" }
        if preview.count <= 220 { return preview }
        return String(preview.prefix(220)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private struct PromptMapMetrics {
    let promptCount: Int
    let registryCount: Int
    let tokenCount: Int
    let itemCount: Int

    init(nodes: [PromptMapNode]) {
        promptCount = nodes.filter(\.isPromptMaterial).reduce(0) { $0 + $1.itemCount }
        registryCount = nodes.filter { !$0.isPromptMaterial }.reduce(0) { $0 + $1.itemCount }
        tokenCount = nodes.reduce(0) { $0 + $1.tokenCount }
        itemCount = nodes.reduce(0) { $0 + $1.itemCount }
    }
}

private struct PromptMapTopBar: View {
    @EnvironmentObject private var store: AssetStore
    @Binding var surfaceMode: PromptSurfaceMode
    @Binding var viewportScale: CGFloat
    @Binding var viewportOffset: CGSize
    let didCopy: Bool
    let metrics: PromptMapMetrics
    let copyAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "text.badge.checkmark")
                        .foregroundStyle(.blue)
                    Text(promptText("System Prompt Map", "System Prompt 地图", language: store.appLanguage))
                        .font(.title2.weight(.semibold))
                }

                Text(promptText(
                    "A local, inspectable prompt terrain for memory, instructions, skills, MCP, and plugin context.",
                    "把记忆、入口指令、Skill、MCP 和插件上下文渲染成可检查的本地提示词地形。",
                    language: store.appLanguage
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Picker("", selection: $surfaceMode) {
                ForEach(PromptSurfaceMode.allCases) { mode in
                    Text(mode.title(language: store.appLanguage)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)

            PromptTopMetric(label: promptText("Prompt", "提示词", language: store.appLanguage), value: metrics.promptCount, tint: .blue)
            PromptTopMetric(label: promptText("Registry", "注册表", language: store.appLanguage), value: metrics.registryCount, tint: .orange)
            PromptTopMetric(label: "Token", value: metrics.tokenCount, tint: .secondary)

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Button {
                    viewportScale = max(0.68, viewportScale - 0.12)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .compactHitTarget()
                }
                .buttonStyle(.plain)
                .help(promptText("Zoom out", "缩小", language: store.appLanguage))

                Button {
                    viewportScale = 1
                    viewportOffset = .zero
                } label: {
                    Text("\(Int(viewportScale * 100))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .frame(width: 46)
                        .compactHitTarget()
                }
                .buttonStyle(.plain)
                .help(promptText("Reset view", "重置视图", language: store.appLanguage))

                Button {
                    viewportScale = min(1.65, viewportScale + 0.12)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .compactHitTarget()
                }
                .buttonStyle(.plain)
                .help(promptText("Zoom in", "放大", language: store.appLanguage))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: copyAction) {
                Label(
                    didCopy ? promptText("Copied", "已复制", language: store.appLanguage) : promptText("Copy", "复制", language: store.appLanguage),
                    systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}

private struct PromptTopMetric: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct PromptContextMapCanvas: View {
    @EnvironmentObject private var store: AssetStore
    let nodes: [PromptMapNode]
    let surfaceMode: PromptSurfaceMode
    @Binding var hoveredNodeID: PromptMapNode.ID?
    @Binding var pinnedNodeID: PromptMapNode.ID?
    @Binding var viewportScale: CGFloat
    @Binding var viewportOffset: CGSize
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    private var effectiveScale: CGFloat {
        min(1.8, max(0.62, viewportScale * pinchScale))
    }

    private var effectiveOffset: CGSize {
        CGSize(
            width: viewportOffset.width + dragTranslation.width,
            height: viewportOffset.height + dragTranslation.height
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clusters = promptClusters(
                nodes: nodes,
                surfaceMode: surfaceMode,
                size: size,
                language: store.appLanguage
            )
            let transformedClusters = transformPromptClusters(
                clusters,
                size: size,
                scale: effectiveScale,
                offset: effectiveOffset
            )
            let pinnedNode = nodes.first { $0.id == pinnedNodeID }
            let legendFrame = promptLegendExclusionFrame(in: size)
            let pinnedPanelWidth = pinnedNode.map { _ in promptPinnedPanelWidth(in: size) }
            let pinnedPanelFrame = pinnedPanelWidth.map { promptPinnedPanelFrame(in: size, panelWidth: $0) }
            let hoveredLayout = transformedClusters
                .flatMap(\.layouts)
                .first { $0.node.id == hoveredNodeID }
            let hoverPreviewLayout = pinnedNode == nil ? hoveredLayout : nil
            let hoverPanelFrame = hoverPreviewLayout.map {
                promptHoverPanelFrame(
                    avoiding: $0.rect,
                    in: size,
                    panelSize: promptHoverPanelSize,
                    excluding: [legendFrame, pinnedPanelFrame].compactMap { $0 }
                )
            }
            let interactionExclusionFrames = [
                hoverPanelFrame,
                legendFrame,
                pinnedPanelFrame
            ].compactMap { $0 }

            ZStack(alignment: .topLeading) {
                PromptMapGrid(scale: effectiveScale, offset: effectiveOffset)

                if nodes.isEmpty {
                    EmptyStateView(
                        title: promptText("No prompt terrain yet", "暂无提示词地形", language: store.appLanguage),
                        message: promptText(
                            "Refresh the index or broaden the current search to render local prompt material.",
                            "刷新索引，或放宽当前搜索条件，即可渲染本地提示词材料。",
                            language: store.appLanguage
                        ),
                        systemImage: "square.stack.3d.up.slash"
                    )
                } else {
                    ZStack(alignment: .topLeading) {
                        ForEach(transformedClusters) { cluster in
                            PromptClusterBoundary(cluster: cluster)

                            ForEach(cluster.layouts) { layout in
                                PromptMapTile(
                                    layout: layout,
                                    isHovered: hoveredNodeID == layout.node.id,
                                    isPinned: pinnedNodeID == layout.node.id,
                                    isDimmed: pinnedNodeID == nil && hoveredNodeID != nil && hoveredNodeID != layout.node.id
                                )
                                .position(x: layout.rect.midX, y: layout.rect.midY)
                            }
                        }
                    }
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .animation(.easeOut(duration: 0.16), value: hoveredNodeID)
                    .animation(.easeOut(duration: 0.18), value: pinnedNodeID)
                }

                PromptMapLegend()
                    .frame(maxWidth: 620)
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                if let hoverPreviewLayout, let hoverPanelFrame {
                    PromptNodeHoverCard(node: hoverPreviewLayout.node)
                        .frame(width: promptHoverPanelSize.width, height: promptHoverPanelSize.height, alignment: .topLeading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(promptNodeTint(hoverPreviewLayout.node).opacity(0.26))
                        }
                        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 12)
                        .position(x: hoverPanelFrame.midX, y: hoverPanelFrame.midY)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(90)
                }

                if let pinnedNode {
                    PromptPinnedNodePanel(node: pinnedNode) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            hoveredNodeID = nil
                            pinnedNodeID = nil
                        }
                    }
                    .frame(width: pinnedPanelWidth ?? promptPinnedPanelWidth(in: size))
                    .padding(18)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onHover { hovering in
                if !hovering {
                    clearHover()
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredNodeID = promptHoveredNodeID(
                        at: location,
                        in: transformedClusters,
                        excluding: interactionExclusionFrames
                    )
                case .ended:
                    clearHover()
                }
            }
            .onDisappear {
                clearHover()
            }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { _ in
                        hoveredNodeID = nil
                    }
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        hoveredNodeID = nil
                        viewportOffset.width += value.translation.width
                        viewportOffset.height += value.translation.height
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { _ in
                        hoveredNodeID = nil
                    }
                    .updating($pinchScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        hoveredNodeID = nil
                        viewportScale = min(1.8, max(0.62, viewportScale * value))
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard !interactionExclusionFrames.contains(where: { $0.contains(value.location) }) else {
                            return
                        }

                        if let tappedNodeID = promptHoveredNodeID(
                            at: value.location,
                            in: transformedClusters
                        ) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                hoveredNodeID = nil
                                pinnedNodeID = tappedNodeID
                            }
                        } else if pinnedNodeID != nil {
                            withAnimation(.easeOut(duration: 0.16)) {
                                pinnedNodeID = nil
                                hoveredNodeID = nil
                            }
                        }
                    }
            )
        }
    }

    private func clearHover() {
        hoveredNodeID = nil
    }
}

private struct PromptMapGrid: View {
    let scale: CGFloat
    let offset: CGSize

    var body: some View {
        Canvas { context, size in
            let spacing = max(28, min(60, 44 * scale))
            let xStart = offset.width.truncatingRemainder(dividingBy: spacing) - spacing
            let yStart = offset.height.truncatingRemainder(dividingBy: spacing) - spacing
            let lineColor = Color(nsColor: .separatorColor).opacity(0.16)

            var x = xStart
            while x < size.width + spacing {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.6)
                x += spacing
            }

            var y = yStart
            while y < size.height + spacing {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.6)
                y += spacing
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.58))
    }
}

private struct PromptMapCluster: Identifiable {
    let id: AgentOwner
    let title: String
    let rect: CGRect
    let layouts: [PromptNodeLayout]
}

private struct PromptNodeLayout: Identifiable {
    var id: PromptMapNode.ID { node.id }
    let node: PromptMapNode
    let rect: CGRect
    let depth: Double
}

private struct PromptClusterBoundary: View {
    let cluster: PromptMapCluster

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.36))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.38))
                }

            HStack(spacing: 8) {
                Image(systemName: promptSurfaceIcon(cluster.id))
                Text(cluster.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(promptOwnerTint(cluster.id))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .frame(width: cluster.rect.width, height: cluster.rect.height)
        .position(x: cluster.rect.midX, y: cluster.rect.midY)
    }
}

private struct PromptMapTile: View {
    let layout: PromptNodeLayout
    let isHovered: Bool
    let isPinned: Bool
    let isDimmed: Bool

    private var node: PromptMapNode { layout.node }
    private var tint: Color { promptNodeTint(node) }
    private var textColor: Color { .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: promptDestinationIcon(node.destination))
                    .font(.caption.weight(.bold))
                    .frame(width: 16)
                    .opacity(0.9)

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                    Text(node.subtitle)
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .opacity(0.78)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                Text("\(node.itemCount) items")
                Text("\(node.tokenCount) tok")
                Spacer()
                Text(node.isPromptMaterial ? "prompt" : "registry")
                    .fontWeight(.semibold)
            }
            .font(.caption2.monospacedDigit())
            .opacity(0.86)
        }
        .padding(12)
        .frame(width: layout.rect.width, height: layout.rect.height, alignment: .topLeading)
        .foregroundStyle(textColor)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.gradient)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(isHovered || isPinned ? 0.18 : 0.08))
                    .blendMode(.plusLighter)
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(isHovered || isPinned ? 0.5 : 0.18), lineWidth: isHovered || isPinned ? 1.2 : 0.8)
        }
        .shadow(color: tint.opacity(isHovered || isPinned ? 0.38 : 0.2), radius: isHovered || isPinned ? 22 : 10, x: 0, y: isHovered || isPinned ? 13 : 6)
        .opacity(isDimmed ? 0.34 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .zIndex(isPinned ? 20 : (isHovered ? 12 : layout.depth))
    }
}

private struct PromptNodeHoverCard: View {
    @EnvironmentObject private var store: AssetStore
    let node: PromptMapNode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PromptNodeDetailHeader(node: node)

            Divider()

            PromptNodeDetailRows(node: node)

            if !node.previewExcerpt.isEmpty {
                Text(node.previewExcerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let asset = node.firstAsset {
                Label(asset.displayPath, systemImage: "folder")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(promptText("Click the block to pin actions.", "点击色块固定操作面板。", language: store.appLanguage))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }
}

private struct PromptPinnedNodePanel: View {
    @EnvironmentObject private var store: AssetStore
    let node: PromptMapNode
    let close: () -> Void
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PromptNodeDetailHeader(node: node)

                Spacer()

                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .compactHitTarget()
                }
                .buttonStyle(.plain)
            }

            PromptNodeDetailRows(node: node)

            if !node.previewExcerpt.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(promptText("Preview", "预览", language: store.appLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(node.previewExcerpt)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(promptText("Sources", "来源", language: store.appLanguage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(node.items.prefix(5), id: \.id) { item in
                    PathPreviewLink(
                        path: item.asset.path,
                        displayPath: item.asset.displayPath,
                        font: .caption.monospaced(),
                        foregroundColor: .secondary,
                        language: store.appLanguage
                    )
                }

                if node.items.count > 5 {
                    Text(promptText(
                        "\(node.items.count - 5) more sources in this block.",
                        "这个色块还有 \(node.items.count - 5) 个来源。",
                        language: store.appLanguage
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Button {
                    copyNodeBrief(node)
                    didCopy = true
                } label: {
                    Label(didCopy ? promptText("Copied", "已复制", language: store.appLanguage) : promptText("Copy block", "复制色块", language: store.appLanguage), systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                if let asset = node.firstAsset {
                    Button {
                        reveal(path: asset.path)
                    } label: {
                        Label(promptText("Finder", "Finder", language: store.appLanguage), systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(promptNodeTint(node).opacity(0.32))
        }
        .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 14)
    }
}

private struct PromptNodeDetailHeader: View {
    @EnvironmentObject private var store: AssetStore
    let node: PromptMapNode

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: promptDestinationIcon(node.destination))
                .font(.title3.weight(.semibold))
                .foregroundStyle(promptNodeTint(node))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(promptSurfaceTitle(node.surface, language: store.appLanguage))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(promptOwnerTint(node.surface))
            }
        }
    }
}

private struct PromptNodeDetailRows: View {
    @EnvironmentObject private var store: AssetStore
    let node: PromptMapNode

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            detailRow(promptText("Placement", "放置位置", language: store.appLanguage), L10n.loadDestination(node.destination, language: store.appLanguage))
            detailRow(promptText("Layer", "层级", language: store.appLanguage), L10n.contextLayer(node.layer, language: store.appLanguage))
            detailRow(promptText("Role", "角色", language: store.appLanguage), L10n.contextRole(node.role, language: store.appLanguage))
            detailRow(promptText("Items", "项目", language: store.appLanguage), "\(node.itemCount)")
            detailRow("Token", "\(node.tokenCount)")
        }
        .font(.caption)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

private struct PromptMapLegend: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        HStack(spacing: 12) {
            legendItem(promptText("Prompt", "提示词", language: store.appLanguage), .blue)
            legendItem(promptText("Memory", "记忆", language: store.appLanguage), .purple)
            legendItem(promptText("Project", "项目", language: store.appLanguage), .teal)
            legendItem("Skill", .orange)
            legendItem("MCP", .yellow)
            legendItem(promptText("Support", "支持", language: store.appLanguage), .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color.gradient)
                .frame(width: 13, height: 9)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@MainActor
private func promptPreview(for surface: AgentOwner, store: AssetStore) -> SystemPromptPreview {
    let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let memoryItems = store.contextCatalog.memoryItems.filter { query.isEmpty || $0.asset.matchesSearch(query: query) }
    let capabilityItems = store.visibleCapabilityItems.filter { query.isEmpty || $0.asset.matchesSearch(query: query) }
    let catalog = ContextCatalog(memoryItems: memoryItems, capabilityItems: capabilityItems, assemblySteps: [])

    return SystemPromptPreviewBuilder().preview(
        surface: surface,
        catalog: catalog,
        visibleCapabilityItems: capabilityItems
    )
}

private func promptNodes(for preview: SystemPromptPreview, language: AppLanguage) -> [PromptMapNode] {
    preview.sections.map { section in
        PromptMapNode(
            id: "\(preview.surface.rawValue)-\(section.id)",
            title: promptNodeTitle(section, language: language),
            subtitle: promptNodeSubtitle(section, language: language),
            surface: preview.surface,
            role: section.role,
            layer: section.layer,
            destination: section.destination,
            items: section.items,
            tokenCount: section.estimatedTokenCount
        )
    }
}

private func promptClusters(
    nodes: [PromptMapNode],
    surfaceMode: PromptSurfaceMode,
    size: CGSize,
    language: AppLanguage
) -> [PromptMapCluster] {
    let horizontalPadding: CGFloat = 30
    let topPadding: CGFloat = 28
    let bottomPadding: CGFloat = 92
    let clusterGap: CGFloat = 22
    let surfaces = surfaceMode.surfaces
    let availableWidth = max(420, size.width - horizontalPadding * 2)
    let availableHeight = max(360, size.height - topPadding - bottomPadding)

    return surfaces.enumerated().compactMap { index, surface in
        let surfaceNodes = nodes.filter { $0.surface == surface }
        guard !surfaceNodes.isEmpty else { return nil }

        let width: CGFloat
        let originX: CGFloat

        if surfaces.count == 1 {
            width = min(1100, availableWidth)
            originX = horizontalPadding + max(0, (availableWidth - width) / 2)
        } else {
            width = (availableWidth - clusterGap) / 2
            originX = horizontalPadding + CGFloat(index) * (width + clusterGap)
        }

        let rect = CGRect(x: originX, y: topPadding, width: width, height: availableHeight)
        return PromptMapCluster(
            id: surface,
            title: promptSurfaceTitle(surface, language: language),
            rect: rect,
            layouts: promptNodeLayouts(nodes: surfaceNodes, in: rect.insetBy(dx: 16, dy: 44))
        )
    }
}

private func promptNodeLayouts(nodes: [PromptMapNode], in rect: CGRect) -> [PromptNodeLayout] {
    let sorted = nodes.sorted {
        if $0.tokenCount != $1.tokenCount {
            return $0.tokenCount > $1.tokenCount
        }
        return $0.title.localizedStandardCompare($1.title) == .orderedAscending
    }
    let gap: CGFloat = 13
    let columns = max(2, min(5, Int(rect.width / 205)))
    let columnWidth = (rect.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
    let weights = sorted.map(promptVisualWeight)
    let minWeight = weights.min() ?? 0
    let maxWeight = weights.max() ?? 1
    let weightRange = max(0.001, maxWeight - minWeight)
    var columnHeights = Array(repeating: rect.minY, count: columns)

    return sorted.enumerated().map { index, node in
        let normalized = (promptVisualWeight(node) - minWeight) / weightRange
        let span = promptColumnSpan(for: node, normalized: normalized, columns: columns)
        let targetColumn = promptBestColumnStart(span: span, columnHeights: columnHeights)
        let y = columnHeights[targetColumn..<(targetColumn + span)].max() ?? rect.minY
        let width = CGFloat(span) * columnWidth + CGFloat(span - 1) * gap
        let height = promptTileHeight(for: node, normalized: normalized, span: span)
        let x = rect.minX + CGFloat(targetColumn) * (columnWidth + gap)

        for column in targetColumn..<(targetColumn + span) {
            columnHeights[column] = y + height + gap
        }

        return PromptNodeLayout(
            node: node,
            rect: CGRect(x: x, y: y, width: width, height: height),
            depth: Double(index)
        )
    }
}

private func transformPromptClusters(
    _ clusters: [PromptMapCluster],
    size: CGSize,
    scale: CGFloat,
    offset: CGSize
) -> [PromptMapCluster] {
    clusters.map { cluster in
        PromptMapCluster(
            id: cluster.id,
            title: cluster.title,
            rect: transformPromptRect(cluster.rect, size: size, scale: scale, offset: offset),
            layouts: cluster.layouts.map { layout in
                PromptNodeLayout(
                    node: layout.node,
                    rect: transformPromptRect(layout.rect, size: size, scale: scale, offset: offset),
                    depth: layout.depth
                )
            }
        )
    }
}

private func transformPromptRect(
    _ rect: CGRect,
    size: CGSize,
    scale: CGFloat,
    offset: CGSize
) -> CGRect {
    let anchor = CGPoint(x: size.width / 2, y: size.height / 2)
    let origin = CGPoint(
        x: anchor.x + (rect.minX - anchor.x) * scale + offset.width,
        y: anchor.y + (rect.minY - anchor.y) * scale + offset.height
    )
    return CGRect(
        x: origin.x,
        y: origin.y,
        width: rect.width * scale,
        height: rect.height * scale
    )
}

private func promptHoveredNodeID(
    at location: CGPoint,
    in clusters: [PromptMapCluster],
    excluding exclusionFrames: [CGRect] = []
) -> PromptMapNode.ID? {
    if exclusionFrames.contains(where: { $0.insetBy(dx: -4, dy: -4).contains(location) }) {
        return nil
    }

    return clusters
        .flatMap(\.layouts)
        .filter { $0.rect.insetBy(dx: -2, dy: -2).contains(location) }
        .sorted { $0.depth > $1.depth }
        .first?
        .node
        .id
}

private func promptHoverPanelFrame(
    avoiding rect: CGRect,
    in size: CGSize,
    panelSize: CGSize,
    excluding exclusionFrames: [CGRect] = []
) -> CGRect {
    let margin: CGFloat = 18
    let panelWidth = min(panelSize.width, max(220, size.width - margin * 2))
    let panelHeight = min(panelSize.height, max(190, size.height - margin * 2))
    let rightX = max(margin, size.width - margin - panelWidth)
    let bottomY = max(margin, size.height - margin - panelHeight)
    let sourceRect = rect.insetBy(dx: -14, dy: -14)
    let blockedFrames = [sourceRect] + exclusionFrames.map { $0.insetBy(dx: -8, dy: -8) }

    let candidates = [
        CGRect(x: rightX, y: margin, width: panelWidth, height: panelHeight),
        CGRect(x: margin, y: margin, width: panelWidth, height: panelHeight),
        CGRect(x: rightX, y: bottomY, width: panelWidth, height: panelHeight),
        CGRect(x: margin, y: bottomY, width: panelWidth, height: panelHeight)
    ]

    if let nonOverlapping = candidates.first(where: { candidate in
        !blockedFrames.contains(where: { $0.intersects(candidate) })
    }) {
        return nonOverlapping
    }

    return candidates.min {
        promptPanelOverlapArea($0, blockedFrames) < promptPanelOverlapArea($1, blockedFrames)
    } ?? candidates[0]
}

private func promptLegendExclusionFrame(in size: CGSize) -> CGRect {
    let margin: CGFloat = 18
    let width = min(620, max(220, size.width - margin * 2))
    let height: CGFloat = 56
    return CGRect(
        x: margin,
        y: max(margin, size.height - margin - height),
        width: width,
        height: height
    )
}

private func promptPinnedPanelWidth(in size: CGSize) -> CGFloat {
    min(430, max(340, size.width * 0.34))
}

private func promptPinnedPanelFrame(in size: CGSize, panelWidth: CGFloat) -> CGRect {
    let horizontalPadding: CGFloat = 36
    let width = min(size.width, panelWidth + horizontalPadding)
    return CGRect(
        x: max(0, size.width - width),
        y: 0,
        width: width,
        height: size.height
    )
}

private func promptPanelOverlapArea(_ rect: CGRect, _ blockedFrames: [CGRect]) -> CGFloat {
    blockedFrames.reduce(0) { total, blocked in
        let intersection = rect.intersection(blocked)
        guard !intersection.isNull, !intersection.isEmpty else { return total }
        return total + intersection.width * intersection.height
    }
}

private func promptVisualWeight(_ node: PromptMapNode) -> CGFloat {
    let tokenScore = log(CGFloat(max(node.tokenCount, 1)) + 1)
    let itemScore = sqrt(CGFloat(max(node.itemCount, 1))) * 1.25
    let promptBoost: CGFloat = node.isPromptMaterial ? 0.55 : 0
    return tokenScore + itemScore + promptBoost
}

private func promptColumnSpan(
    for node: PromptMapNode,
    normalized: CGFloat,
    columns: Int
) -> Int {
    guard columns >= 3 else { return 1 }
    if columns >= 5, normalized > 0.72 || node.itemCount >= 24 {
        return 3
    }
    if normalized > 0.38 || node.itemCount >= 8 {
        return 2
    }
    return 1
}

private func promptBestColumnStart(span: Int, columnHeights: [CGFloat]) -> Int {
    guard span < columnHeights.count else { return 0 }

    var bestStart = 0
    var bestY = CGFloat.greatestFiniteMagnitude
    for start in 0...(columnHeights.count - span) {
        let y = columnHeights[start..<(start + span)].max() ?? .greatestFiniteMagnitude
        if y < bestY {
            bestY = y
            bestStart = start
        }
    }
    return bestStart
}

private func promptTileHeight(
    for node: PromptMapNode,
    normalized: CGFloat,
    span: Int
) -> CGFloat {
    let shaped = pow(max(0, min(1, normalized)), 0.72)
    let itemBoost = min(58, sqrt(CGFloat(max(node.itemCount, 1))) * 10)
    let base = 84 + shaped * 150 + itemBoost
    let spanCompression: CGFloat = span > 1 ? 0.88 : 1
    return min(280, max(86, base * spanCompression))
}

private func promptNodeTitle(_ section: SystemPromptPreviewSection, language: AppLanguage) -> String {
    if section.items.count == 1, let item = section.items.first {
        return item.asset.title
    }
    switch section.destination {
    case .systemPrompt:
        return promptText("Entry Instructions", "入口指令", language: language)
    case .memoryBlock:
        return promptText("Long-term Memory", "长期记忆", language: language)
    case .projectContextBlock:
        return promptText("Project Context", "项目上下文", language: language)
    case .workspaceContextBlock:
        return promptText("Workspace Context", "工作区上下文", language: language)
    case .pluginInstructionBlock:
        return promptText("Plugin Instructions", "插件指令", language: language)
    case .skillRegistry:
        return "Skill Registry"
    case .commandRegistry:
        return "Command Registry"
    case .toolRegistry:
        return "MCP Tools"
    case .pluginRegistry:
        return "Plugin Registry"
    case .configuration:
        return promptText("Configuration", "配置", language: language)
    case .sessionArchive:
        return promptText("Session Archive", "会话历史", language: language)
    case .supportFile:
        return promptText("Support Files", "支持文件", language: language)
    case .indexOnly:
        return promptText("Index-only", "仅索引", language: language)
    }
}

private func promptNodeSubtitle(_ section: SystemPromptPreviewSection, language: AppLanguage) -> String {
    "\(L10n.contextLayer(section.layer, language: language)) · \(L10n.contextRole(section.role, language: language))"
}

private func promptText(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
    switch language {
    case .english: english
    case .simplifiedChinese: simplifiedChinese
    }
}

private func promptSurfaceTitle(_ surface: AgentOwner, language: AppLanguage) -> String {
    surface == .claude ? "Claude Code" : L10n.agentOwner(surface, language: language)
}

private func promptSurfaceIcon(_ surface: AgentOwner) -> String {
    switch surface {
    case .claude: "terminal"
    case .codex: "cube.transparent"
    case .agents: "person.2.wave.2"
    case .project: "folder"
    case .unknown: "questionmark.folder"
    }
}

private func promptOwnerTint(_ surface: AgentOwner) -> Color {
    switch surface {
    case .claude: Color(red: 0.9, green: 0.45, blue: 0.16)
    case .codex: Color(red: 0.1, green: 0.44, blue: 0.95)
    case .agents: .green
    case .project: .purple
    case .unknown: .secondary
    }
}

private func promptDestinationIcon(_ destination: ContextLoadDestination) -> String {
    switch destination {
    case .systemPrompt: "text.badge.checkmark"
    case .memoryBlock: "brain.head.profile"
    case .projectContextBlock, .workspaceContextBlock: "folder.badge.gearshape"
    case .pluginInstructionBlock, .pluginRegistry: "puzzlepiece.extension"
    case .skillRegistry: "wand.and.stars"
    case .commandRegistry: "command"
    case .toolRegistry: "point.3.connected.trianglepath.dotted"
    case .configuration: "switch.2"
    case .sessionArchive: "clock.arrow.circlepath"
    case .supportFile: "doc.on.doc"
    case .indexOnly: "tray"
    }
}

private func promptNodeTint(_ node: PromptMapNode) -> Color {
    switch node.destination {
    case .systemPrompt:
        Color(red: 0.08, green: 0.42, blue: 0.95)
    case .memoryBlock:
        Color(red: 0.45, green: 0.32, blue: 0.95)
    case .projectContextBlock, .workspaceContextBlock:
        Color(red: 0.0, green: 0.55, blue: 0.58)
    case .pluginInstructionBlock, .pluginRegistry:
        Color(red: 0.75, green: 0.38, blue: 0.82)
    case .skillRegistry, .commandRegistry:
        Color(red: 0.92, green: 0.43, blue: 0.12)
    case .toolRegistry:
        Color(red: 0.86, green: 0.58, blue: 0.08)
    case .configuration, .sessionArchive, .supportFile, .indexOnly:
        Color(red: 0.38, green: 0.42, blue: 0.48)
    }
}

private func reveal(path: String) {
    let url = FinderRevealTarget.selectingURL(for: path)
    NSWorkspace.shared.activateFileViewerSelecting([url])
}

private func copyNodeBrief(_ node: PromptMapNode) {
    let paths = node.items.map { "- `\($0.asset.displayPath)`" }.joined(separator: "\n")
    let text = """
    # \(node.title)

    Surface: \(node.surface.rawValue)
    Placement: \(node.destination.rawValue)
    Layer: \(node.layer.rawValue)
    Items: \(node.itemCount)
    Estimated tokens: \(node.tokenCount)

    ## Sources
    \(paths)

    ## Preview
    \(node.previewExcerpt)
    """

    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
