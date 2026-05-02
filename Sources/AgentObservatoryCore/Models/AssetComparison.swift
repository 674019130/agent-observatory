import Foundation

public struct AssetComparison: Equatable, Sendable {
    public let base: AgentAsset
    public let counterpart: AgentAsset?
    public let rows: [AssetDiffRow]

    public init(base: AgentAsset, counterpart: AgentAsset?, rows: [AssetDiffRow]) {
        self.base = base
        self.counterpart = counterpart
        self.rows = rows
    }

    public var status: AssetComparisonStatus {
        guard counterpart != nil else { return .missingCounterpart }
        return rows.contains { $0.status != .same } ? .changed : .same
    }

    public var changedRowCount: Int {
        rows.filter { $0.status != .same }.count
    }
}

public enum AssetComparisonStatus: String, Codable, Equatable, Sendable {
    case same = "Same"
    case changed = "Changed"
    case missingCounterpart = "Missing Counterpart"
}

public struct AssetDiffRow: Identifiable, Equatable, Sendable {
    public var id: String { field }
    public let field: String
    public let leftValue: String
    public let rightValue: String
    public let status: AssetDiffRowStatus

    public init(field: String, leftValue: String, rightValue: String, status: AssetDiffRowStatus) {
        self.field = field
        self.leftValue = leftValue
        self.rightValue = rightValue
        self.status = status
    }
}

public enum AssetDiffRowStatus: String, Codable, Equatable, Sendable {
    case same = "Same"
    case changed = "Changed"
    case missingLeft = "Missing Left"
    case missingRight = "Missing Right"
}
