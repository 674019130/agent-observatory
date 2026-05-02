import Foundation

public struct ScanSource: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var owner: AgentOwner
    public var label: String
    public var path: String
    public var scope: String
    public var maxDepth: Int
    public var isEnabled: Bool
    public var isCustom: Bool

    public init(
        id: String,
        owner: AgentOwner,
        label: String,
        path: String,
        scope: String,
        maxDepth: Int = 8,
        isEnabled: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.owner = owner
        self.label = label
        self.path = path
        self.scope = scope
        self.maxDepth = maxDepth
        self.isEnabled = isEnabled
        self.isCustom = isCustom
    }

    public var url: URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    public var displayPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    public var scanRoot: ScanRoot {
        ScanRoot(owner: owner, label: label, url: url, scope: scope, maxDepth: maxDepth)
    }
}
