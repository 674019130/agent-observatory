import Foundation

public enum AssetKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case skill = "Skill"
    case command = "Command"
    case memory = "Memory"
    case config = "Config"
    case rule = "Rule"
    case mcp = "MCP"
    case plugin = "Plugin"
    case instruction = "Instruction"
    case script = "Script"
    case session = "Session"
    case unknown = "Unknown"

    public var id: String { rawValue }
}
