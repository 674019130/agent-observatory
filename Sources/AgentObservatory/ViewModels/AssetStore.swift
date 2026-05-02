import AgentObservatoryCore
import Combine
import Foundation

@MainActor
final class AssetStore: ObservableObject {
    @Published private(set) var assets: [AgentAsset] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var scanProgress: ScanProgress?
    @Published private(set) var isIndexStale = false
    @Published private(set) var lastFileEventDate: Date?
    @Published private(set) var lastFileEventPaths: [String] = []
    @Published private(set) var lastChangeSummary: AssetChangeSummary = .empty
    @Published private(set) var managementState: AssetManagementState
    @Published private(set) var dashboardSummary: DashboardSummary = .empty
    @Published var managementError: String?
    @Published var selectedSection: WorkspaceSection = .dashboard
    @Published var scanSources: [ScanSource]
    @Published var selectedOwner: AgentOwner?
    @Published var selectedKind: AssetKind?
    @Published var selectedHealth: HealthFilter?
    @Published var selectedAssetID: AgentAsset.ID?
    @Published var searchText = ""
    @Published var aiSummaries: [String: String]
    @Published var aiErrors: [String: String] = [:]
    @Published var enrichingAssetID: AgentAsset.ID?
    @Published var appLanguage = AppLanguage.fromStoredValue(UserDefaults.standard.string(forKey: "appLanguage"))
    @Published var openAIModel = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4.1-mini"
    @Published var openAIKey = APIKeyStore.shared.loadOpenAIKey()

    private static let scanSourcesDefaultsKey = "scanSources.v2"
    private static let managementStateDefaultsKey = "assetManagementState.v1"
    private static let appLanguageDefaultsKey = "appLanguage"

    private let scanner: FileSystemAssetScanner
    private let archiveService: AssetArchiveService
    private let enricher = OpenAIEnricher()
    private let summaryCache: SummaryCache
    private let watcher = SourceFileWatcher()
    private var activeScanID: UUID?
    private var cancellationToken: ScanCancellationToken?
    private var enrichmentTask: Task<Void, Never>?
    private var lastSnapshot: ScanSnapshot?

    init(
        scanner: FileSystemAssetScanner = FileSystemAssetScanner(),
        archiveService: AssetArchiveService = AssetArchiveService(),
        summaryCache: SummaryCache = SummaryCache(url: SummaryCache.defaultURL)
    ) {
        self.scanner = scanner
        self.archiveService = archiveService
        self.summaryCache = summaryCache
        self.scanSources = Self.loadScanSources(defaultSources: scanner.defaultSources())
        self.managementState = Self.loadManagementState()
        self.aiSummaries = (try? summaryCache.loadSummaries()) ?? [:]
        rebuildDashboardSummary()
    }

    deinit {
        cancellationToken?.cancel()
        enrichmentTask?.cancel()
        watcher.stop()
    }

    var summary: ScanSummary {
        ScanSummary(assets: visibleAssets)
    }

    var visibleAssets: [AgentAsset] {
        managementState.visibleAssets(from: assets)
    }

    var hiddenAssetCount: Int {
        managementState.hiddenAssetPaths.count
    }

    var archivedAssetCount: Int {
        managementState.archivedAssets.count
    }

    var archivedAssets: [ArchivedAsset] {
        managementState.archivedAssets
    }

    var hiddenAssets: [AgentAsset] {
        managementState.hiddenAssets(from: assets)
    }

    var filteredAssets: [AgentAsset] {
        visibleAssets.filter { asset in
            let ownerMatches = selectedOwner == nil || asset.owner == selectedOwner
            let kindMatches = selectedKind == nil || asset.kind == selectedKind
            let healthMatches = selectedHealth?.matches(asset) ?? true
            let queryMatches = asset.matchesSearch(query: searchText)
            return ownerMatches && kindMatches && healthMatches && queryMatches
        }
    }

    var selectedAsset: AgentAsset? {
        guard let selectedAssetID else { return filteredAssets.first }
        return visibleAssets.first { $0.id == selectedAssetID } ?? filteredAssets.first
    }

    var activeScanSources: [ScanSource] {
        scanSources.filter(\.isEnabled)
    }

    var existingScanSourceCount: Int {
        scanSources.filter { FileManager.default.fileExists(atPath: $0.url.path) }.count
    }

    var isWatchingSources: Bool {
        !activeScanSources.isEmpty
    }

    func healthCount(for filter: HealthFilter) -> Int {
        visibleAssets.filter { filter.matches($0) }.count
    }

    func sourceExists(_ source: ScanSource) -> Bool {
        FileManager.default.fileExists(atPath: source.url.path)
    }

    func t(_ key: L10n.Key) -> String {
        L10n.text(key, language: appLanguage)
    }

    func resetFilters() {
        selectedOwner = nil
        selectedKind = nil
        selectedHealth = nil
        searchText = ""
        selectedAssetID = filteredAssets.first?.id
        selectedSection = .assets
    }

    func showDashboard() {
        selectedSection = .dashboard
    }

    func showAssets() {
        selectedSection = .assets
    }

    func showArchive() {
        selectedSection = .archive
    }

    func showHidden() {
        selectedSection = .hidden
        selectedAssetID = nil
    }

    func scan() {
        guard !isScanning else { return }

        let scanID = UUID()
        let token = ScanCancellationToken()
        let sources = scanSources
        let previousSelectedPath = selectedAsset?.path
        activeScanID = scanID
        cancellationToken = token
        isScanning = true
        scanProgress = ScanProgress(
            phase: .preparing,
            sourceLabel: "All Sources",
            rootsCompleted: 0,
            rootCount: sources.filter(\.isEnabled).count,
            message: "Preparing scan roots"
        )

        DispatchQueue.global(qos: .userInitiated).async { [scanID, sources, token] in
            let scanned = FileSystemAssetScanner().scan(
                sources: sources,
                progress: { progress in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.activeScanID == scanID else { return }
                        self.scanProgress = progress
                    }
                },
                cancellationToken: token
            )

            DispatchQueue.main.async { [weak self] in
                guard let self, self.activeScanID == scanID else { return }
                self.cancellationToken = nil

                if token.isCancelled {
                    self.isScanning = false
                    self.scanProgress = ScanProgress(
                        phase: .cancelled,
                        sourceLabel: "All Sources",
                        rootsCompleted: self.scanProgress?.rootsCompleted ?? 0,
                        rootCount: self.scanProgress?.rootCount ?? 0,
                        filesVisited: self.scanProgress?.filesVisited ?? 0,
                        filesDiscovered: self.scanProgress?.filesDiscovered ?? 0,
                        filesProcessed: self.scanProgress?.filesProcessed ?? 0,
                        assetsFound: self.scanProgress?.assetsFound ?? self.assets.count,
                        directoriesSkipped: self.scanProgress?.directoriesSkipped ?? 0,
                        readErrors: self.scanProgress?.readErrors ?? 0,
                        message: "Scan cancelled"
                    )
                    return
                }

                let visibleScanned = self.managementState.visibleAssets(from: scanned)
                let currentSnapshot = ScanSnapshot(assets: visibleScanned)
                self.lastChangeSummary = ScanSnapshot.diff(from: self.lastSnapshot, to: currentSnapshot)
                self.lastSnapshot = currentSnapshot
                self.assets = scanned
                self.lastScanDate = Date()
                self.isIndexStale = false
                self.lastFileEventPaths = []
                self.isScanning = false
                self.scanProgress = ScanProgress(
                    phase: .completed,
                    sourceLabel: "All Sources",
                    rootsCompleted: self.scanProgress?.rootCount ?? 0,
                    rootCount: self.scanProgress?.rootCount ?? 0,
                    filesVisited: self.scanProgress?.filesVisited ?? 0,
                    filesDiscovered: self.scanProgress?.filesDiscovered ?? 0,
                    filesProcessed: self.scanProgress?.filesProcessed ?? 0,
                        assetsFound: visibleScanned.count,
                    directoriesSkipped: self.scanProgress?.directoriesSkipped ?? 0,
                    readErrors: self.scanProgress?.readErrors ?? 0,
                    rootProgress: 1,
                    message: "Scan completed"
                )
                self.rebuildDashboardSummary()

                if let previousSelectedPath,
                   let preserved = visibleScanned.first(where: { $0.path == previousSelectedPath }) {
                    self.selectedAssetID = preserved.id
                } else {
                    self.selectedAssetID = self.filteredAssets.first?.id
                }
                self.startWatchingSources()
            }
        }
    }

    func cancelScan() {
        guard isScanning else { return }
        cancellationToken?.cancel()
        isScanning = false
        scanProgress = ScanProgress(
            phase: .cancelled,
            sourceLabel: scanProgress?.sourceLabel ?? "All Sources",
            currentPath: scanProgress?.currentPath ?? "",
            rootsCompleted: scanProgress?.rootsCompleted ?? 0,
            rootCount: scanProgress?.rootCount ?? 0,
            filesVisited: scanProgress?.filesVisited ?? 0,
            filesDiscovered: scanProgress?.filesDiscovered ?? 0,
            filesProcessed: scanProgress?.filesProcessed ?? 0,
            assetsFound: scanProgress?.assetsFound ?? assets.count,
            directoriesSkipped: scanProgress?.directoriesSkipped ?? 0,
            readErrors: scanProgress?.readErrors ?? 0,
            message: "Scan cancelled"
        )
        activeScanID = nil
    }

    func toggleSource(_ source: ScanSource) {
        guard let index = scanSources.firstIndex(where: { $0.id == source.id }) else { return }
        scanSources[index].isEnabled.toggle()
        saveScanSources()
        startWatchingSources()
        isIndexStale = true
        rebuildDashboardSummary()
    }

    func addCustomSource(url: URL) {
        let id = "custom-\(StableHash.hash(url.standardizedFileURL.path))"
        guard !scanSources.contains(where: { $0.id == id }) else { return }

        scanSources.append(
            ScanSource(
                id: id,
                owner: .project,
                label: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                path: url.path,
                scope: "custom",
                maxDepth: 8,
                isEnabled: true,
                isCustom: true
            )
        )
        saveScanSources()
        startWatchingSources()
        isIndexStale = true
        rebuildDashboardSummary()
    }

    func removeSource(_ source: ScanSource) {
        guard source.isCustom else { return }
        scanSources.removeAll { $0.id == source.id }
        saveScanSources()
        startWatchingSources()
        isIndexStale = true
        rebuildDashboardSummary()
    }

    func resetScanSources() {
        scanSources = scanner.defaultSources()
        saveScanSources()
        startWatchingSources()
        isIndexStale = true
        rebuildDashboardSummary()
    }

    func hideSelectedAsset() {
        guard let asset = selectedAsset else { return }
        hideAsset(asset)
    }

    func hideAsset(_ asset: AgentAsset) {
        managementState.hide(path: asset.path)
        saveManagementState()
        rebuildDashboardSummary()
        if selectedAssetID == asset.id {
            selectedAssetID = filteredAssets.first?.id
        }
    }

    func unhideAllAssets() {
        managementState.unhideAll()
        saveManagementState()
        rebuildDashboardSummary()
        selectedAssetID = filteredAssets.first?.id
    }

    func unhideAsset(_ asset: AgentAsset) {
        managementState.unhide(path: asset.path)
        saveManagementState()
        managementError = nil
        rebuildDashboardSummary()
        if selectedAssetID == asset.id {
            selectedAssetID = nil
        }
    }

    func archiveSelectedAsset(reason: String) {
        guard let asset = selectedAsset else { return }
        archiveAsset(asset, reason: reason)
    }

    func archiveAsset(_ asset: AgentAsset, reason: String) {
        do {
            let archived = try archiveService.archive(asset: asset, reason: reason)
            managementState.hiddenAssetPaths.remove(asset.path)
            managementState.addArchive(archived)
            saveManagementState()
            assets.removeAll { $0.path == asset.path }
            managementError = nil
            markManagedFileEvent(path: asset.path, message: "Archived \(asset.displayPath)")
            rebuildDashboardSummary()
            if selectedAssetID == asset.id {
                selectedAssetID = filteredAssets.first?.id
            }
        } catch {
            managementError = error.localizedDescription
        }
    }

    func restoreArchivedAsset(_ archivedAsset: ArchivedAsset) {
        do {
            try archiveService.restore(archivedAsset)
            managementState.removeArchive(id: archivedAsset.id)
            saveManagementState()
            managementError = nil
            markManagedFileEvent(path: archivedAsset.originalPath, message: "Restored \(archivedAsset.displayOriginalPath)")
            rebuildDashboardSummary()
        } catch {
            managementError = error.localizedDescription
        }
    }

    func startWatchingSources() {
        watcher.start(sources: activeScanSources) { [weak self] paths in
            self?.recordFileEvents(paths)
        }
    }

    func select(owner: AgentOwner?) {
        selectedSection = .assets
        selectedOwner = owner
        selectedAssetID = filteredAssets.first?.id
    }

    func select(kind: AssetKind?) {
        selectedSection = .assets
        selectedKind = kind
        selectedAssetID = filteredAssets.first?.id
    }

    func select(health: HealthFilter?) {
        selectedSection = .assets
        selectedHealth = health
        selectedAssetID = filteredAssets.first?.id
    }

    func saveOpenAISettings() {
        UserDefaults.standard.set(openAIModel, forKey: "openAIModel")
        do {
            try APIKeyStore.shared.saveOpenAIKey(openAIKey)
        } catch {
            aiErrors["settings"] = error.localizedDescription
        }
    }

    func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        saveGeneralSettings()
    }

    func saveGeneralSettings() {
        UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageDefaultsKey)
    }

    func enrichSelectedAsset() {
        guard let asset = selectedAsset else { return }
        guard !asset.statusFlags.contains(.secretRisk) else {
            aiErrors[asset.contentHash] = "Sensitive files are not sent to OpenAI."
            return
        }

        enrichmentTask?.cancel()
        enrichingAssetID = asset.id
        aiErrors[asset.contentHash] = nil
        let apiKey = openAIKey
        let model = openAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : openAIModel

        enrichmentTask = Task { [weak self, asset, apiKey, model, enricher, summaryCache] in
            defer {
                Task { @MainActor [weak self] in
                    guard let self, self.enrichingAssetID == asset.id else { return }
                    self.enrichingAssetID = nil
                    self.enrichmentTask = nil
                }
            }

            do {
                let summary = try await enricher.summarize(
                    asset: asset,
                    apiKey: apiKey,
                    model: model
                )
                guard !Task.isCancelled else { return }
                guard let self else { return }
                aiSummaries[asset.contentHash] = summary
                try? summaryCache.save(summary: summary, forContentHash: asset.contentHash)
                rebuildDashboardSummary()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                aiErrors[asset.contentHash] = error.localizedDescription
            }
        }
    }

    func relatedAssets(for asset: AgentAsset) -> [AgentAsset] {
        assets.filter { candidate in
            candidate.id != asset.id
                && (
                    candidate.normalizedKey == asset.normalizedKey
                    || candidate.normalizedTitleKey == asset.normalizedTitleKey
                    || (candidate.title.localizedCaseInsensitiveCompare(asset.title) == .orderedSame && candidate.owner != asset.owner)
                )
        }
    }

    func comparison(for asset: AgentAsset) -> AssetComparison {
        AssetDiffAnalyzer().comparison(for: asset, in: assets)
    }

    func impact(for asset: AgentAsset) -> AssetImpact {
        AssetImpactAnalyzer().impact(for: asset, in: assets)
    }

    func selectAsset(path: String?) {
        guard let path,
              let asset = assets.first(where: { $0.path == path }) else {
            return
        }
        selectedSection = .assets
        selectedAssetID = asset.id
    }

    func openRisk(_ risk: DashboardRiskItem) {
        selectAsset(path: risk.assetPath)
    }

    func openHotspot(_ hotspot: DashboardDependencyHotspot) {
        selectAsset(path: hotspot.assetPath)
    }

    func openChange(_ change: AssetChange) {
        selectAsset(path: change.path)
    }

    private func saveScanSources() {
        guard let data = try? JSONEncoder().encode(scanSources) else { return }
        UserDefaults.standard.set(data, forKey: Self.scanSourcesDefaultsKey)
    }

    private func saveManagementState() {
        guard let data = try? JSONEncoder().encode(managementState) else { return }
        UserDefaults.standard.set(data, forKey: Self.managementStateDefaultsKey)
    }

    private func rebuildDashboardSummary() {
        dashboardSummary = DashboardAnalyzer().summary(
            assets: visibleAssets,
            changeSummary: lastChangeSummary,
            aiSummaries: aiSummaries,
            activeSourceCount: activeScanSources.count,
            existingSourceCount: existingScanSourceCount,
            isIndexStale: isIndexStale
        )
    }

    private func markManagedFileEvent(path: String, message: String) {
        isIndexStale = true
        lastFileEventDate = Date()
        lastFileEventPaths = [path.replacingOccurrences(of: NSHomeDirectory(), with: "~")]
        scanProgress = ScanProgress(
            phase: .completed,
            sourceLabel: "Management",
            currentPath: path.replacingOccurrences(of: NSHomeDirectory(), with: "~"),
            rootsCompleted: scanProgress?.rootsCompleted ?? 0,
            rootCount: scanProgress?.rootCount ?? 0,
            filesVisited: scanProgress?.filesVisited ?? 0,
            filesDiscovered: scanProgress?.filesDiscovered ?? 0,
            filesProcessed: scanProgress?.filesProcessed ?? 0,
            assetsFound: visibleAssets.count,
            directoriesSkipped: scanProgress?.directoriesSkipped ?? 0,
            readErrors: scanProgress?.readErrors ?? 0,
            message: message
        )
    }

    private func recordFileEvents(_ paths: [String]) {
        guard !isScanning else { return }
        let relevantPaths = ScanSourceEventFilter.relevantEventPaths(paths, sources: activeScanSources)
        guard !relevantPaths.isEmpty else { return }
        isIndexStale = true
        lastFileEventDate = Date()
        lastFileEventPaths = relevantPaths.map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
        rebuildDashboardSummary()
    }

    private static func loadScanSources(defaultSources: [ScanSource]) -> [ScanSource] {
        guard let data = UserDefaults.standard.data(forKey: scanSourcesDefaultsKey),
              let savedSources = try? JSONDecoder().decode([ScanSource].self, from: data) else {
            return defaultSources
        }

        let savedByID = Dictionary(uniqueKeysWithValues: savedSources.map { ($0.id, $0) })
        var merged = defaultSources.map { source in
            guard let saved = savedByID[source.id] else { return source }
            var updated = source
            updated.label = saved.label
            updated.maxDepth = saved.maxDepth
            updated.isEnabled = saved.isEnabled
            return updated
        }

        let defaultIDs = Set(defaultSources.map(\.id))
        merged.append(contentsOf: savedSources.filter { $0.isCustom && !defaultIDs.contains($0.id) })
        return merged
    }

    private static func loadManagementState() -> AssetManagementState {
        guard let data = UserDefaults.standard.data(forKey: managementStateDefaultsKey),
              let state = try? JSONDecoder().decode(AssetManagementState.self, from: data) else {
            return AssetManagementState()
        }
        return state
    }
}
