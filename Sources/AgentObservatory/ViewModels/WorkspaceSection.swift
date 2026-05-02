import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case assets = "Assets"
    case hidden = "Hidden"
    case archive = "Archive"

    var id: String { rawValue }
}
