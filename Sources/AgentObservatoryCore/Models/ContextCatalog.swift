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
