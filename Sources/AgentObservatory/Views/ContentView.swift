import AgentObservatoryCore
import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } content: {
            Group {
                if store.selectedSection == .dashboard {
                    DashboardView()
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
            } else if store.selectedSection == .hidden {
                EmptyStateView(
                    title: store.t(.hiddenItems),
                    message: store.t(.hiddenCenterMessage),
                    systemImage: "eye.slash"
                )
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            } else {
                InspectorView()
                    .navigationSplitViewColumnWidth(min: 420, ideal: 620)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(store.t(.toggleSidebar))
            }

            ToolbarItemGroup {
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
                .help(store.t(.refresh))
            }

            Button {
                store.enrichSelectedAsset()
            } label: {
                Label(store.t(.explain), systemImage: "sparkles")
            }
            .disabled(store.selectedSection == .archive || store.selectedSection == .hidden || store.selectedAsset == nil || store.enrichingAssetID != nil)
            .help(store.t(.explainWithOpenAI))

            if store.isIndexStale {
                Label(store.t(.stale), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(store.t(.sourceFilesChangedAfterScan))
            }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(store.t(.searchPlaceholder), text: $store.searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 330)
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(store.t(.clearSearch))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
