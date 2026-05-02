import Foundation

public enum AssetStatusFlag: String, CaseIterable, Codable, Identifiable, Sendable {
    case duplicate = "Duplicate"
    case stalePath = "Stale Path"
    case hasScripts = "Has Scripts"
    case needsSummary = "Needs Summary"
    case secretRisk = "Secret Risk"
    case largeFile = "Large File"
    case unreadable = "Unreadable"

    public var id: String { rawValue }
}
