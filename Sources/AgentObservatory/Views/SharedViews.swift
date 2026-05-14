import AgentObservatoryCore
import AppKit
import SwiftUI

enum HitTarget {
    static let compact: CGFloat = 30
    static let row: CGFloat = 32
}

extension View {
    func compactHitTarget(size: CGFloat = HitTarget.compact) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    func rowHitTarget(cornerRadius: CGFloat = 8, minHeight: CGFloat = HitTarget.row) -> some View {
        frame(minHeight: minHeight)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct BadgeView: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.13), in: Capsule())
            .foregroundStyle(tint)
            .contentShape(Capsule())
    }
}

struct CountBadge: View {
    let count: Int
    let tint: Color

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
    }
}

struct PathPreviewLink: View {
    let path: String
    var displayPath: String?
    var font: Font = .caption.monospaced()
    var foregroundColor: Color = .secondary
    var lineLimit: Int = 1
    var language: AppLanguage = .english
    var revealAction: (String) -> Void = FinderPathOpener.reveal

    @State private var isShowingPreview = false
    @State private var hidePreviewTask: Task<Void, Never>?

    private var visiblePath: String {
        displayPath ?? path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var body: some View {
        Button {
            revealPath()
        } label: {
            HStack(spacing: 4) {
                Text(visiblePath)
                    .font(font)
                    .foregroundStyle(foregroundColor)
                    .lineLimit(lineLimit)
                    .truncationMode(.middle)
                    .underline(isShowingPreview, color: foregroundColor.opacity(0.55))

                Image(systemName: "arrow.up.forward.square")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(isShowingPreview ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hovering ? showPreview() : schedulePreviewHide()
        }
        .popover(isPresented: $isShowingPreview, arrowEdge: .bottom) {
            PathPreviewPopover(
                path: path,
                language: language,
                onReveal: revealPath,
                onHoverChange: { hovering in
                    hovering ? showPreview() : schedulePreviewHide()
                }
            )
        }
        .help(path)
    }

    private func revealPath() {
        hidePreviewTask?.cancel()
        isShowingPreview = false
        revealAction(path)
    }

    private func showPreview() {
        hidePreviewTask?.cancel()
        isShowingPreview = true
    }

    private func schedulePreviewHide() {
        hidePreviewTask?.cancel()
        hidePreviewTask = Task {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            await MainActor.run {
                isShowingPreview = false
            }
        }
    }
}

private struct PathPreviewPopover: View {
    let path: String
    let language: AppLanguage
    let onReveal: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Button(action: onReveal) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Label(actionHint, systemImage: "arrow.up.forward.app")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(minWidth: 320, idealWidth: 420, maxWidth: 520, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover(perform: onHoverChange)
        .help(actionHint)
    }

    private var title: String {
        switch language {
        case .english:
            "Full path"
        case .simplifiedChinese:
            "完整路径"
        }
    }

    private var actionHint: String {
        switch language {
        case .english:
            "Click the path to reveal it in Finder."
        case .simplifiedChinese:
            "点击路径即可在 Finder 中定位。"
        }
    }
}

private enum FinderPathOpener {
    static func reveal(path: String) {
        let url = FinderRevealTarget.selectingURL(for: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct OfficialDocTipsPanel: View {
    @EnvironmentObject private var store: AssetStore
    let tips: [OfficialDocTip]

    var body: some View {
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(panelTitle, systemImage: "lightbulb")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(tips) { tip in
                        OfficialDocTipRow(tip: tip)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.blue.opacity(0.22))
            }
        }
    }

    private var panelTitle: String {
        switch store.appLanguage {
        case .english:
            "Official docs tips"
        case .simplifiedChinese:
            "官方文档 Tips"
        }
    }
}

private struct OfficialDocTipRow: View {
    @EnvironmentObject private var store: AssetStore
    let tip: OfficialDocTip

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(tip.title)
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            Text(tip.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(locationLabel) \(tip.sourceLocation)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if let url = URL(string: tip.sourceURL) {
                    Link(destination: url) {
                        Label(tip.sourceTitle, systemImage: "arrow.up.forward.square")
                            .labelStyle(.titleAndIcon)
                    }
                    .font(.caption2.weight(.medium))
                }
            }
        }
    }

    private var locationLabel: String {
        switch store.appLanguage {
        case .english:
            "Location:"
        case .simplifiedChinese:
            "位置："
        }
    }
}

struct InspectorPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }
}

struct ManagementErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ArchiveConfirmationSheet: View {
    @EnvironmentObject private var store: AssetStore
    let asset: AgentAsset
    @Binding var reason: String
    let onArchive: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(store.t(.archiveAction)) \(asset.title)")
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    PathPreviewLink(
                        path: asset.path,
                        displayPath: asset.displayPath,
                        font: .caption.monospaced(),
                        foregroundColor: .secondary,
                        lineLimit: 2,
                        language: store.appLanguage
                    )
                }
            }

            Text(store.t(.archiveConfirmationMessage))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField(store.t(.archiveReason), text: $reason)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(store.t(.cancel), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    onArchive()
                } label: {
                    Label(store.t(.archiveAction), systemImage: "archivebox")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(22)
        .frame(width: 440)
    }
}
