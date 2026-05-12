import Foundation

public enum AIAuditOperation: String, Codable, Sendable {
    case assetExplanation
    case organizationPlan
}

public enum AIAuditStatus: String, Codable, Sendable {
    case started
    case succeeded
    case failed
    case cancelled
}

public struct AIAuditRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let operation: AIAuditOperation
    public var status: AIAuditStatus
    public let model: String
    public let baseURL: String
    public let assetCount: Int
    public var message: String
    public let createdAt: Date
    public var finishedAt: Date?

    public init(
        id: String = UUID().uuidString,
        operation: AIAuditOperation,
        status: AIAuditStatus,
        model: String,
        baseURL: String,
        assetCount: Int,
        message: String,
        createdAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.operation = operation
        self.status = status
        self.model = model
        self.baseURL = baseURL
        self.assetCount = assetCount
        self.message = message
        self.createdAt = createdAt
        self.finishedAt = finishedAt
    }
}

public struct AIAuditLog: Codable, Equatable, Sendable {
    public var records: [AIAuditRecord]

    public init(records: [AIAuditRecord] = []) {
        self.records = records
    }

    public mutating func add(_ record: AIAuditRecord) {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        records = Array(records.prefix(50))
    }

    public mutating func replace(_ record: AIAuditRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            add(record)
            return
        }
        records[index] = record
    }
}
