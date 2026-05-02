import AgentObservatoryCore
import SwiftUI

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
                    Text(asset.displayPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
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
