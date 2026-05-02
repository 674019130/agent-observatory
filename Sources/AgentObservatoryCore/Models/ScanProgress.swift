import Foundation

public struct ScanProgress: Equatable, Sendable {
    public enum Phase: String, Sendable {
        case preparing = "Preparing"
        case collecting = "Collecting"
        case processing = "Processing"
        case finalizing = "Finalizing"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    public let phase: Phase
    public let sourceLabel: String
    public let currentPath: String
    public let rootsCompleted: Int
    public let rootCount: Int
    public let filesVisited: Int
    public let filesDiscovered: Int
    public let filesProcessed: Int
    public let assetsFound: Int
    public let directoriesSkipped: Int
    public let readErrors: Int
    public let rootProgress: Double?
    public let message: String

    public init(
        phase: Phase,
        sourceLabel: String,
        currentPath: String = "",
        rootsCompleted: Int,
        rootCount: Int,
        filesVisited: Int = 0,
        filesDiscovered: Int = 0,
        filesProcessed: Int = 0,
        assetsFound: Int = 0,
        directoriesSkipped: Int = 0,
        readErrors: Int = 0,
        rootProgress: Double? = nil,
        message: String
    ) {
        self.phase = phase
        self.sourceLabel = sourceLabel
        self.currentPath = currentPath
        self.rootsCompleted = rootsCompleted
        self.rootCount = rootCount
        self.filesVisited = filesVisited
        self.filesDiscovered = filesDiscovered
        self.filesProcessed = filesProcessed
        self.assetsFound = assetsFound
        self.directoriesSkipped = directoriesSkipped
        self.readErrors = readErrors
        self.rootProgress = rootProgress
        self.message = message
    }
}
