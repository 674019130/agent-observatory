import AgentObservatoryCore
import AppKit
import SwiftUI

@main
struct AgentObservatoryApp: App {
    @NSApplicationDelegateAdaptor(AgentObservatoryAppDelegate.self) private var appDelegate
    @StateObject private var store: AssetStore

    init() {
        let store = AssetStore()
        _store = StateObject(wrappedValue: store)
        AgentObservatoryAppDelegate.store = store
    }

    var body: some Scene {
        WindowGroup("Agent Observatory") {
            AgentObservatoryRootContent()
                .environmentObject(store)
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

            CommandMenu(store.t(.viewMenu)) {
                Button(store.t(.goBack)) {
                    store.goBack()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!store.canGoBack)

                Divider()

                Button(store.t(.zoomIn)) {
                    store.zoomInterfaceIn()
                }
                .disabled(!store.interfaceZoomLevel.canZoomIn)

                Button(store.t(.zoomOut)) {
                    store.zoomInterfaceOut()
                }
                .disabled(!store.interfaceZoomLevel.canZoomOut)

                Button(store.t(.actualSize)) {
                    store.resetInterfaceZoom()
                }
                .disabled(store.interfaceZoomLevel == .defaultLevel)
            }
        }

        Settings {
            InterfaceZoomContainer(level: store.interfaceZoomLevel, minimumSize: CGSize(width: 860, height: 620)) {
                SettingsView()
                    .environmentObject(store)
            }
        }
    }
}

private final class AgentObservatoryAppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var store: AssetStore?
    @MainActor private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task { @MainActor in
                self.ensureMainWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                self.ensureMainWindow()
            }
        }
        return true
    }

    @MainActor
    private func ensureMainWindow() {
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeKey
        }
        guard !hasVisibleMainWindow, let store = Self.store else { return }

        let rootView = AgentObservatoryRootContent()
            .environmentObject(store)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Agent Observatory"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.minSize = NSSize(width: 1080, height: 720)
        window.setContentSize(NSSize(width: 1320, height: 860))
        window.center()
        window.makeKeyAndOrderFront(nil)
        fallbackWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AgentObservatoryRootContent: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        InterfaceZoomContainer(level: store.interfaceZoomLevel, minimumSize: CGSize(width: 1080, height: 720)) {
            ContentView()
                .environmentObject(store)
        }
        .background(
            InterfaceZoomShortcutMonitor(
                zoomIn: { store.zoomInterfaceIn() },
                zoomOut: { store.zoomInterfaceOut() },
                reset: { store.resetInterfaceZoom() }
            )
            .frame(width: 0, height: 0)
        )
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if store.assets.isEmpty {
                store.scan()
            }
        }
    }
}

private struct InterfaceZoomContainer<Content: View>: View {
    let level: InterfaceZoomLevel
    let minimumSize: CGSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        let scale = CGFloat(level.scale)

        content()
            .font(.system(size: baseFontSize(for: scale)))
            .controlSize(controlSize(for: level))
            .frame(
                minWidth: minimumSize.width * scale,
                minHeight: minimumSize.height * scale,
                alignment: .topLeading
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                InterfaceZoomWindowResizer(level: level, minimumSize: minimumSize)
                    .frame(width: 0, height: 0)
            )
    }

    private func baseFontSize(for scale: CGFloat) -> CGFloat {
        13 * scale
    }

    private func controlSize(for level: InterfaceZoomLevel) -> ControlSize {
        switch level {
        case .smallest, .smaller:
            return .small
        case .standard:
            return .regular
        case .larger, .largest, .accessibility:
            return .large
        }
    }
}

private struct InterfaceZoomWindowResizer: NSViewRepresentable {
    let level: InterfaceZoomLevel
    let minimumSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(level: level)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.update(level: level, minimumSize: minimumSize, view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(level: level, minimumSize: minimumSize, view: nsView)
    }

    final class Coordinator {
        private var previousLevel: InterfaceZoomLevel
        private var standardFrame: NSRect?

        init(level: InterfaceZoomLevel) {
            previousLevel = level
        }

        func update(level: InterfaceZoomLevel, minimumSize: CGSize, view: NSView) {
            guard previousLevel != level else { return }

            let oldLevel = previousLevel
            previousLevel = level

            DispatchQueue.main.async { [weak view] in
                guard let view, let window = view.window else { return }
                self.resize(window: window, from: oldLevel, to: level, minimumSize: minimumSize)
            }
        }

        private func resize(
            window: NSWindow,
            from oldLevel: InterfaceZoomLevel,
            to newLevel: InterfaceZoomLevel,
            minimumSize: CGSize
        ) {
            let oldScale = CGFloat(oldLevel.scale)
            let newScale = CGFloat(newLevel.scale)
            guard oldScale > 0, newScale > 0, oldScale != newScale else { return }

            let ratio = newScale / oldScale
            let currentFrame = window.frame
            if oldLevel == .defaultLevel || standardFrame == nil {
                standardFrame = NSRect(origin: currentFrame.origin, size: currentFrame.size)
            }

            let minimumFrameSize = window.frameRect(
                forContentRect: NSRect(
                    origin: .zero,
                    size: CGSize(width: minimumSize.width * newScale, height: minimumSize.height * newScale)
                )
            ).size

            let scaledStandardSize = standardFrame.map { frame in
                CGSize(width: frame.width * newScale, height: frame.height * newScale)
            }

            let proportionalSize = CGSize(width: currentFrame.width * ratio, height: currentFrame.height * ratio)
            let preferredSize = newLevel == .defaultLevel
                ? standardFrame?.size ?? proportionalSize
                : scaledStandardSize ?? proportionalSize

            var targetSize = CGSize(width: preferredSize.width, height: preferredSize.height)
            targetSize.width = max(minimumFrameSize.width, targetSize.width)
            targetSize.height = max(minimumFrameSize.height, targetSize.height)

            if let visibleFrame = window.screen?.visibleFrame {
                targetSize.width = min(targetSize.width, visibleFrame.width)
                targetSize.height = min(targetSize.height, visibleFrame.height)
            }

            var targetFrame = NSRect(
                x: currentFrame.midX - targetSize.width / 2,
                y: currentFrame.midY - targetSize.height / 2,
                width: targetSize.width,
                height: targetSize.height
            )

            if let visibleFrame = window.screen?.visibleFrame {
                targetFrame.origin.x = min(max(targetFrame.minX, visibleFrame.minX), visibleFrame.maxX - targetFrame.width)
                targetFrame.origin.y = min(max(targetFrame.minY, visibleFrame.minY), visibleFrame.maxY - targetFrame.height)
            }

            window.setFrame(targetFrame, display: true, animate: true)
        }
    }
}

private struct InterfaceZoomShortcutMonitor: NSViewRepresentable {
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let reset: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.update(zoomIn: zoomIn, zoomOut: zoomOut, reset: reset)
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(zoomIn: zoomIn, zoomOut: zoomOut, reset: reset)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        private var monitor: Any?
        private var lastHandledShortcut: (keyCode: UInt16, timestamp: TimeInterval)?
        private var zoomIn: () -> Void = {}
        private var zoomOut: () -> Void = {}
        private var reset: () -> Void = {}

        func update(zoomIn: @escaping () -> Void, zoomOut: @escaping () -> Void, reset: @escaping () -> Void) {
            self.zoomIn = zoomIn
            self.zoomOut = zoomOut
            self.reset = reset
        }

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command),
                  !flags.contains(.control),
                  !flags.contains(.option)
            else {
                return event
            }

            guard let action = shortcutAction(for: event) else {
                return event
            }

            if shouldRunShortcut(for: event) {
                action()
            }
            return nil
        }

        private func shortcutAction(for event: NSEvent) -> (() -> Void)? {
            switch event.keyCode {
            case 24:
                return zoomIn
            case 27:
                return zoomOut
            case 29:
                return reset
            default:
                break
            }

            switch event.charactersIgnoringModifiers?.lowercased() {
            case "=":
                return zoomIn
            case "-":
                return zoomOut
            case "0":
                return reset
            default:
                return nil
            }
        }

        private func shouldRunShortcut(for event: NSEvent) -> Bool {
            guard !event.isARepeat else { return false }

            if let lastHandledShortcut,
               lastHandledShortcut.keyCode == event.keyCode,
               event.timestamp - lastHandledShortcut.timestamp < 0.2 {
                return false
            }

            lastHandledShortcut = (event.keyCode, event.timestamp)
            return true
        }
    }
}
