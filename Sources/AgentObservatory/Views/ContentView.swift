import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        Group {
            if store.selectedSection == .systemPromptPreview {
                wideCanvasLayout
            } else {
                standardSplitLayout
            }
        }
        .toolbar {
            appToolbar
        }
    }

    private var wideCanvasLayout: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            SystemPromptPreviewView()
                .navigationSplitViewColumnWidth(min: 720, ideal: 1120)
        }
    }

    private var standardSplitLayout: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } content: {
            Group {
                if store.selectedSection == .triggerRadar {
                    SkillTriggerRadarView()
                } else if store.selectedSection == .contextOverview {
                    ContextOverviewView()
                } else if store.selectedSection == .memories {
                    MemoryBrowserView()
                } else if store.selectedSection == .capabilities {
                    CapabilityBrowserView()
                } else if store.selectedSection == .mcpTools {
                    MCPBrowserView()
                } else if store.selectedSection == .assembly {
                    ContextAssemblyView()
                } else if store.selectedSection == .dashboard {
                    DashboardView()
                } else if store.selectedSection == .organizer {
                    OrganizerView()
                } else if store.selectedSection == .hidden {
                    HiddenView()
                } else if store.selectedSection == .archive {
                    ArchiveView()
                } else {
                    AssetListView()
                }
            }
            .navigationSplitViewColumnWidth(min: 360, ideal: 460, max: 560)
        } detail: {
            if store.selectedSection == .archive {
                EmptyStateView(
                    title: store.t(.archiveCenter),
                    message: store.t(.archiveCenterMessage),
                    systemImage: "archivebox"
                )
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else if store.selectedSection == .triggerRadar {
                if let conflict = store.selectedSkillTriggerConflict {
                    SkillTriggerConflictDetailView(conflict: conflict)
                        .navigationSplitViewColumnWidth(min: 420, ideal: 620)
                } else {
                    EmptyStateView(
                        title: store.t(.triggerConflictDetailPlaceholder),
                        message: store.t(.triggerConflictDetailPlaceholderMessage),
                        systemImage: "scope"
                    )
                    .navigationSplitViewColumnWidth(min: 420, ideal: 620)
                }
            } else if store.selectedSection == .organizer {
                OrganizerDetailView()
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else if store.selectedSection == .hidden {
                EmptyStateView(
                    title: store.t(.hiddenItems),
                    message: store.t(.hiddenCenterMessage),
                    systemImage: "eye.slash"
                )
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else if let contextGroup = store.selectedContextTreeGroup {
                ContextGroupInspectorView(node: contextGroup)
                    .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else if shouldShowContextOverviewInspector {
                ContextOverviewInspectorView()
                    .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else if shouldShowContextPlaceholder {
                EmptyStateView(
                    title: store.t(.contextDetailPlaceholder),
                    message: store.t(.contextDetailPlaceholderMessage),
                    systemImage: "doc.text.magnifyingglass"
                )
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else {
                InspectorView()
                    .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            }
        }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .compactHitTarget()
            }
            .disabled(!store.canGoBack)
            .help(store.t(.goBack))
            .accessibilityLabel(store.t(.goBack))
        }

        ToolbarItem(placement: .primaryAction) {
            scanToolbarButton
        }

        ToolbarItem(placement: .principal) {
            searchField
        }
    }

    @ViewBuilder
    private var scanToolbarButton: some View {
        if store.isScanning {
            Button {
                store.cancelScan()
            } label: {
                Label(store.t(.cancel), systemImage: "xmark.circle")
            }
            .help(store.t(.cancel))
        } else {
            Button {
                store.scan()
            } label: {
                Label(store.t(.refresh), systemImage: "arrow.clockwise")
            }
            .help(store.isIndexStale ? store.t(.refreshStaleIndex) : store.t(.refresh))
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(store.t(.searchPlaceholder), text: $store.searchText)
                .textFieldStyle(.plain)
                .frame(minWidth: 180, idealWidth: 300, maxWidth: 360)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .compactHitTarget()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(store.t(.clearSearch))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minWidth: 230, idealWidth: 360, maxWidth: 430)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var shouldShowContextPlaceholder: Bool {
        switch store.selectedSection {
        case .contextOverview, .memories, .capabilities, .mcpTools, .assembly:
            store.selectedAssetID == nil
        default:
            false
        }
    }

    private var shouldShowContextOverviewInspector: Bool {
        store.selectedSection == .contextOverview && store.selectedAssetID == nil
    }
}
