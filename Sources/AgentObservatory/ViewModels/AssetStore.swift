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
    @Published private(set) var organizationMap: OrganizationMap = .empty
    @Published private(set) var organizationPlan: OrganizationPlan = .empty
    @Published private(set) var lastOrganizationMapDate: Date?
    @Published private(set) var isBuildingOrganizationMap = false
    @Published private(set) var isOrganizing = false
    @Published private(set) var organizerStatus: String?
    @Published var organizationDetailSelection = OrganizationDetailSelection()
    @Published var managementError: String?
    @Published var organizerError: String?
    @Published var approvedOrganizationRecommendationIDs: Set<String> = []
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
    @Published var openAIModel = OpenAIConfiguration.normalizedStoredModel(UserDefaults.standard.string(forKey: "openAIModel"))
    @Published var openAIBaseURL = UserDefaults.standard.string(forKey: "openAIBaseURL")
        ?? ProcessInfo.processInfo.environment["OPENAI_BASE_URL"]
        ?? OpenAIConfiguration.defaultBaseURL
    @Published var openAIKey = APIKeyStore.shared.loadOpenAIKey()

    private static let scanSourcesDefaultsKey = "scanSources.v2"
    private static let managementStateDefaultsKey = "assetManagementState.v1"
    private static let appLanguageDefaultsKey = "appLanguage"
    private static let openAIBaseURLDefaultsKey = "openAIBaseURL"

    private let scanner: FileSystemAssetScanner
    private let archiveService: AssetArchiveService
    private let enricher = OpenAIEnricher()
    private let organizer = OpenAIOrganizer()
    private let summaryCache: SummaryCache
    private let watcher = SourceFileWatcher()
    private var activeScanID: UUID?
    private var activeOrganizerID: UUID?
    private var cancellationToken: ScanCancellationToken?
    private var enrichmentTask: Task<Void, Never>?
    private var organizerTask: Task<Void, Never>?
    private var pendingOrganizationMapAfterScan = false
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
        organizerTask?.cancel()
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

    var approvedOrganizationRecommendationCount: Int {
        approvedOrganizationRecommendationIDs.count
    }

    var selectedOrganizationRecommendation: OrganizationRecommendation? {
        guard let id = organizationDetailSelection.recommendationID else { return nil }
        return organizationPlan.recommendations.first { $0.id == id }
    }

    var selectedOrganizationBucket: OrganizationBucket? {
        guard let id = organizationDetailSelection.bucketID else { return nil }
        return organizationMap.buckets.first { $0.id == id }
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

    func showOrganizer() {
        selectedSection = .organizer
        selectedAssetID = nil
        rebuildOrganizationMap()
        if lastOrganizationMapDate == nil {
            organizerStatus = t(.mapUsesCurrentIndex)
        }
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
                    if self.pendingOrganizationMapAfterScan {
                        self.pendingOrganizationMapAfterScan = false
                        self.isBuildingOrganizationMap = false
                        self.organizerStatus = self.t(.scanCancelledForMap)
                    }
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
                if self.pendingOrganizationMapAfterScan {
                    self.finishOrganizationMapBuild()
                }

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
        if pendingOrganizationMapAfterScan {
            pendingOrganizationMapAfterScan = false
            isBuildingOrganizationMap = false
            organizerStatus = t(.scanCancelledForMap)
        }
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
        pruneOrganizationApprovals()
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
            pruneOrganizationApprovals()
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
            pruneOrganizationApprovals()
        } catch {
            managementError = error.localizedDescription
        }
    }

    func buildOrganizationMap() {
        organizerTask?.cancel()
        activeOrganizerID = nil
        isOrganizing = false
        organizerError = nil

        switch OrganizationMapBuildPlanner().decision(
            assetCount: visibleAssets.count,
            isIndexStale: isIndexStale,
            isScanning: isScanning
        ) {
        case .buildCurrentIndex:
            finishOrganizationMapBuild()
        case .scanThenBuild:
            pendingOrganizationMapAfterScan = true
            isBuildingOrganizationMap = true
            organizerStatus = t(.scanningForOrganizationMap)
            scan()
        case .waitForScan:
            pendingOrganizationMapAfterScan = true
            isBuildingOrganizationMap = true
            organizerStatus = t(.scanningForOrganizationMap)
        }
    }

    func generateOrganizationRecommendations(useAI: Bool = true) {
        organizerTask?.cancel()
        activeOrganizerID = nil
        isOrganizing = false

        let analyzer = OrganizationAnalyzer()
        let activeAssets = visibleAssets
        let map = analyzer.map(assets: activeAssets, aiSummaries: aiSummaries)
        let localPlan = analyzer.recommendations(for: map, assets: activeAssets)

        organizationMap = map
        organizationPlan = localPlan
        resetOrganizationApprovals(for: localPlan)
        organizerError = nil

        guard !activeAssets.isEmpty else {
            organizerStatus = t(.noAssetsIndexed)
            return
        }

        guard useAI else {
            organizerStatus = t(.localPlanReady)
            return
        }

        let apiKey = openAIKey
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            organizerStatus = t(.localPlanReady)
            organizerError = t(.openAIKeyRequiredForOrganizer)
            return
        }

        let model = OpenAIConfiguration.normalizedModel(openAIModel)
        let baseURL = OpenAIConfiguration.normalizedBaseURL(openAIBaseURL)
        let requestID = UUID()
        activeOrganizerID = requestID
        isOrganizing = true
        organizerStatus = t(.organizing)

        organizerTask = Task { [weak self, organizer, map, activeAssets, apiKey, model, baseURL, localPlan, requestID] in
            defer {
                if let self, self.activeOrganizerID == requestID {
                    self.isOrganizing = false
                    self.activeOrganizerID = nil
                    self.organizerTask = nil
                }
            }

            do {
                let aiPlan = try await organizer.organize(
                    map: map,
                    assets: activeAssets,
                    apiKey: apiKey,
                    model: model,
                    baseURL: baseURL
                )
                guard !Task.isCancelled else { return }
                guard let self, self.activeOrganizerID == requestID else { return }
                let mergedPlan = self.combinedOrganizationPlan(aiPlan: aiPlan, localPlan: localPlan, map: map)
                self.organizationPlan = mergedPlan
                self.resetOrganizationApprovals(for: mergedPlan)
                self.organizerStatus = self.t(.aiPlanReady)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                guard let self, self.activeOrganizerID == requestID else { return }
                self.organizationPlan = localPlan
                self.resetOrganizationApprovals(for: localPlan)
                self.organizerError = error.localizedDescription
                self.organizerStatus = self.t(.aiPlanFailedUsingLocal)
            }
        }
    }

    func setOrganizationRecommendationApproved(_ recommendation: OrganizationRecommendation, approved: Bool) {
        if approved {
            approvedOrganizationRecommendationIDs.insert(recommendation.id)
        } else {
            approvedOrganizationRecommendationIDs.remove(recommendation.id)
        }
    }

    func isOrganizationRecommendationApproved(_ recommendation: OrganizationRecommendation) -> Bool {
        approvedOrganizationRecommendationIDs.contains(recommendation.id)
    }

    func selectOrganizationRecommendation(_ recommendation: OrganizationRecommendation) {
        organizationDetailSelection.selectRecommendation(id: recommendation.id)
    }

    func selectOrganizationBucket(_ bucket: OrganizationBucket) {
        organizationDetailSelection.selectBucket(id: bucket.id)
    }

    func applyApprovedOrganizationActions() {
        let approvedRecommendations = organizationPlan.recommendations.filter {
            approvedOrganizationRecommendationIDs.contains($0.id)
        }

        var appliedCount = 0
        var manualCount = 0

        for recommendation in approvedRecommendations {
            guard let asset = assets.first(where: { $0.path == recommendation.primaryAssetPath }) else { continue }
            switch recommendation.action {
            case .archive:
                archiveAsset(asset, reason: "AI Organizer: \(recommendation.reason)")
                appliedCount += 1
            case .hide:
                hideAsset(asset)
                appliedCount += 1
            case .keep, .merge, .review:
                manualCount += 1
            }
        }

        approvedOrganizationRecommendationIDs = []
        rebuildOrganizationMap()
        organizationPlan = OrganizationAnalyzer().recommendations(for: organizationMap, assets: visibleAssets)
        organizerStatus = String(format: t(.appliedOrganizationActions), appliedCount, manualCount)
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
        openAIModel = OpenAIConfiguration.normalizedModel(openAIModel)
        openAIBaseURL = OpenAIConfiguration.normalizedBaseURL(openAIBaseURL)
        do {
            _ = try OpenAIConfiguration.responsesEndpoint(baseURL: openAIBaseURL)
        } catch {
            aiErrors["settings"] = error.localizedDescription
            return
        }

        UserDefaults.standard.set(openAIModel, forKey: "openAIModel")
        UserDefaults.standard.set(openAIBaseURL, forKey: Self.openAIBaseURLDefaultsKey)
        do {
            try APIKeyStore.shared.saveOpenAIKey(openAIKey)
            aiErrors["settings"] = nil
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
        let model = OpenAIConfiguration.normalizedModel(openAIModel)
        let baseURL = OpenAIConfiguration.normalizedBaseURL(openAIBaseURL)

        enrichmentTask = Task { [weak self, asset, apiKey, model, baseURL, enricher, summaryCache] in
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
                    model: model,
                    baseURL: baseURL
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
        rebuildOrganizationMap()
    }

    private func rebuildOrganizationMap() {
        organizationMap = OrganizationAnalyzer().map(assets: visibleAssets, aiSummaries: aiSummaries)
    }

    private func finishOrganizationMapBuild() {
        pendingOrganizationMapAfterScan = false
        isBuildingOrganizationMap = false
        rebuildOrganizationMap()
        organizationPlan = OrganizationPlan(
            map: organizationMap,
            recommendations: organizationPlan.recommendations.filter { recommendation in
                visibleAssets.contains { $0.path == recommendation.primaryAssetPath }
            },
            source: organizationPlan.source
        )
        lastOrganizationMapDate = Date()
        pruneOrganizationApprovals()
        preserveValidOrganizationDetailSelection()
        organizerStatus = String(format: t(.mapReadyWithCounts), organizationMap.totalAssets, organizationMap.buckets.count)
    }

    private func resetOrganizationApprovals(for plan: OrganizationPlan) {
        approvedOrganizationRecommendationIDs = Set(plan.recommendations.filter(\.isApprovedByDefault).map(\.id))
    }

    private func pruneOrganizationApprovals() {
        let visiblePaths = Set(visibleAssets.map(\.path))
        let validIDs = Set(
            organizationPlan.recommendations
                .filter { visiblePaths.contains($0.primaryAssetPath) }
                .map(\.id)
        )
        approvedOrganizationRecommendationIDs = approvedOrganizationRecommendationIDs.intersection(validIDs)
        preserveValidOrganizationDetailSelection()
    }

    private func preserveValidOrganizationDetailSelection() {
        switch organizationDetailSelection.kind {
        case .recommendation:
            if selectedOrganizationRecommendation == nil {
                organizationDetailSelection.clear()
            }
        case .bucket:
            if selectedOrganizationBucket == nil {
                organizationDetailSelection.clear()
            }
        case .none:
            break
        }
    }

    private func combinedOrganizationPlan(
        aiPlan: OrganizationPlan,
        localPlan: OrganizationPlan,
        map: OrganizationMap
    ) -> OrganizationPlan {
        var seen: Set<String> = []
        let recommendations = (aiPlan.recommendations + localPlan.recommendations).filter { recommendation in
            seen.insert(recommendation.id).inserted
        }
        return OrganizationPlan(
            map: map,
            recommendations: recommendations.sorted { left, right in
                if left.action != right.action {
                    return organizationActionPriority(left.action) < organizationActionPriority(right.action)
                }
                if left.confidence != right.confidence { return left.confidence > right.confidence }
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            },
            source: "openai + local"
        )
    }

    private func organizationActionPriority(_ action: OrganizationAction) -> Int {
        switch action {
        case .archive:
            0
        case .hide:
            1
        case .merge:
            2
        case .review:
            3
        case .keep:
            4
        }
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
