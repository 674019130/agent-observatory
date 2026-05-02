import AppKit
import SwiftUI

@main
struct AgentObservatoryApp: App {
    @StateObject private var store = AssetStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1080, minHeight: 720)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    if store.assets.isEmpty {
                        store.scan()
                    }
                }
        }
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(after: .newItem) {
                Button(store.t(.refresh)) {
                    store.scan()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(store.isScanning)

                Button(store.t(.cancel)) {
                    store.cancelScan()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!store.isScanning)
            }

            CommandMenu(store.t(.assets)) {
                Button(store.t(.explainWithOpenAI)) {
                    store.enrichSelectedAsset()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(store.selectedAsset == nil || store.enrichingAssetID != nil)

                Button(store.t(.showInFinder)) {
                    guard let asset = store.selectedAsset else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: asset.path)])
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(store.selectedAsset == nil)

                Divider()

                Button(store.t(.resetFilters)) {
                    store.resetFilters()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 860, height: 620)
        }
    }
}
