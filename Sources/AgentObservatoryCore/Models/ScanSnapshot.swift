import Foundation

public struct ScanSnapshot: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let entries: [String: ScanSnapshotEntry]

    public init(assets: [AgentAsset], capturedAt: Date = Date()) {
        self.capturedAt = capturedAt
        self.entries = Dictionary(uniqueKeysWithValues: assets.map { asset in
            (
                asset.path,
                ScanSnapshotEntry(
                    path: asset.path,
                    title: asset.title,
                    owner: asset.owner,
                    kind: asset.kind,
                    contentHash: asset.contentHash,
                    modifiedAt: asset.modifiedAt
                )
            )
        })
    }

    public static func diff(from previous: ScanSnapshot?, to current: ScanSnapshot) -> AssetChangeSummary {
        guard let previous else {
            return AssetChangeSummary(
                added: current.entries.values.sortedByPath().map(AssetChange.init(entry:)),
                removed: [],
                changed: []
            )
        }

        let previousEntries = previous.entries
        let currentEntries = current.entries

        let added = currentEntries
            .filter { previousEntries[$0.key] == nil }
            .map { AssetChange(entry: $0.value) }
            .sortedByPath()

        let removed = previousEntries
            .filter { currentEntries[$0.key] == nil }
            .map { AssetChange(entry: $0.value) }
            .sortedByPath()

        let changed = currentEntries
            .compactMap { path, currentEntry -> AssetChange? in
                guard let previousEntry = previousEntries[path],
                      previousEntry.contentHash != currentEntry.contentHash else {
                    return nil
                }
                return AssetChange(
                    path: currentEntry.path,
                    title: currentEntry.title,
                    owner: currentEntry.owner,
                    kind: currentEntry.kind,
                    previousHash: previousEntry.contentHash,
                    currentHash: currentEntry.contentHash
                )
            }
            .sortedByPath()

        return AssetChangeSummary(added: added, removed: removed, changed: changed)
    }
}

public struct ScanSnapshotEntry: Codable, Equatable, Sendable {
    public let path: String
    public let title: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let contentHash: String
    public let modifiedAt: Date?
}

public struct AssetChangeSummary: Codable, Equatable, Sendable {
    public let added: [AssetChange]
    public let removed: [AssetChange]
    public let changed: [AssetChange]

    public init(added: [AssetChange], removed: [AssetChange], changed: [AssetChange]) {
        self.added = added
        self.removed = removed
        self.changed = changed
    }

    public static let empty = AssetChangeSummary(added: [], removed: [], changed: [])

    public var isEmpty: Bool {
        added.isEmpty && removed.isEmpty && changed.isEmpty
    }

    public var totalCount: Int {
        added.count + removed.count + changed.count
    }
}

public struct AssetChange: Identifiable, Codable, Equatable, Sendable {
    public var id: String { "\(path)-\(previousHash ?? "")-\(currentHash ?? "")" }
    public let path: String
    public let title: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let previousHash: String?
    public let currentHash: String?

    public init(
        path: String,
        title: String,
        owner: AgentOwner,
        kind: AssetKind,
        previousHash: String? = nil,
        currentHash: String? = nil
    ) {
        self.path = path
        self.title = title
        self.owner = owner
        self.kind = kind
        self.previousHash = previousHash
        self.currentHash = currentHash
    }

    public init(entry: ScanSnapshotEntry) {
        self.init(
            path: entry.path,
            title: entry.title,
            owner: entry.owner,
            kind: entry.kind,
            currentHash: entry.contentHash
        )
    }
}

private extension Sequence where Element == AssetChange {
    func sortedByPath() -> [AssetChange] {
        sorted { left, right in
            left.path.localizedCaseInsensitiveCompare(right.path) == .orderedAscending
        }
    }
}

private extension Sequence where Element == ScanSnapshotEntry {
    func sortedByPath() -> [ScanSnapshotEntry] {
        sorted { left, right in
            left.path.localizedCaseInsensitiveCompare(right.path) == .orderedAscending
        }
    }
}
