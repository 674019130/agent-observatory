import Foundation

public enum OrganizationMapBuildDecision: Equatable, Sendable {
    case buildCurrentIndex
    case scanThenBuild
    case waitForScan
}

public struct OrganizationMapBuildPlanner: Sendable {
    public init() {}

    public func decision(assetCount: Int, isIndexStale: Bool, isScanning: Bool) -> OrganizationMapBuildDecision {
        if isScanning {
            return .waitForScan
        }

        if assetCount == 0 || isIndexStale {
            return .scanThenBuild
        }

        return .buildCurrentIndex
    }
}
