import Foundation

public enum SkillTriggerConflictSeverity: String, CaseIterable, Codable, Sendable {
    case high
    case medium
    case low

    public var sortIndex: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

public enum SkillTriggerConflictSignal: String, CaseIterable, Codable, Sendable {
    case sameName
    case sharedTriggerTerms
    case duplicateSummary
    case broadTrigger
    case sharedRuntimeSurface
    case userSkillOverlapsBundled
}

public struct SkillTriggerConflict: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let severity: SkillTriggerConflictSeverity
    public let score: Double
    public let primaryAsset: AgentAsset
    public let competingAsset: AgentAsset
    public let primaryRoute: ContextLoadRoute
    public let competingRoute: ContextLoadRoute
    public let sharedTerms: [String]
    public let signals: [SkillTriggerConflictSignal]

    public init(
        id: String,
        severity: SkillTriggerConflictSeverity,
        score: Double,
        primaryAsset: AgentAsset,
        competingAsset: AgentAsset,
        primaryRoute: ContextLoadRoute,
        competingRoute: ContextLoadRoute,
        sharedTerms: [String],
        signals: [SkillTriggerConflictSignal]
    ) {
        self.id = id
        self.severity = severity
        self.score = score
        self.primaryAsset = primaryAsset
        self.competingAsset = competingAsset
        self.primaryRoute = primaryRoute
        self.competingRoute = competingRoute
        self.sharedTerms = sharedTerms
        self.signals = signals
    }

    public var involvedAssets: [AgentAsset] {
        [primaryAsset, competingAsset]
    }

    public var sharedSurfaces: [AgentOwner] {
        let competingSurfaces = Set(competingRoute.surfaces)
        return primaryRoute.surfaces.filter { competingSurfaces.contains($0) }
    }
}
