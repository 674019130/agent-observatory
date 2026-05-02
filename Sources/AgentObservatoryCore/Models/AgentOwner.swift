import Foundation

public enum AgentOwner: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex"
    case agents = "Agents"
    case project = "Current Project"
    case unknown = "Unknown"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .agents: "Agents"
        case .project: "Project"
        case .unknown: "Unknown"
        }
    }
}
