import AgentObservatoryCore
import Foundation

enum HealthFilter: String, CaseIterable, Identifiable {
    case warnings = "Warnings"
    case duplicates = "Duplicates"
    case stalePaths = "Stale Paths"
    case secrets = "Secrets"
    case unreadable = "Unreadable"
    case needsSummary = "Needs Summary"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .warnings: L10n.text(.warnings, language: language)
        case .duplicates: L10n.text(.duplicates, language: language)
        case .stalePaths: L10n.text(.stalePaths, language: language)
        case .secrets: L10n.text(.secrets, language: language)
        case .unreadable: L10n.statusFlag(.unreadable, language: language)
        case .needsSummary: L10n.statusFlag(.needsSummary, language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .warnings: "exclamationmark.triangle"
        case .duplicates: "rectangle.on.rectangle"
        case .stalePaths: "arrow.triangle.branch"
        case .secrets: "lock.trianglebadge.exclamationmark"
        case .unreadable: "xmark.octagon"
        case .needsSummary: "text.bubble"
        }
    }

    func matches(_ asset: AgentAsset) -> Bool {
        switch self {
        case .warnings:
            !asset.statusFlags.isEmpty
        case .duplicates:
            asset.statusFlags.contains(.duplicate)
        case .stalePaths:
            asset.statusFlags.contains(.stalePath)
        case .secrets:
            asset.statusFlags.contains(.secretRisk)
        case .unreadable:
            asset.statusFlags.contains(.unreadable)
        case .needsSummary:
            asset.statusFlags.contains(.needsSummary)
        }
    }
}
