import Foundation

public enum ContextLoadDestination: String, CaseIterable, Codable, Sendable {
    case systemPrompt
    case memoryBlock
    case projectContextBlock
    case workspaceContextBlock
    case pluginInstructionBlock
    case skillRegistry
    case commandRegistry
    case toolRegistry
    case pluginRegistry
    case configuration
    case sessionArchive
    case supportFile
    case indexOnly

    public var isPromptMaterial: Bool {
        switch self {
        case .systemPrompt, .memoryBlock, .projectContextBlock, .workspaceContextBlock, .pluginInstructionBlock:
            true
        case .skillRegistry, .commandRegistry, .toolRegistry, .pluginRegistry, .configuration, .sessionArchive, .supportFile, .indexOnly:
            false
        }
    }
}

public enum ContextLoadTrigger: String, CaseIterable, Codable, Sendable {
    case globalStartup
    case projectDiscovery
    case workspaceSource
    case pluginDiscovery
    case skillDiscovery
    case commandDiscovery
    case mcpConfiguration
    case settingsConfiguration
    case sessionHistory
    case supportFileReference
    case observatoryIndex
}

public enum SkillInstallOrigin: String, CaseIterable, Codable, Sendable {
    case preset
    case officialPlugin
    case userInstalled
    case projectLocal
    case unknown

    public var sortIndex: Int {
        switch self {
        case .preset: 0
        case .officialPlugin: 1
        case .userInstalled: 2
        case .projectLocal: 3
        case .unknown: 4
        }
    }

    public var isBundled: Bool {
        switch self {
        case .preset, .officialPlugin:
            true
        case .userInstalled, .projectLocal, .unknown:
            false
        }
    }
}

public struct ContextLoadRoute: Codable, Hashable, Sendable {
    public let role: AgentContextRole?
    public let layer: AgentContextLayer
    public let memoryType: AgentMemoryType?
    public let surfaces: [AgentOwner]
    public let destination: ContextLoadDestination
    public let trigger: ContextLoadTrigger
    public let skillInstallOrigin: SkillInstallOrigin?

    public init(
        role: AgentContextRole?,
        layer: AgentContextLayer,
        memoryType: AgentMemoryType? = nil,
        surfaces: [AgentOwner],
        destination: ContextLoadDestination,
        trigger: ContextLoadTrigger,
        skillInstallOrigin: SkillInstallOrigin? = nil
    ) {
        self.role = role
        self.layer = layer
        self.memoryType = memoryType
        self.surfaces = surfaces
        self.destination = destination
        self.trigger = trigger
        self.skillInstallOrigin = skillInstallOrigin
    }
}
