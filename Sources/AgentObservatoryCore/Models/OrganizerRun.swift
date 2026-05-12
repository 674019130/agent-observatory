import Foundation

public enum OrganizerRunStatus: String, Codable, Sendable {
    case empty
    case ready
    case applied
}

public enum OrganizerActionPackKind: String, Codable, Sendable {
    case mergeDuplicates
    case hideNoise
    case reviewSensitive
    case reviewUnreadable
    case clarifyUnknown
    case reviewStalePaths
}

public enum OrganizerActionPackRisk: String, Codable, Comparable, Sendable {
    case low
    case medium
    case high

    public static func < (left: OrganizerActionPackRisk, right: OrganizerActionPackRisk) -> Bool {
        left.priority < right.priority
    }

    private var priority: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }
}

public struct OrganizerActionPack: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: OrganizerActionPackKind
    public let title: String
    public let summary: String
    public let risk: OrganizerActionPackRisk
    public let assetPaths: [String]
    public let executableAssetPaths: [String]
    public let isReversible: Bool
    public let requiresHumanReview: Bool

    public init(
        id: String,
        kind: OrganizerActionPackKind,
        title: String,
        summary: String,
        risk: OrganizerActionPackRisk,
        assetPaths: [String],
        executableAssetPaths: [String],
        isReversible: Bool,
        requiresHumanReview: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.risk = risk
        self.assetPaths = assetPaths
        self.executableAssetPaths = executableAssetPaths
        self.isReversible = isReversible
        self.requiresHumanReview = requiresHumanReview
    }

    public var canExecuteAutomatically: Bool {
        !requiresHumanReview && !executableAssetPaths.isEmpty
    }
}

public struct OrganizerRun: Codable, Equatable, Sendable {
    public let status: OrganizerRunStatus
    public let title: String
    public let summary: String
    public let totalAssetCount: Int
    public let duplicateAssetCount: Int
    public let noiseAssetCount: Int
    public let sensitiveAssetCount: Int
    public let stalePathAssetCount: Int
    public let unclearAssetCount: Int
    public let actionPacks: [OrganizerActionPack]
    public let createdAt: Date

    public init(
        status: OrganizerRunStatus,
        title: String,
        summary: String,
        totalAssetCount: Int,
        duplicateAssetCount: Int,
        noiseAssetCount: Int,
        sensitiveAssetCount: Int,
        stalePathAssetCount: Int,
        unclearAssetCount: Int,
        actionPacks: [OrganizerActionPack],
        createdAt: Date = Date()
    ) {
        self.status = status
        self.title = title
        self.summary = summary
        self.totalAssetCount = totalAssetCount
        self.duplicateAssetCount = duplicateAssetCount
        self.noiseAssetCount = noiseAssetCount
        self.sensitiveAssetCount = sensitiveAssetCount
        self.stalePathAssetCount = stalePathAssetCount
        self.unclearAssetCount = unclearAssetCount
        self.actionPacks = actionPacks
        self.createdAt = createdAt
    }

    public var executablePacks: [OrganizerActionPack] {
        actionPacks.filter(\.canExecuteAutomatically)
    }

    public var hasExecutablePacks: Bool {
        !executablePacks.isEmpty
    }

    public static let empty = OrganizerRun(
        status: .empty,
        title: "",
        summary: "",
        totalAssetCount: 0,
        duplicateAssetCount: 0,
        noiseAssetCount: 0,
        sensitiveAssetCount: 0,
        stalePathAssetCount: 0,
        unclearAssetCount: 0,
        actionPacks: [],
        createdAt: Date(timeIntervalSince1970: 0)
    )
}
