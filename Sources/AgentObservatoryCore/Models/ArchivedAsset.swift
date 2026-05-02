import Foundation

public struct ArchivedAsset: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let originalPath: String
    public let archivedPath: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let title: String
    public let contentHash: String
    public let archivedAt: Date
    public let reason: String

    public init(
        id: String = UUID().uuidString,
        originalPath: String,
        archivedPath: String,
        owner: AgentOwner,
        kind: AssetKind,
        title: String,
        contentHash: String,
        archivedAt: Date = Date(),
        reason: String
    ) {
        self.id = id
        self.originalPath = originalPath
        self.archivedPath = archivedPath
        self.owner = owner
        self.kind = kind
        self.title = title
        self.contentHash = contentHash
        self.archivedAt = archivedAt
        self.reason = reason
    }

    public var displayOriginalPath: String {
        originalPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    public var displayArchivedPath: String {
        archivedPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
