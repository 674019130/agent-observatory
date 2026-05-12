import Foundation

public enum ManagementOperationKind: String, Codable, Sendable {
    case hide
    case archive
    case mergeArchive
}

public enum ManagementOperationStatus: String, Codable, Sendable {
    case applied
    case failed
    case undone
    case undoFailed
}

public enum ManagementOperationSource: String, Codable, Sendable {
    case manual
    case cleanupReview
    case aiOrganizer
}

public struct ManagementOperationRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: ManagementOperationKind
    public var status: ManagementOperationStatus
    public let originalPath: String
    public let title: String
    public let archivedAsset: ArchivedAsset?
    public var message: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: ManagementOperationKind,
        status: ManagementOperationStatus,
        originalPath: String,
        title: String,
        archivedAsset: ArchivedAsset?,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.originalPath = originalPath
        self.title = title
        self.archivedAsset = archivedAsset
        self.message = message
        self.createdAt = createdAt
    }

    public var isUndoable: Bool {
        guard status == .applied || status == .undoFailed else { return false }
        switch kind {
        case .hide:
            return true
        case .archive, .mergeArchive:
            return archivedAsset != nil
        }
    }
}

public struct ManagementOperationBatch: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let source: ManagementOperationSource
    public let createdAt: Date
    public var records: [ManagementOperationRecord]

    public init(
        id: String = UUID().uuidString,
        title: String,
        source: ManagementOperationSource,
        createdAt: Date = Date(),
        records: [ManagementOperationRecord]
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.createdAt = createdAt
        self.records = records
    }

    public var appliedCount: Int {
        records.filter { $0.status == .applied }.count
    }

    public var failedCount: Int {
        records.filter { $0.status == .failed }.count
    }

    public var undoneCount: Int {
        records.filter { $0.status == .undone }.count
    }

    public var undoableCount: Int {
        records.filter(\.isUndoable).count
    }

    public var isFullyUndone: Bool {
        !records.isEmpty && records.allSatisfy { $0.status == .undone || $0.status == .failed }
    }

    public mutating func markRecord(id: ManagementOperationRecord.ID, status: ManagementOperationStatus, message: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = status
        records[index].message = message
    }
}
