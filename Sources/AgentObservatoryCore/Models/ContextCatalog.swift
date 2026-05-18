import Foundation

public enum AgentContextRole: String, CaseIterable, Codable, Sendable {
    case memory
    case capability
}

public enum AgentContextLayer: String, CaseIterable, Codable, Sendable {
    case global
    case project
    case workspace
    case shared
    case pluginProvided
    case configuration
    case session

    public var sortIndex: Int {
        switch self {
        case .global: 0
        case .project: 1
        case .workspace: 2
        case .shared: 3
        case .pluginProvided: 4
        case .configuration: 5
        case .session: 6
        }
    }
}

public enum AgentMemoryType: String, CaseIterable, Codable, Identifiable, Sendable {
    case longTerm
    case project
    case workspace
    case automation
    case preference
    case sessionHistory
    case shared
    case instructions
    case contextRules
    case pluginProvided

    public var id: String { rawValue }

    public var sortIndex: Int {
        switch self {
        case .longTerm: 0
        case .project: 1
        case .workspace: 2
        case .automation: 3
        case .preference: 4
        case .sessionHistory: 5
        case .shared: 6
        case .instructions: 7
        case .contextRules: 8
        case .pluginProvided: 9
        }
    }
}

public struct ContextCatalogItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID { asset.id }
    public let asset: AgentAsset
    public let role: AgentContextRole
    public let layer: AgentContextLayer
    public let memoryType: AgentMemoryType?
    public let surfaces: [AgentOwner]
    public let loadRoute: ContextLoadRoute

    public init(
        asset: AgentAsset,
        role: AgentContextRole,
        layer: AgentContextLayer,
        memoryType: AgentMemoryType? = nil,
        surfaces: [AgentOwner],
        loadRoute: ContextLoadRoute
    ) {
        self.asset = asset
        self.role = role
        self.layer = layer
        self.memoryType = memoryType
        self.surfaces = surfaces
        self.loadRoute = loadRoute
    }
}

public struct ContextAssemblyStep: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(surface.rawValue)-\(role.rawValue)-\(layer.rawValue)" }
    public let surface: AgentOwner
    public let role: AgentContextRole
    public let layer: AgentContextLayer
    public let items: [ContextCatalogItem]

    public init(
        surface: AgentOwner,
        role: AgentContextRole,
        layer: AgentContextLayer,
        items: [ContextCatalogItem]
    ) {
        self.surface = surface
        self.role = role
        self.layer = layer
        self.items = items
    }
}

public struct ContextCapabilityGroup: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let rootPath: String
    public let groupingBasis: ContextCapabilityGroupingBasis
    public let origin: SkillInstallOrigin?
    public let primaryKind: AssetKind
    public let kindCounts: [AssetKind: Int]
    public let owners: [AgentOwner]
    public let surfaces: [AgentOwner]
    public let items: [ContextCatalogItem]

    public init(
        id: String,
        title: String,
        subtitle: String,
        rootPath: String,
        groupingBasis: ContextCapabilityGroupingBasis,
        origin: SkillInstallOrigin?,
        primaryKind: AssetKind,
        kindCounts: [AssetKind: Int],
        owners: [AgentOwner],
        surfaces: [AgentOwner],
        items: [ContextCatalogItem]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.rootPath = rootPath
        self.groupingBasis = groupingBasis
        self.origin = origin
        self.primaryKind = primaryKind
        self.kindCounts = kindCounts
        self.owners = owners
        self.surfaces = surfaces
        self.items = items
    }
}

public struct ContextCapabilityGroupingBasis: Codable, Hashable, Sendable {
    public let kind: ContextCapabilityGroupingBasisKind
    public let sourceURL: String?
    public let sourceLocation: String?
    public let isRuntimeMerge: Bool

    public init(
        kind: ContextCapabilityGroupingBasisKind,
        sourceURL: String? = nil,
        sourceLocation: String? = nil,
        isRuntimeMerge: Bool = false
    ) {
        self.kind = kind
        self.sourceURL = sourceURL
        self.sourceLocation = sourceLocation
        self.isRuntimeMerge = isRuntimeMerge
    }

    public static func official(_ kind: ContextCapabilityGroupingBasisKind) -> ContextCapabilityGroupingBasis {
        ContextCapabilityGroupingBasis(
            kind: kind,
            sourceURL: kind.sourceURL,
            sourceLocation: kind.sourceLocation,
            isRuntimeMerge: false
        )
    }
}

public enum ContextCapabilityGroupingBasisKind: String, CaseIterable, Codable, Sendable {
    case skillDirectory
    case pluginBundle
    case repositorySkillDirectory
    case sameNameSkillCopies
    case skillNameFamily
    case mcpConfiguration
    case parentDirectory

    public var sourceURL: String? {
        switch self {
        case .skillDirectory, .repositorySkillDirectory, .skillNameFamily:
            return "https://agentskills.io/specification"
        case .pluginBundle:
            return "https://developers.openai.com/codex/plugins"
        case .sameNameSkillCopies:
            return "https://developers.openai.com/codex/skills"
        case .mcpConfiguration:
            return "https://developers.openai.com/codex/mcp"
        case .parentDirectory:
            return nil
        }
    }

    public var sourceLocation: String? {
        switch self {
        case .skillDirectory, .repositorySkillDirectory, .skillNameFamily:
            return "Agent Skills Specification > Directory structure"
        case .pluginBundle:
            return "Codex Plugins > Overview > A plugin can contain Skills"
        case .sameNameSkillCopies:
            return "Codex Skills > Where to save skills"
        case .mcpConfiguration:
            return "Codex MCP > Connect Codex to an MCP server"
        case .parentDirectory:
            return nil
        }
    }
}

public enum ContextCapabilityCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case userSkills
    case mcpTools
    case localCapabilities
    case officialCapabilities
    case otherCapabilities

    public var id: String { rawValue }

    public var sortIndex: Int {
        switch self {
        case .userSkills: 0
        case .mcpTools: 1
        case .localCapabilities: 2
        case .officialCapabilities: 3
        case .otherCapabilities: 4
        }
    }

    public var isLowPriority: Bool {
        self == .officialCapabilities || self == .otherCapabilities
    }
}

public struct ContextCapabilitySection: Identifiable, Codable, Hashable, Sendable {
    public var id: String { category.rawValue }
    public let category: ContextCapabilityCategory
    public let groups: [ContextCapabilityGroup]

    public var itemCount: Int {
        groups.reduce(0) { $0 + $1.items.count }
    }

    public init(
        category: ContextCapabilityCategory,
        groups: [ContextCapabilityGroup]
    ) {
        self.category = category
        self.groups = groups
    }
}

public struct ContextCatalog: Codable, Hashable, Sendable {
    public let memoryItems: [ContextCatalogItem]
    public let capabilityItems: [ContextCatalogItem]
    public let assemblySteps: [ContextAssemblyStep]

    public init(
        memoryItems: [ContextCatalogItem],
        capabilityItems: [ContextCatalogItem],
        assemblySteps: [ContextAssemblyStep]
    ) {
        self.memoryItems = memoryItems
        self.capabilityItems = capabilityItems
        self.assemblySteps = assemblySteps
    }

    public static let empty = ContextCatalog(memoryItems: [], capabilityItems: [], assemblySteps: [])

    public func memoryCount(for surface: AgentOwner) -> Int {
        memoryItems.filter { $0.surfaces.contains(surface) }.count
    }

    public func memoryCount(for surface: AgentOwner, type: AgentMemoryType) -> Int {
        memoryItems.filter { $0.surfaces.contains(surface) && $0.memoryType == type }.count
    }

    public func memoryItems(of type: AgentMemoryType) -> [ContextCatalogItem] {
        memoryItems.filter { $0.memoryType == type }
    }

    public func capabilityCount(for surface: AgentOwner) -> Int {
        capabilityItems.filter { $0.surfaces.contains(surface) }.count
    }

    public func assemblySteps(for surface: AgentOwner) -> [ContextAssemblyStep] {
        assemblySteps.filter { $0.surface == surface }
    }
}
