import Foundation

public struct DashboardSummary: Equatable, Sendable {
    public let indexHealth: DashboardIndexHealth
    public let topRisks: [DashboardRiskItem]
    public let drift: DashboardDriftSummary
    public let recentChanges: AssetChangeSummary
    public let dependencyHotspots: [DashboardDependencyHotspot]
    public let aiCoverage: DashboardAICoverage

    public init(
        indexHealth: DashboardIndexHealth,
        topRisks: [DashboardRiskItem],
        drift: DashboardDriftSummary,
        recentChanges: AssetChangeSummary,
        dependencyHotspots: [DashboardDependencyHotspot],
        aiCoverage: DashboardAICoverage
    ) {
        self.indexHealth = indexHealth
        self.topRisks = topRisks
        self.drift = drift
        self.recentChanges = recentChanges
        self.dependencyHotspots = dependencyHotspots
        self.aiCoverage = aiCoverage
    }

    public static let empty = DashboardSummary(
        indexHealth: DashboardIndexHealth(
            totalAssets: 0,
            warningCount: 0,
            activeSourceCount: 0,
            existingSourceCount: 0,
            isStale: false
        ),
        topRisks: [],
        drift: DashboardDriftSummary(same: 0, changed: 0, missingCounterpart: 0),
        recentChanges: .empty,
        dependencyHotspots: [],
        aiCoverage: DashboardAICoverage(explained: 0, missing: 0)
    )
}

public struct DashboardIndexHealth: Equatable, Sendable {
    public let totalAssets: Int
    public let warningCount: Int
    public let activeSourceCount: Int
    public let existingSourceCount: Int
    public let isStale: Bool

    public init(totalAssets: Int, warningCount: Int, activeSourceCount: Int, existingSourceCount: Int, isStale: Bool) {
        self.totalAssets = totalAssets
        self.warningCount = warningCount
        self.activeSourceCount = activeSourceCount
        self.existingSourceCount = existingSourceCount
        self.isStale = isStale
    }
}

public struct DashboardRiskItem: Identifiable, Equatable, Sendable {
    public var id: String { "\(assetPath)-\(category.rawValue)-\(message)" }
    public let assetPath: String
    public let assetTitle: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let category: DashboardRiskCategory
    public let severity: DashboardRiskSeverity
    public let message: String
    public let score: Int

    public init(
        assetPath: String,
        assetTitle: String,
        owner: AgentOwner,
        kind: AssetKind,
        category: DashboardRiskCategory,
        severity: DashboardRiskSeverity,
        message: String,
        score: Int
    ) {
        self.assetPath = assetPath
        self.assetTitle = assetTitle
        self.owner = owner
        self.kind = kind
        self.category = category
        self.severity = severity
        self.message = message
        self.score = score
    }
}

public enum DashboardRiskCategory: String, Codable, Equatable, Sendable {
    case missingDependency = "Missing Dependency"
    case staleReference = "Stale Reference"
    case sensitiveFile = "Sensitive File"
    case unreadable = "Unreadable"
    case stalePath = "Stale Path"
    case duplicate = "Duplicate"
    case largeFile = "Large File"
    case needsSummary = "Needs Summary"
}

public enum DashboardRiskSeverity: String, Codable, Equatable, Sendable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

public struct DashboardDriftSummary: Equatable, Sendable {
    public let same: Int
    public let changed: Int
    public let missingCounterpart: Int

    public init(same: Int, changed: Int, missingCounterpart: Int) {
        self.same = same
        self.changed = changed
        self.missingCounterpart = missingCounterpart
    }

    public var total: Int {
        same + changed + missingCounterpart
    }
}

public struct DashboardDependencyHotspot: Identifiable, Equatable, Sendable {
    public var id: String { assetPath }
    public let assetPath: String
    public let assetTitle: String
    public let owner: AgentOwner
    public let kind: AssetKind
    public let incomingCount: Int
    public let missingOutgoingCount: Int
    public let staleReferenceCount: Int

    public init(
        assetPath: String,
        assetTitle: String,
        owner: AgentOwner,
        kind: AssetKind,
        incomingCount: Int,
        missingOutgoingCount: Int,
        staleReferenceCount: Int
    ) {
        self.assetPath = assetPath
        self.assetTitle = assetTitle
        self.owner = owner
        self.kind = kind
        self.incomingCount = incomingCount
        self.missingOutgoingCount = missingOutgoingCount
        self.staleReferenceCount = staleReferenceCount
    }

    public var score: Int {
        incomingCount * 4 + missingOutgoingCount * 5 + staleReferenceCount * 2
    }
}

public struct DashboardAICoverage: Equatable, Sendable {
    public let explained: Int
    public let missing: Int

    public init(explained: Int, missing: Int) {
        self.explained = explained
        self.missing = missing
    }

    public var total: Int {
        explained + missing
    }

    public var ratio: Double {
        guard total > 0 else { return 1 }
        return Double(explained) / Double(total)
    }
}
