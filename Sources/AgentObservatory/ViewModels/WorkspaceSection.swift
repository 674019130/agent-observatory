import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case triggerRadar = "Trigger Radar"
    case contextOverview = "Context Overview"
    case memories = "Memories"
    case capabilities = "Capabilities"
    case mcpTools = "MCP"
    case assembly = "Assembly"
    case systemPromptPreview = "System Prompt Preview"
    case dashboard = "Dashboard"
    case organizer = "Organizer"
    case assets = "Assets"
    case hidden = "Hidden"
    case archive = "Archive"

    var id: String { rawValue }
}
