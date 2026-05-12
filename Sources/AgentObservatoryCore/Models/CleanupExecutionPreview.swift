import Foundation

public struct CleanupExecutionPreview: Codable, Equatable, Sendable {
    public let goal: CleanupReviewGoal
    public let groupCount: Int
    public let affectedAssetCount: Int
    public let executableGroupCount: Int
    public let executableAssetCount: Int
    public let archiveCount: Int
    public let hideCount: Int
    public let mergeArchiveCount: Int
    public let manualGroupCount: Int

    public init(session: CleanupReviewSession) {
        self.goal = session.goal
        self.groupCount = session.groups.count
        self.affectedAssetCount = Set(session.groups.flatMap(\.assetPaths)).count
        self.executableGroupCount = session.groups.filter(\.canApplyAutomatically).count
        self.executableAssetCount = Set(session.groups.flatMap(\.automaticApplyAssetPaths)).count
        self.archiveCount = Self.assetCount(for: .archive, in: session.groups)
        self.hideCount = Self.assetCount(for: .hide, in: session.groups)
        self.mergeArchiveCount = Self.assetCount(for: .merge, in: session.groups)
        self.manualGroupCount = session.groups.filter { !$0.canApplyAutomatically }.count
    }

    public var hasExecutableActions: Bool {
        executableAssetCount > 0
    }

    private static func assetCount(for action: CleanupReviewAction, in groups: [CleanupReviewGroup]) -> Int {
        groups
            .filter { $0.action == action && $0.canApplyAutomatically }
            .flatMap(\.automaticApplyAssetPaths)
            .count
    }
}
