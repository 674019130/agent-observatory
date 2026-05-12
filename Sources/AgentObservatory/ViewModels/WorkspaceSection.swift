import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case contextOverview = "Context Overview"
    case memories = "Memories"
    case capabilities = "Capabilities"
    case assembly = "Assembly"
    case dashboard = "Dashboard"
    case organizer = "Organizer"
    case assets = "Assets"
    case hidden = "Hidden"
    case archive = "Archive"

    var id: String { rawValue }
}
