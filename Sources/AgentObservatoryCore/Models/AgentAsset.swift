import Foundation

public struct AgentAsset: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let path: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let scope: String
    public let title: String
    public let summary: String
    public let trigger: String?
    public let dependencies: [String]
    public let relatedFiles: [String]
    public let modifiedAt: Date?
    public let byteCount: Int64
    public let contentHash: String
    public let preview: String
    public var statusFlags: [AssetStatusFlag]

    public init(
        id: UUID = UUID(),
        path: String,
        owner: AgentOwner,
        kind: AssetKind,
        scope: String,
        title: String,
        summary: String,
        trigger: String? = nil,
        dependencies: [String] = [],
        relatedFiles: [String] = [],
        modifiedAt: Date? = nil,
        byteCount: Int64 = 0,
        contentHash: String,
        preview: String,
        statusFlags: [AssetStatusFlag] = []
    ) {
        self.id = id
        self.path = path
        self.owner = owner
        self.kind = kind
        self.scope = scope
        self.title = title
        self.summary = summary
        self.trigger = trigger
        self.dependencies = dependencies
        self.relatedFiles = relatedFiles
        self.modifiedAt = modifiedAt
        self.byteCount = byteCount
        self.contentHash = contentHash
        self.preview = preview
        self.statusFlags = statusFlags
    }

    public var displayPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    public var normalizedKey: String {
        "\(kind.rawValue.lowercased())::\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    public var normalizedTitleKey: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func matchesSearch(query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return true }

        let searchableText = [
            title,
            path,
            displayPath,
            owner.rawValue,
            owner.shortName,
            kind.rawValue,
            scope,
            summary,
            trigger ?? "",
            dependencies.joined(separator: " "),
            relatedFiles.joined(separator: " "),
            statusFlags.map(\.rawValue).joined(separator: " "),
            preview
        ]
        .joined(separator: "\n")
        .lowercased()

        return searchableText.contains(normalizedQuery)
    }
}
