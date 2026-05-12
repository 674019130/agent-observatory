import AgentObservatoryCore
import SwiftUI

struct LatestManagementOperationCard: View {
    @EnvironmentObject private var store: AssetStore
    let batch: ManagementOperationBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(store.t(.operationResult), systemImage: "checkmark.seal")
                    .font(.headline)
                BadgeView(text: L10n.managementOperationSource(batch.source, language: store.appLanguage), tint: .blue)
                Spacer()
                if batch.undoableCount > 0 {
                    Button {
                        store.undoLatestManagementBatch()
                    } label: {
                        Label(store.t(.undoLatestOperation), systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(batch.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Text(batch.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    CountBadge(count: batch.appliedCount, tint: .green)
                    CountBadge(count: batch.failedCount, tint: batch.failedCount > 0 ? .orange : .secondary)
                    if batch.undoneCount > 0 {
                        CountBadge(count: batch.undoneCount, tint: .purple)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(batch.records.prefix(4)) { record in
                    ManagementOperationRecordLine(record: record)
                }
                if batch.records.count > 4 {
                    Text("+ \(batch.records.count - 4)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

struct ManagementOperationHistorySection: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(store.t(.operationHistory), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                CountBadge(count: store.managementOperationBatches.count, tint: .secondary)
            }

            if store.managementOperationBatches.isEmpty {
                Text(store.t(.noOperationHistory))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(store.managementOperationBatches) { batch in
                        ManagementOperationBatchRow(batch: batch)
                    }
                }
            }
        }
    }
}

private struct ManagementOperationBatchRow: View {
    @EnvironmentObject private var store: AssetStore
    let batch: ManagementOperationBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(batch.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                BadgeView(text: L10n.managementOperationSource(batch.source, language: store.appLanguage), tint: .blue)
                Spacer()
                Text(batch.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label("\(batch.appliedCount)", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Label("\(batch.failedCount)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(batch.failedCount > 0 ? .orange : .secondary)
                if batch.undoneCount > 0 {
                    Label("\(batch.undoneCount)", systemImage: "arrow.uturn.backward")
                        .foregroundStyle(.purple)
                }
                Spacer()
                if store.latestManagementBatch?.id == batch.id, batch.undoableCount > 0 {
                    Button(store.t(.undoLatestOperation)) {
                        store.undoLatestManagementBatch()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.caption)

            ForEach(batch.records.prefix(3)) { record in
                ManagementOperationRecordLine(record: record)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct ManagementOperationRecordLine: View {
    @EnvironmentObject private var store: AssetStore
    let record: ManagementOperationRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            BadgeView(text: L10n.managementOperationKind(record.kind, language: store.appLanguage), tint: kindTint)
            Text(record.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            BadgeView(text: L10n.managementOperationStatus(record.status, language: store.appLanguage), tint: statusTint)
        }
        .help(record.message)
    }

    private var kindTint: Color {
        switch record.kind {
        case .hide:
            .purple
        case .archive:
            .orange
        case .mergeArchive:
            .blue
        }
    }

    private var statusTint: Color {
        switch record.status {
        case .applied:
            .green
        case .failed, .undoFailed:
            .orange
        case .undone:
            .purple
        }
    }
}
