import AgentObservatoryCore
import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AssetStore
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedPane)
                .frame(width: 190)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeader(pane: selectedPane)
                    paneContent
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selectedPane {
        case .general:
            GeneralSettingsPane()
        case .sources:
            SourcesSettingsPane()
        case .openAI:
            OpenAISettingsPane()
        case .management:
            ManagementSettingsPane()
        }
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case sources
    case openAI
    case management

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .sources: "folder.badge.gearshape"
        case .openAI: "sparkles"
        case .management: "archivebox"
        }
    }

    @MainActor
    func title(store: AssetStore) -> String {
        switch self {
        case .general: store.t(.general)
        case .sources: store.t(.sources)
        case .openAI: store.t(.openAI)
        case .management: store.t(.management)
        }
    }
}

private struct SettingsSidebar: View {
    @EnvironmentObject private var store: AssetStore
    @Binding var selection: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.t(.settingsTitle))
                    .font(.title3.weight(.semibold))
                Text(store.t(.settingsSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)

            VStack(spacing: 3) {
                ForEach(SettingsPane.allCases) { pane in
                    Button {
                        selection = pane
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: pane.icon)
                                .foregroundColor(selection == pane ? .accentColor : .secondary)
                                .frame(width: 18)
                            Text(pane.title(store: store))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selection == pane ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == pane ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .background(.bar)
    }
}

private struct SettingsHeader: View {
    @EnvironmentObject private var store: AssetStore
    let pane: SettingsPane

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: pane.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(pane.title(store: store))
                    .font(.system(size: 26, weight: .semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var subtitle: String {
        switch pane {
        case .general:
            store.t(.languageDescription)
        case .sources:
            store.t(.sourcesDescription)
        case .openAI:
            store.t(.openAIDescription)
        case .management:
            store.t(.archiveLocationDescription)
        }
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsPanel(title: store.t(.language), systemImage: "globe") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(store.t(.language), selection: Binding(
                        get: { store.appLanguage },
                        set: { store.setAppLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    Text(store.t(.languageDescription))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsPanel(title: store.t(.indexState), systemImage: "checkmark.seal") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    SettingsMetric(title: store.t(.currentIndex), value: store.isIndexStale ? store.t(.stale) : store.t(.indexCurrent), tint: store.isIndexStale ? .orange : .green)
                    SettingsMetric(title: store.t(.assets), value: "\(store.visibleAssets.count)", tint: .blue)
                    SettingsMetric(title: store.t(.activeSources), value: "\(store.activeScanSources.count)", tint: .teal)
                    SettingsMetric(title: store.t(.existingPaths), value: "\(store.existingScanSourceCount)", tint: .green)
                }

                Text(store.lastScanDate?.formatted(date: .abbreviated, time: .shortened) ?? store.t(.noScanYet))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SourcesSettingsPane: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        SettingsPanel(title: store.t(.sources), systemImage: "folder.badge.gearshape") {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t(.sourcesDescription))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(store.scanSources) { source in
                        ScanSourceSettingsRow(source: source)
                        if source.id != store.scanSources.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45))
                }

                HStack {
                    Button {
                        chooseFolder()
                    } label: {
                        Label(store.t(.addFolder), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        store.resetScanSources()
                    } label: {
                        Label(store.t(.resetDefaults), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = store.t(.addFolder)

        if panel.runModal() == .OK, let url = panel.url {
            store.addCustomSource(url: url)
        }
    }
}

private struct OpenAISettingsPane: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        SettingsPanel(title: store.t(.openAI), systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.t(.openAIDescription))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = store.aiErrors["settings"] {
                    ManagementErrorBanner(message: error)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t(.apiKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    SecureField(store.t(.apiKey), text: $store.openAIKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t(.modelPreset))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker(store.t(.modelPreset), selection: Binding(
                        get: { OpenAIModelPreset.allCases.first { $0.modelID == store.openAIModel }?.modelID ?? "custom" },
                        set: { value in
                            if let preset = OpenAIModelPreset.allCases.first(where: { $0.modelID == value }) {
                                store.openAIModel = preset.modelID
                            }
                        }
                    )) {
                        ForEach(OpenAIModelPreset.allCases) { preset in
                            Text(preset.title).tag(preset.modelID)
                        }
                        Text(store.t(.customModel)).tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 460)

                    Text(store.t(.model))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(store.t(.model), text: $store.openAIModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                    Text(store.t(.modelDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t(.baseURL))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(OpenAIConfiguration.defaultBaseURL, text: $store.openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                    Text(store.t(.openAIBaseURLDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Button {
                        store.saveOpenAISettings()
                    } label: {
                        Label(store.t(.save), systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

private struct ManagementSettingsPane: View {
    @EnvironmentObject private var store: AssetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsPanel(title: store.t(.management), systemImage: "archivebox") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    SettingsMetric(title: store.t(.archivedItems), value: "\(store.archivedAssetCount)", tint: .orange)
                    SettingsMetric(title: store.t(.hiddenItems), value: "\(store.hiddenAssetCount)", tint: .purple)
                }

                HStack {
                    Button {
                        store.showArchive()
                    } label: {
                        Label(store.t(.archiveCenter), systemImage: "archivebox")
                    }
                    .buttonStyle(.bordered)

                    if store.hiddenAssetCount > 0 {
                        Button {
                            store.unhideAllAssets()
                        } label: {
                            Label(store.t(.unhideAll), systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                }
            }

            SettingsPanel(title: store.t(.archiveLocation), systemImage: "externaldrive") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t(.archiveLocationDescription))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(archiveDisplayPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }
        }
    }

    private var archiveDisplayPath: String {
        AssetArchiveService.defaultArchiveRoot().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

private struct ScanSourceSettingsRow: View {
    @EnvironmentObject private var store: AssetStore
    let source: ScanSource

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { _ in store.toggleSource(source) }
            ))
            .labelsHidden()

            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.label)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    BadgeView(text: source.owner.shortName, tint: ownerTint)
                    if source.isCustom {
                        BadgeView(text: store.t(.custom), tint: .purple)
                    }
                }

                Text(source.displayPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            BadgeView(text: store.sourceExists(source) ? store.t(.exists) : store.t(.missing), tint: store.sourceExists(source) ? .green : .orange)

            if source.isCustom {
                Button {
                    store.removeSource(source)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(store.t(.removeCustomSource))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var icon: String {
        source.isEnabled ? "checkmark.circle.fill" : "circle"
    }

    private var tint: Color {
        guard source.isEnabled else { return .secondary }
        return store.sourceExists(source) ? .green : .orange
    }

    private var ownerTint: Color {
        switch source.owner {
        case .claude: .orange
        case .codex: .blue
        case .agents: .green
        case .project: .teal
        case .unknown: .secondary
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }
}

private struct SettingsMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
