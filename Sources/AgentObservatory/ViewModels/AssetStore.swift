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
    @Published private(set) var aiAuditLog: AIAuditLog
    @Published private(set) var dashboardSummary: DashboardSummary = .empty
    @Published private(set) var contextCatalog: ContextCatalog = .empty
    @Published private(set) var skillTriggerConflicts: [SkillTriggerConflict] = []
    @Published private(set) var organizationMap: OrganizationMap = .empty
    @Published private(set) var organizerBrief: OrganizerBrief = .empty
    @Published private(set) var organizerRun: OrganizerRun = .empty
    @Published private(set) var organizerRunReview: OrganizerRun?
    @Published private(set) var organizationPlan: OrganizationPlan = .empty
    @Published private(set) var cleanupReviewSession: CleanupReviewSession = .empty
    @Published private(set) var lastOrganizationMapDate: Date?
    @Published private(set) var isBuildingOrganizationMap = false
    @Published private(set) var isBuildingCleanupReview = false
    @Published private(set) var isPreparingOrganizerRun = false
    @Published private(set) var isOrganizing = false
    @Published private(set) var organizerStatus: String?
    @Published private(set) var memoryMigrationStatus: String?
    @Published private(set) var cleanupExecutionPreview: CleanupExecutionPreview?
    @Published var organizationDetailSelection = OrganizationDetailSelection()
    @Published var cleanupReviewGoal: CleanupReviewGoal = .fullReview
    @Published var selectedCleanupGroupID: CleanupReviewGroup.ID?
    @Published var managementError: String?
    @Published var organizerError: String?
    @Published var approvedOrganizationRecommendationIDs: Set<String> = []
    @Published var approvedCleanupGroupIDs: Set<String> = []
    @Published var selectedSection: WorkspaceSection = .contextOverview
    @Published private(set) var canGoBack = false
    @Published private(set) var projectRootPath: String?
    @Published var scanSources: [ScanSource]
    @Published var selectedOwner: AgentOwner?
    @Published var selectedKind: AssetKind?
    @Published var selectedHealth: HealthFilter?
    @Published var selectedAssetID: AgentAsset.ID?
    @Published var selectedContextTreeNodeID: ContextTreeNode.ID?
    @Published var selectedSkillTriggerConflictID: SkillTriggerConflict.ID?
    @Published var includeBundledSkills = false {
        didSet {
            guard selectedSection == .assets || selectedSection == .capabilities else { return }
            if selectedSection == .capabilities {
                selectedAssetID = visibleNonMCPCapabilityItems.first?.asset.id
                return
            }
            selectedAssetID = filteredAssets.first?.id
        }
    }
    @Published var searchText = ""
    @Published var interfaceZoomLevel = InterfaceZoomLevel.stored(rawValue: UserDefaults.standard.object(forKey: "interfaceZoomLevel.v1") as? Int)
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
    private static let projectRootDefaultsKey = "projectRoot.v1"
    private static let managementStateDefaultsKey = "assetManagementState.v1"
    private static let aiAuditLogDefaultsKey = "aiAuditLog.v1"
    private static let appLanguageDefaultsKey = "appLanguage"
    private static let interfaceZoomLevelDefaultsKey = "interfaceZoomLevel.v1"
    private static let openAIBaseURLDefaultsKey = "openAIBaseURL"

    private let scanner: FileSystemAssetScanner
    private let archiveService: AssetArchiveService
    private let memoryMigrationPlanner = MemoryMigrationPlanner()
    private let enricher = OpenAIEnricher()
    private let organizer = OpenAIOrganizer()
    private let summaryCache: SummaryCache
    private let watcher = SourceFileWatcher()
    private var activeScanID: UUID?
    private var activeOrganizerID: UUID?
    private var cancellationToken: ScanCancellationToken?
    private var enrichmentTask: Task<Void, Never>?
    private var organizerTask: Task<Void, Never>?
    private var navigationBackStack: [WorkspaceNavigationState] = []
    private var pendingOrganizationMapAfterScan = false
    private var pendingCleanupReviewAfterScan = false
    private var pendingOrganizerRunAfterScan = false
    private var pendingCleanupExecutionPreview = false
    private var lastSnapshot: ScanSnapshot?

    init(
        scanner: FileSystemAssetScanner = FileSystemAssetScanner(),
        archiveService: AssetArchiveService = AssetArchiveService(),
        summaryCache: SummaryCache = SummaryCache(url: SummaryCache.defaultURL)
    ) {
        self.scanner = scanner
        self.archiveService = archiveService
        self.summaryCache = summaryCache
        let loadedProjectRootPath = Self.loadProjectRootPath()
        self.projectRootPath = loadedProjectRootPath
        self.scanSources = Self.loadScanSources(
            defaultSources: scanner.defaultSources(projectDirectory: Self.projectDirectory(from: loadedProjectRootPath))
        )
        self.managementState = Self.loadManagementState()
        self.aiAuditLog = Self.loadAIAuditLog()
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

    var managementOperationBatches: [ManagementOperationBatch] {
        managementState.operationBatches
    }

    var aiAuditRecords: [AIAuditRecord] {
        aiAuditLog.records
    }

    var latestManagementBatch: ManagementOperationBatch? {
        managementState.operationBatches.first
    }

    var hiddenAssets: [AgentAsset] {
        managementState.hiddenAssets(from: assets)
    }

    var approvedOrganizationRecommendationCount: Int {
        approvedOrganizationRecommendationIDs.count
    }

    var approvedExecutableOrganizationRecommendationCount: Int {
        organizationPlan.recommendations.filter {
            approvedOrganizationRecommendationIDs.contains($0.id) && $0.canApplyAutomatically
        }.count
    }

    var approvedCleanupGroupCount: Int {
        approvedCleanupGroupIDs.count
    }

    var cleanupReviewAffectedAssetCount: Int {
        Set(cleanupReviewSession.groups.flatMap(\.assetPaths)).count
    }

    var executableCleanupGroupCount: Int {
        cleanupReviewSession.groups.filter(\.canApplyAutomatically).count
    }

    var organizerAdvancedContentState: OrganizerAdvancedContentState {
        OrganizerAdvancedContentState(
            isBuildingCleanupReview: isBuildingCleanupReview,
            cleanupGroupCount: cleanupReviewSession.groups.count,
            recommendationCount: organizationPlan.recommendations.count,
            organizationAssetCount: organizationMap.totalAssets,
            hasBuiltOrganizationMap: lastOrganizationMapDate != nil
        )
    }

    var selectedCleanupGroup: CleanupReviewGroup? {
        guard organizationDetailSelection.kind == .none else { return nil }
        guard let selectedCleanupGroupID else { return cleanupReviewSession.groups.first }
        return cleanupReviewSession.groups.first { $0.id == selectedCleanupGroupID } ?? cleanupReviewSession.groups.first
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
            let bundledSkillMatches = includeBundledSkills || !isBundledSkill(asset)
            let ownerMatches = selectedOwner == nil || asset.owner == selectedOwner
            let kindMatches = selectedKind == nil || asset.kind == selectedKind
            let healthMatches = selectedHealth?.matches(asset) ?? true
            let queryMatches = asset.matchesSearch(query: searchText)
            return bundledSkillMatches && ownerMatches && kindMatches && healthMatches && queryMatches
        }
    }

    var selectedAsset: AgentAsset? {
        AssetSelectionResolver().selectedAsset(
            selectedAssetID: selectedAssetID,
            visibleAssets: visibleAssets,
            filteredAssets: filteredAssets,
            surface: selectionSurface
        )
    }

    private var selectionSurface: AssetSelectionSurface {
        switch selectedSection {
        case .contextOverview, .memories, .capabilities, .mcpTools, .assembly:
            return .contextBrowser
        default:
            return .assetTable
        }
    }

    var activeScanSources: [ScanSource] {
        scanSources.filter(\.isEnabled)
    }

    var existingScanSourceCount: Int {
        scanSources.filter { FileManager.default.fileExists(atPath: $0.url.path) }.count
    }

    var activeProjectDirectoryDisplayPath: String {
        Self.displayPath(Self.projectDirectory(from: projectRootPath).path)
    }

    var isUsingLaunchDirectoryProjectRoot: Bool {
        projectRootPath == nil
    }

    var isWatchingSources: Bool {
        !activeScanSources.isEmpty
    }

    func healthCount(for filter: HealthFilter) -> Int {
        visibleAssets.filter { asset in
            (includeBundledSkills || !isBundledSkill(asset)) && filter.matches(asset)
        }.count
    }

    func isBundledSkill(_ asset: AgentAsset) -> Bool {
        guard asset.kind == .skill else { return false }
        return ContextLoadAnalyzer().route(for: asset).skillInstallOrigin?.isBundled == true
    }

    var bundledSkillCount: Int {
        visibleAssets.filter(isBundledSkill).count
    }

    var visibleCapabilityItems: [ContextCatalogItem] {
        contextCatalog.capabilityItems.filter { item in
            includeBundledSkills || item.loadRoute.skillInstallOrigin?.isBundled != true
        }
    }

    var visibleMCPItems: [ContextCatalogItem] {
        visibleCapabilityItems.filter { $0.asset.kind == .mcp }
    }

    var visibleNonMCPCapabilityItems: [ContextCatalogItem] {
        visibleCapabilityItems.filter { $0.asset.kind != .mcp }
    }

    var contextTreeNodes: [ContextTreeNode] {
        ContextTreeBuilder(
            catalog: contextCatalog,
            visibleCapabilityItems: visibleCapabilityItems,
            searchText: searchText,
            language: appLanguage
        )
        .nodes()
    }

    var selectedContextTreeNode: ContextTreeNode? {
        guard let selectedContextTreeNodeID else { return nil }
        return contextTreeNodes
            .flatMap(\.flattened)
            .first { $0.id == selectedContextTreeNodeID }
    }

    var selectedContextTreeGroup: ContextTreeNode? {
        guard let node = selectedContextTreeNode, !node.isAsset else { return nil }
        return node
    }

    var selectedSkillTriggerConflict: SkillTriggerConflict? {
        guard let selectedSkillTriggerConflictID else {
            return skillTriggerConflicts.first
        }
        return skillTriggerConflicts.first { $0.id == selectedSkillTriggerConflictID } ?? skillTriggerConflicts.first
    }

    var highSkillTriggerConflictCount: Int {
        skillTriggerConflicts.filter { $0.severity == .high }.count
    }

    var mediumSkillTriggerConflictCount: Int {
        skillTriggerConflicts.filter { $0.severity == .medium }.count
    }

    var skillTriggerRadarAffectedSkillCount: Int {
        Set(
            skillTriggerConflicts.flatMap { conflict in
                [conflict.primaryAsset.path, conflict.competingAsset.path]
            }
        )
        .count
    }

    func organizerBriefMarkdown() -> String {
        OrganizerBriefExporter().markdown(
            brief: organizerBrief,
            map: organizationMap,
            language: appLanguage
        )
    }

    func organizerRunMarkdown() -> String {
        OrganizerRunExporter().markdown(
            run: organizerRun,
            language: appLanguage
        )
    }

    func markOrganizerBriefCopied() {
        organizerStatus = t(.organizerBriefCopied)
    }

    func sourceExists(_ source: ScanSource) -> Bool {
        FileManager.default.fileExists(atPath: source.url.path)
    }

    func t(_ key: L10n.Key) -> String {
        L10n.text(key, language: appLanguage)
    }

    func resetFilters() {
        navigate {
            selectedOwner = nil
            selectedKind = nil
            selectedHealth = nil
            includeBundledSkills = false
            searchText = ""
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = filteredAssets.first?.id
            selectedSection = .assets
        }
    }

    func showTriggerRadar() {
        navigate {
            selectedSection = .triggerRadar
            selectedContextTreeNodeID = nil
            selectedAssetID = nil
            selectedSkillTriggerConflictID = selectedSkillTriggerConflict?.id
        }
    }

    func showContextOverview() {
        navigate {
            selectedSection = .contextOverview
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = nil
        }
    }

    func showMemories() {
        navigate {
            selectedSection = .memories
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = contextCatalog.memoryItems.first?.asset.id
        }
    }

    func showCapabilities() {
        navigate {
            selectedSection = .capabilities
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = visibleNonMCPCapabilityItems.first?.asset.id
        }
    }

    func showMCPTools() {
        navigate {
            selectedSection = .mcpTools
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = visibleMCPItems.first?.asset.id
        }
    }

    func showAssembly() {
        navigate {
            selectedSection = .assembly
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = nil
        }
    }

    func showDashboard() {
        navigate {
            selectedSection = .dashboard
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
        }
    }

    func showOrganizer() {
        navigate {
            selectedSection = .organizer
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = nil
        }
        rebuildOrganizationMap()
        if lastOrganizationMapDate == nil {
            organizerStatus = t(.mapUsesCurrentIndex)
        }
    }

    func showAssets() {
        navigate {
            selectedSection = .assets
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
        }
    }

    func showArchive() {
        navigate {
            selectedSection = .archive
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
        }
    }

    func showHidden() {
        navigate {
            selectedSection = .hidden
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = nil
        }
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
            sourceLabel: t(.allSources),
            rootsCompleted: 0,
            rootCount: sources.filter(\.isEnabled).count,
            message: t(.scanPreparingRoots)
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
                    if self.pendingCleanupReviewAfterScan {
                        self.pendingCleanupReviewAfterScan = false
                        self.pendingCleanupExecutionPreview = false
                        self.cleanupExecutionPreview = nil
                        self.isBuildingCleanupReview = false
                        self.organizerStatus = self.t(.scanCancelledForCleanupReview)
                    }
                    if self.pendingOrganizerRunAfterScan {
                        self.pendingOrganizerRunAfterScan = false
                        self.isPreparingOrganizerRun = false
                        self.organizerStatus = self.t(.scanCancelledForCleanupReview)
                    }
                    self.isScanning = false
                    self.scanProgress = ScanProgress(
                        phase: .cancelled,
                        sourceLabel: self.t(.allSources),
                        rootsCompleted: self.scanProgress?.rootsCompleted ?? 0,
                        rootCount: self.scanProgress?.rootCount ?? 0,
                        filesVisited: self.scanProgress?.filesVisited ?? 0,
                        filesDiscovered: self.scanProgress?.filesDiscovered ?? 0,
                        filesProcessed: self.scanProgress?.filesProcessed ?? 0,
                        assetsFound: self.scanProgress?.assetsFound ?? self.assets.count,
                        directoriesSkipped: self.scanProgress?.directoriesSkipped ?? 0,
                        readErrors: self.scanProgress?.readErrors ?? 0,
                        message: self.t(.scanCancelled)
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
                    sourceLabel: self.t(.allSources),
                    rootsCompleted: self.scanProgress?.rootCount ?? 0,
                    rootCount: self.scanProgress?.rootCount ?? 0,
                    filesVisited: self.scanProgress?.filesVisited ?? 0,
                    filesDiscovered: self.scanProgress?.filesDiscovered ?? 0,
                    filesProcessed: self.scanProgress?.filesProcessed ?? 0,
                        assetsFound: visibleScanned.count,
                    directoriesSkipped: self.scanProgress?.directoriesSkipped ?? 0,
                    readErrors: self.scanProgress?.readErrors ?? 0,
                    rootProgress: 1,
                    message: self.t(.scanCompleted)
                )
                self.rebuildDashboardSummary()
                if self.pendingOrganizationMapAfterScan {
                    self.finishOrganizationMapBuild()
                }
                if self.pendingCleanupReviewAfterScan {
                    self.finishCleanupReview()
                }
                if self.pendingOrganizerRunAfterScan {
                    self.finishOrganizerRunBuild(presentReview: true)
                }

                if let previousSelectedPath,
                   let preserved = visibleScanned.first(where: { $0.path == previousSelectedPath }) {
                    self.selectedAssetID = preserved.id
                } else if self.selectedSection == .triggerRadar
                    || self.selectedSection == .contextOverview
                    || self.selectedSection == .assembly
                {
                    self.selectedAssetID = nil
                } else if self.selectedSection == .capabilities {
                    self.selectedAssetID = self.visibleNonMCPCapabilityItems.first?.asset.id
                } else if self.selectedSection == .mcpTools {
                    self.selectedAssetID = self.visibleMCPItems.first?.asset.id
                } else if self.selectedSection == .memories {
                    self.selectedAssetID = self.contextCatalog.memoryItems.first?.asset.id
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
        if pendingCleanupReviewAfterScan {
            pendingCleanupReviewAfterScan = false
            pendingCleanupExecutionPreview = false
            cleanupExecutionPreview = nil
            isBuildingCleanupReview = false
            organizerStatus = t(.scanCancelledForCleanupReview)
        }
        if pendingOrganizerRunAfterScan {
            pendingOrganizerRunAfterScan = false
            isPreparingOrganizerRun = false
            organizerStatus = t(.scanCancelledForCleanupReview)
        }
        isScanning = false
        scanProgress = ScanProgress(
            phase: .cancelled,
            sourceLabel: scanProgress?.sourceLabel ?? t(.allSources),
            currentPath: scanProgress?.currentPath ?? "",
            rootsCompleted: scanProgress?.rootsCompleted ?? 0,
            rootCount: scanProgress?.rootCount ?? 0,
            filesVisited: scanProgress?.filesVisited ?? 0,
            filesDiscovered: scanProgress?.filesDiscovered ?? 0,
            filesProcessed: scanProgress?.filesProcessed ?? 0,
            assetsFound: scanProgress?.assetsFound ?? assets.count,
            directoriesSkipped: scanProgress?.directoriesSkipped ?? 0,
            readErrors: scanProgress?.readErrors ?? 0,
            message: t(.scanCancelled)
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

    func setProjectRoot(url: URL) {
        projectRootPath = url.standardizedFileURL.path
        UserDefaults.standard.set(projectRootPath, forKey: Self.projectRootDefaultsKey)
        reloadDefaultScanSources()
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

    func addWorkspaceMemorySource(url: URL) {
        let standardizedPath = url.standardizedFileURL.path
        let id = "workspace-memory-\(StableHash.hash(standardizedPath))"
        guard !scanSources.contains(where: { $0.id == id }) else { return }

        let folderName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        scanSources.append(
            ScanSource(
                id: id,
                owner: .project,
                label: "\(t(.workspaceMemory)) · \(folderName)",
                path: standardizedPath,
                scope: "workspace-memory",
                maxDepth: 12,
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
        scanSources = scanner.defaultSources(projectDirectory: Self.projectDirectory(from: projectRootPath))
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
        let record = performHideAsset(asset)
        commitManagementOperations(
            title: "\(t(.hide)): \(asset.title)",
            source: .manual,
            records: [record]
        )
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
        markManagedFileEvent(path: asset.path, message: String(format: t(.unhiddenFileStatus), asset.displayPath))
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
        let record = performArchiveAsset(asset, reason: reason, kind: .archive)
        commitManagementOperations(
            title: "\(t(.archiveAction)): \(asset.title)",
            source: .manual,
            records: [record]
        )
    }

    func restoreArchivedAsset(_ archivedAsset: ArchivedAsset) {
        do {
            try archiveService.restore(archivedAsset)
            managementState.removeArchive(id: archivedAsset.id)
            saveManagementState()
            managementError = nil
            markManagedFileEvent(path: archivedAsset.originalPath, message: String(format: t(.restoredFileStatus), archivedAsset.displayOriginalPath))
            rebuildDashboardSummary()
            pruneOrganizationApprovals()
        } catch {
            managementError = error.localizedDescription
        }
    }

    func undoLatestManagementBatch() {
        guard let batch = latestManagementBatch else { return }
        undoManagementBatch(batch)
    }

    func undoManagementBatch(_ batch: ManagementOperationBatch) {
        guard batch.undoableCount > 0 else {
            organizerStatus = t(.operationUndoNotAvailable)
            return
        }

        var updatedBatch = batch
        var undoneCount = 0
        var failedCount = 0
        var affectedPaths: [String] = []

        for record in batch.records.reversed() where record.isUndoable {
            switch record.kind {
            case .hide:
                managementState.unhide(path: record.originalPath)
                updatedBatch.markRecord(id: record.id, status: .undone, message: String(format: t(.unhiddenFileStatus), record.title))
                undoneCount += 1
                affectedPaths.append(record.originalPath)
            case .archive, .mergeArchive:
                guard let archivedAsset = record.archivedAsset else {
                    updatedBatch.markRecord(id: record.id, status: .undoFailed, message: t(.operationUndoNotAvailable))
                    failedCount += 1
                    continue
                }

                do {
                    try archiveService.restore(archivedAsset)
                    managementState.removeArchive(id: archivedAsset.id)
                    updatedBatch.markRecord(id: record.id, status: .undone, message: String(format: t(.restoredFileStatus), archivedAsset.displayOriginalPath))
                    undoneCount += 1
                    affectedPaths.append(record.originalPath)
                } catch {
                    updatedBatch.markRecord(id: record.id, status: .undoFailed, message: error.localizedDescription)
                    managementError = error.localizedDescription
                    failedCount += 1
                }
            }
        }

        managementState.replaceOperationBatch(updatedBatch)
        saveManagementState()
        markManagedFileEvent(paths: affectedPaths, message: String(format: t(.operationBatchUndone), undoneCount, failedCount))
        rebuildDashboardSummary()
        pruneOrganizationApprovals()
        organizerStatus = String(format: t(.operationBatchUndone), undoneCount, failedCount)
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

    func startCleanupReview() {
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
            finishCleanupReview()
        case .scanThenBuild:
            pendingCleanupReviewAfterScan = true
            isBuildingCleanupReview = true
            organizerStatus = t(.scanningForCleanupReview)
            scan()
        case .waitForScan:
            pendingCleanupReviewAfterScan = true
            isBuildingCleanupReview = true
            organizerStatus = t(.scanningForCleanupReview)
        }
    }

    func prepareCleanupExecution(goal: CleanupReviewGoal) {
        cleanupExecutionPreview = nil
        pendingCleanupExecutionPreview = true
        cleanupReviewGoal = goal
        startCleanupReview()
    }

    func prepareOrganizerRun() {
        organizerRunReview = nil
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
            finishOrganizerRunBuild(presentReview: true)
        case .scanThenBuild:
            pendingOrganizerRunAfterScan = true
            isPreparingOrganizerRun = true
            organizerStatus = t(.organizerRunScanning)
            scan()
        case .waitForScan:
            pendingOrganizerRunAfterScan = true
            isPreparingOrganizerRun = true
            organizerStatus = t(.organizerRunScanning)
        }
    }

    func dismissOrganizerRunReview() {
        organizerRunReview = nil
    }

    func confirmOrganizerRunExecution() {
        let run = organizerRunReview ?? organizerRun
        organizerRunReview = nil
        guard run.hasExecutablePacks else {
            organizerStatus = t(.cleanupPreviewManualOnly)
            return
        }

        var records: [ManagementOperationRecord] = []
        for pack in run.executablePacks {
            for path in pack.executableAssetPaths {
                guard let asset = assets.first(where: { $0.path == path }) else { continue }
                switch pack.kind {
                case .mergeDuplicates:
                    records.append(
                        performArchiveAsset(
                            asset,
                            reason: "\(t(.aiOrganizer)): \(pack.summary)",
                            kind: .mergeArchive
                        )
                    )
                case .hideNoise:
                    records.append(performHideAsset(asset))
                case .reviewSensitive, .reviewUnreadable, .clarifyUnknown, .reviewStalePaths:
                    break
                }
            }
        }

        commitManagementOperations(title: t(.aiOrganizer), source: .aiOrganizer, records: records)
        finishOrganizerRunBuild(presentReview: false)
        organizerStatus = String(format: t(.appliedOrganizationActions), records.filter { $0.status == .applied }.count, run.actionPacks.count - run.executablePacks.count)
    }

    func dismissCleanupExecutionPreview() {
        cleanupExecutionPreview = nil
        pendingCleanupExecutionPreview = false
    }

    func confirmCleanupExecutionPreview() {
        guard let preview = cleanupExecutionPreview else { return }
        cleanupExecutionPreview = nil
        pendingCleanupExecutionPreview = false

        guard preview.hasExecutableActions else {
            organizerStatus = t(.cleanupPreviewManualOnly)
            return
        }

        approvedCleanupGroupIDs = Set(
            cleanupReviewSession.groups
                .filter(\.canApplyAutomatically)
                .map(\.id)
        )
        applyApprovedCleanupGroups()
    }

    func generateOrganizationRecommendations(useAI: Bool = true) {
        organizerTask?.cancel()
        activeOrganizerID = nil
        isOrganizing = false

        let analyzer = OrganizationAnalyzer()
        let activeAssets = visibleAssets
        let map = analyzer.map(assets: activeAssets, aiSummaries: aiSummaries, language: appLanguage)
        let localPlan = analyzer.recommendations(for: map, assets: activeAssets, language: appLanguage)

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
        let language = appLanguage
        let requestID = UUID()
        activeOrganizerID = requestID
        isOrganizing = true
        organizerStatus = t(.organizing)
        let auditRecord = beginAIAudit(
            operation: .organizationPlan,
            model: model,
            baseURL: baseURL,
            assetCount: activeAssets.count,
            message: t(.organizing)
        )

        organizerTask = Task { [weak self, organizer, map, activeAssets, apiKey, model, baseURL, language, localPlan, requestID, auditRecord] in
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
                    baseURL: baseURL,
                    language: language
                )
                guard !Task.isCancelled else { return }
                guard let self, self.activeOrganizerID == requestID else { return }
                let mergedPlan = self.combinedOrganizationPlan(aiPlan: aiPlan, localPlan: localPlan, map: map)
                self.organizationPlan = mergedPlan
                self.resetOrganizationApprovals(for: mergedPlan)
                self.organizerStatus = self.t(.aiPlanReady)
                self.finishAIAudit(auditRecord, status: .succeeded, message: self.t(.aiPlanReady))
            } catch is CancellationError {
                guard let self else { return }
                self.finishAIAudit(auditRecord, status: .cancelled, message: self.t(.cancel))
                return
            } catch {
                guard !Task.isCancelled else { return }
                guard let self, self.activeOrganizerID == requestID else { return }
                self.organizationPlan = localPlan
                self.resetOrganizationApprovals(for: localPlan)
                self.organizerError = String(format: self.t(.aiPlanErrorPrefix), error.localizedDescription)
                self.organizerStatus = self.t(.aiPlanFailedUsingLocal)
                self.finishAIAudit(auditRecord, status: .failed, message: error.localizedDescription)
            }
        }
    }

    func setOrganizationRecommendationApproved(_ recommendation: OrganizationRecommendation, approved: Bool) {
        guard recommendation.canApplyAutomatically else {
            approvedOrganizationRecommendationIDs.remove(recommendation.id)
            organizerStatus = t(.manualRecommendationRequired)
            return
        }

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

    func selectCleanupGroup(_ group: CleanupReviewGroup) {
        selectedCleanupGroupID = group.id
        organizationDetailSelection.clear()
    }

    func setCleanupGroupApproved(_ group: CleanupReviewGroup, approved: Bool) {
        guard group.canApplyAutomatically else {
            approvedCleanupGroupIDs.remove(group.id)
            return
        }

        if approved {
            approvedCleanupGroupIDs.insert(group.id)
        } else {
            approvedCleanupGroupIDs.remove(group.id)
        }
    }

    func isCleanupGroupApproved(_ group: CleanupReviewGroup) -> Bool {
        approvedCleanupGroupIDs.contains(group.id)
    }

    func applyApprovedCleanupGroups() {
        let approvedGroups = cleanupReviewSession.groups.filter {
            approvedCleanupGroupIDs.contains($0.id) && $0.canApplyAutomatically
        }

        var records: [ManagementOperationRecord] = []
        for group in approvedGroups {
            for path in group.automaticApplyAssetPaths {
                guard let asset = assets.first(where: { $0.path == path }) else { continue }
                switch group.action {
                case .archive:
                    records.append(performArchiveAsset(asset, reason: "\(t(.cleanupReview)): \(group.summary)", kind: .archive))
                case .merge:
                    records.append(performArchiveAsset(asset, reason: mergeArchiveReason(summary: group.summary, primaryPath: group.assetPaths.first), kind: .mergeArchive))
                case .hide:
                    records.append(performHideAsset(asset))
                case .review, .keep:
                    break
                }
            }
        }

        commitManagementOperations(title: t(.cleanupReview), source: .cleanupReview, records: records)
        approvedCleanupGroupIDs = []
        finishCleanupReview()
        organizerStatus = String(format: t(.appliedCleanupActions), records.filter { $0.status == .applied }.count)
    }

    func applyApprovedOrganizationActions() {
        let approvedRecommendations = organizationPlan.recommendations.filter {
            approvedOrganizationRecommendationIDs.contains($0.id)
        }
        let executableRecommendations = approvedRecommendations.filter(\.canApplyAutomatically)

        guard !executableRecommendations.isEmpty else {
            approvedOrganizationRecommendationIDs = []
            organizerStatus = t(.noExecutableApprovedActions)
            return
        }

        var records: [ManagementOperationRecord] = []
        let manualCount = approvedRecommendations.count - executableRecommendations.count

        for recommendation in executableRecommendations {
            for path in recommendation.automaticApplyAssetPaths {
                guard let asset = assets.first(where: { $0.path == path }) else { continue }
                switch recommendation.action {
                case .archive:
                    records.append(performArchiveAsset(asset, reason: "\(t(.aiOrganizer)): \(recommendation.reason)", kind: .archive))
                case .merge:
                    records.append(performArchiveAsset(asset, reason: mergeArchiveReason(summary: recommendation.reason, primaryPath: recommendation.primaryAssetPath), kind: .mergeArchive))
                case .hide:
                    records.append(performHideAsset(asset))
                case .keep, .review:
                    break
                }
            }
        }

        commitManagementOperations(title: t(.aiOrganizer), source: .aiOrganizer, records: records)
        approvedOrganizationRecommendationIDs = []
        rebuildOrganizationMap()
        organizationPlan = OrganizationAnalyzer().recommendations(for: organizationMap, assets: visibleAssets, language: appLanguage)
        organizerStatus = String(format: t(.appliedOrganizationActions), records.filter { $0.status == .applied }.count, manualCount)
    }

    func startWatchingSources() {
        watcher.start(sources: activeScanSources) { [weak self] paths in
            self?.recordFileEvents(paths)
        }
    }

    func select(owner: AgentOwner?) {
        navigate {
            selectedSection = .assets
            selectedContextTreeNodeID = nil
            selectedOwner = owner
            selectedAssetID = filteredAssets.first?.id
        }
    }

    func select(kind: AssetKind?) {
        navigate {
            selectedSection = .assets
            selectedContextTreeNodeID = nil
            selectedKind = kind
            selectedAssetID = filteredAssets.first?.id
        }
    }

    func select(health: HealthFilter?) {
        navigate {
            selectedSection = .assets
            selectedContextTreeNodeID = nil
            selectedHealth = health
            selectedAssetID = filteredAssets.first?.id
        }
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
        rebuildOrganizationMap()
        if cleanupReviewSession.createdAt.timeIntervalSince1970 > 0 {
            cleanupReviewSession = CleanupReviewAnalyzer().session(goal: cleanupReviewGoal, assets: visibleAssets, language: appLanguage)
        }
    }

    func saveGeneralSettings() {
        UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageDefaultsKey)
    }

    func zoomInterfaceIn() {
        setInterfaceZoomLevel(interfaceZoomLevel.zoomedIn)
    }

    func zoomInterfaceOut() {
        setInterfaceZoomLevel(interfaceZoomLevel.zoomedOut)
    }

    func resetInterfaceZoom() {
        setInterfaceZoomLevel(.defaultLevel)
    }

    private func setInterfaceZoomLevel(_ level: InterfaceZoomLevel) {
        guard interfaceZoomLevel != level else { return }
        interfaceZoomLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: Self.interfaceZoomLevelDefaultsKey)
    }

    func enrichSelectedAsset() {
        guard let asset = selectedAsset else { return }
        guard OpenAIPayloadGuard.isSafeForAI(asset) else {
            aiErrors[asset.contentHash] = t(.sensitiveFilesNotSentToOpenAI)
            return
        }

        enrichmentTask?.cancel()
        enrichingAssetID = asset.id
        aiErrors[asset.contentHash] = nil
        let apiKey = openAIKey
        let model = OpenAIConfiguration.normalizedModel(openAIModel)
        let baseURL = OpenAIConfiguration.normalizedBaseURL(openAIBaseURL)
        let language = appLanguage
        let auditRecord = beginAIAudit(
            operation: .assetExplanation,
            model: model,
            baseURL: baseURL,
            assetCount: 1,
            message: L10n.aiAuditOperation(.assetExplanation, language: appLanguage)
        )

        enrichmentTask = Task { [weak self, asset, apiKey, model, baseURL, language, enricher, summaryCache, auditRecord] in
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
                    baseURL: baseURL,
                    language: language
                )
                guard !Task.isCancelled else { return }
                guard let self else { return }
                aiSummaries[asset.contentHash] = summary
                try? summaryCache.save(summary: summary, forContentHash: asset.contentHash)
                rebuildDashboardSummary()
                finishAIAudit(auditRecord, status: .succeeded, message: L10n.aiAuditOperation(.assetExplanation, language: language))
            } catch is CancellationError {
                guard let self else { return }
                finishAIAudit(auditRecord, status: .cancelled, message: L10n.aiAuditOperation(.assetExplanation, language: language))
                return
            } catch {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                aiErrors[asset.contentHash] = error.localizedDescription
                finishAIAudit(auditRecord, status: .failed, message: error.localizedDescription)
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
        navigate {
            selectedSection = .assets
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = asset.id
        }
    }

    func focusAsset(path: String?) {
        guard let path,
              let asset = visibleAssets.first(where: { $0.path == path }) else {
            return
        }
        selectedContextTreeNodeID = nil
        selectedSkillTriggerConflictID = nil
        selectedAssetID = asset.id
    }

    func memoryMigrationPlan(for asset: AgentAsset, to target: AgentOwner) -> MemoryMigrationPlan? {
        guard let side = MemoryMigrationSide(owner: target) else { return nil }
        return try? memoryMigrationPlanner.plan(
            for: asset,
            target: side,
            projectDirectory: memoryMigrationProjectDirectory
        )
    }

    func existingMemoryTargetPath(
        for asset: AgentAsset,
        to target: AgentOwner,
        plannedDestinationPath: String? = nil
    ) -> String? {
        guard let side = MemoryMigrationSide(owner: target) else { return nil }
        return memoryMigrationPlanner.existingTargetMemory(
            for: asset,
            target: side,
            in: contextCatalog.memoryItems,
            plannedDestinationPath: plannedDestinationPath
        )?.asset.path
    }

    @discardableResult
    func migrateMemory(_ asset: AgentAsset, to target: AgentOwner) -> MemoryMigrationResult? {
        guard let side = MemoryMigrationSide(owner: target) else {
            memoryMigrationStatus = nil
            managementError = memoryMigrationErrorPrefix + "unsupported target"
            return nil
        }

        do {
            let plan = try memoryMigrationPlanner.plan(
                for: asset,
                target: side,
                projectDirectory: memoryMigrationProjectDirectory
            )
            if let existingPath = memoryMigrationPlanner.existingTargetMemory(
                for: asset,
                target: side,
                in: contextCatalog.memoryItems,
                plannedDestinationPath: plan.destinationPath
            )?.asset.path {
                memoryMigrationStatus = nil
                managementError = memoryMigrationTargetExistsMessage(path: existingPath)
                return nil
            }

            let result = try memoryMigrationPlanner.migrate(
                asset: asset,
                target: side,
                projectDirectory: memoryMigrationProjectDirectory
            )
            memoryMigrationStatus = memoryMigrationSuccessMessage(result: result)
            managementError = nil
            markManagedFileEvent(
                path: result.plan.destinationPath,
                message: memoryMigrationStatus ?? ""
            )
            if !isScanning {
                scan()
            }
            return result
        } catch {
            memoryMigrationStatus = nil
            managementError = "\(memoryMigrationErrorPrefix)\(error.localizedDescription)"
            return nil
        }
    }

    func selectContextTreeNode(_ node: ContextTreeNode) {
        navigate {
            selectedSection = .contextOverview
            selectedContextTreeNodeID = node.id
            selectedSkillTriggerConflictID = nil
            selectedAssetID = node.asset?.id
        }
    }

    func focusContextAsset(path: String?) {
        guard let path,
              let asset = visibleAssets.first(where: { $0.path == path }) else {
            return
        }
        navigate {
            selectedSection = .contextOverview
            selectedContextTreeNodeID = nil
            selectedSkillTriggerConflictID = nil
            selectedAssetID = asset.id
        }
    }

    func selectSkillTriggerConflict(_ conflict: SkillTriggerConflict) {
        navigate {
            selectedSection = .triggerRadar
            selectedContextTreeNodeID = nil
            selectedAssetID = nil
            selectedSkillTriggerConflictID = conflict.id
        }
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

    func goBack() {
        guard let previousState = navigationBackStack.popLast() else { return }
        applyNavigationState(previousState)
        updateBackAvailability()
    }

    private func navigate(_ update: () -> Void) {
        let previousState = currentNavigationState()
        update()
        let currentState = currentNavigationState()
        guard currentState != previousState else { return }

        if navigationBackStack.last != previousState {
            navigationBackStack.append(previousState)
        }
        if navigationBackStack.count > 40 {
            navigationBackStack.removeFirst(navigationBackStack.count - 40)
        }
        updateBackAvailability()
    }

    private func currentNavigationState() -> WorkspaceNavigationState {
        WorkspaceNavigationState(
            selectedSection: selectedSection,
            selectedOwner: selectedOwner,
            selectedKind: selectedKind,
            selectedHealth: selectedHealth,
            selectedAssetID: selectedAssetID,
            selectedContextTreeNodeID: selectedContextTreeNodeID,
            selectedSkillTriggerConflictID: selectedSkillTriggerConflictID
        )
    }

    private func applyNavigationState(_ state: WorkspaceNavigationState) {
        selectedSection = state.selectedSection
        selectedOwner = state.selectedOwner
        selectedKind = state.selectedKind
        selectedHealth = state.selectedHealth
        selectedAssetID = state.selectedAssetID
        selectedContextTreeNodeID = state.selectedContextTreeNodeID
        selectedSkillTriggerConflictID = state.selectedSkillTriggerConflictID

        if selectedSection == .organizer {
            rebuildOrganizationMap()
        }
    }

    private func updateBackAvailability() {
        canGoBack = !navigationBackStack.isEmpty
    }

    private func saveScanSources() {
        guard let data = try? JSONEncoder().encode(scanSources) else { return }
        UserDefaults.standard.set(data, forKey: Self.scanSourcesDefaultsKey)
    }

    private func reloadDefaultScanSources() {
        let defaultSources = scanner.defaultSources(projectDirectory: Self.projectDirectory(from: projectRootPath))
        scanSources = Self.mergeScanSources(defaultSources: defaultSources, savedSources: scanSources)
        saveScanSources()
        startWatchingSources()
        isIndexStale = true
        rebuildDashboardSummary()
    }

    private func saveManagementState() {
        guard let data = try? JSONEncoder().encode(managementState) else { return }
        UserDefaults.standard.set(data, forKey: Self.managementStateDefaultsKey)
    }

    private func saveAIAuditLog() {
        guard let data = try? JSONEncoder().encode(aiAuditLog) else { return }
        UserDefaults.standard.set(data, forKey: Self.aiAuditLogDefaultsKey)
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
        rebuildContextCatalog()
        rebuildOrganizationMap()
    }

    private func rebuildContextCatalog() {
        contextCatalog = ContextCatalogAnalyzer().catalog(assets: visibleAssets)
        rebuildSkillTriggerConflicts()
    }

    private func rebuildSkillTriggerConflicts() {
        skillTriggerConflicts = SkillTriggerConflictAnalyzer().conflicts(assets: visibleAssets)
        if let selectedSkillTriggerConflictID,
           !skillTriggerConflicts.contains(where: { $0.id == selectedSkillTriggerConflictID }) {
            self.selectedSkillTriggerConflictID = skillTriggerConflicts.first?.id
        }
    }

    private func rebuildOrganizationMap() {
        organizationMap = OrganizationAnalyzer().map(assets: visibleAssets, aiSummaries: aiSummaries, language: appLanguage)
        organizerBrief = OrganizerAdvisor().brief(map: organizationMap, assets: visibleAssets, language: appLanguage)
        organizerRun = OrganizerRunPlanner().plan(map: organizationMap, assets: visibleAssets, language: appLanguage)
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

    private func finishCleanupReview() {
        pendingCleanupReviewAfterScan = false
        isBuildingCleanupReview = false
        rebuildOrganizationMap()
        cleanupReviewSession = CleanupReviewAnalyzer().session(goal: cleanupReviewGoal, assets: visibleAssets, language: appLanguage)
        lastOrganizationMapDate = Date()
        approvedCleanupGroupIDs = approvedCleanupGroupIDs.intersection(Set(cleanupReviewSession.groups.map(\.id)))
        if let selectedCleanupGroupID,
           !cleanupReviewSession.groups.contains(where: { $0.id == selectedCleanupGroupID }) {
            self.selectedCleanupGroupID = cleanupReviewSession.groups.first?.id
        } else if selectedCleanupGroupID == nil {
            selectedCleanupGroupID = cleanupReviewSession.groups.first?.id
        }
        organizerStatus = String(format: t(.cleanupReviewReadyWithCounts), cleanupReviewSession.groups.count, cleanupReviewAffectedAssetCount)
        if pendingCleanupExecutionPreview {
            pendingCleanupExecutionPreview = false
            cleanupExecutionPreview = CleanupExecutionPreview(session: cleanupReviewSession)
        }
    }

    private func finishOrganizerRunBuild(presentReview: Bool) {
        pendingOrganizerRunAfterScan = false
        isPreparingOrganizerRun = false
        rebuildOrganizationMap()
        lastOrganizationMapDate = Date()
        organizerStatus = organizerRun.status == .empty ? t(.noAssetsIndexed) : t(.organizerRunReady)
        if presentReview {
            organizerRunReview = organizerRun
        }
    }

    private func resetOrganizationApprovals(for plan: OrganizationPlan) {
        approvedOrganizationRecommendationIDs = Set(
            plan.recommendations
                .filter { $0.isApprovedByDefault && $0.canApplyAutomatically }
                .map(\.id)
        )
    }

    private func pruneOrganizationApprovals() {
        let visiblePaths = Set(visibleAssets.map(\.path))
        let validIDs = Set(
            organizationPlan.recommendations
                .filter { visiblePaths.contains($0.primaryAssetPath) && $0.canApplyAutomatically }
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

    private func beginAIAudit(
        operation: AIAuditOperation,
        model: String,
        baseURL: String,
        assetCount: Int,
        message: String
    ) -> AIAuditRecord {
        let record = AIAuditRecord(
            operation: operation,
            status: .started,
            model: model,
            baseURL: baseURL,
            assetCount: assetCount,
            message: clippedAuditMessage(message)
        )
        aiAuditLog.add(record)
        saveAIAuditLog()
        return record
    }

    private func finishAIAudit(_ record: AIAuditRecord, status: AIAuditStatus, message: String) {
        var updated = record
        updated.status = status
        updated.message = clippedAuditMessage(message)
        updated.finishedAt = Date()
        aiAuditLog.replace(updated)
        saveAIAuditLog()
    }

    private func clippedAuditMessage(_ message: String) -> String {
        let trimmed = SecretRedactor.auditSafe(message).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 500 else { return trimmed }
        return "\(trimmed.prefix(500))..."
    }

    private func performHideAsset(_ asset: AgentAsset) -> ManagementOperationRecord {
        managementState.hide(path: asset.path)
        managementError = nil
        return ManagementOperationRecord(
            kind: .hide,
            status: .applied,
            originalPath: asset.path,
            title: asset.title,
            archivedAsset: nil,
            message: String(format: t(.hiddenFileStatus), asset.displayPath)
        )
    }

    private func performArchiveAsset(
        _ asset: AgentAsset,
        reason: String,
        kind: ManagementOperationKind
    ) -> ManagementOperationRecord {
        do {
            let archived = try archiveService.archive(asset: asset, reason: reason)
            managementState.hiddenAssetPaths.remove(asset.path)
            managementState.addArchive(archived)
            assets.removeAll { $0.path == asset.path }
            managementError = nil
            return ManagementOperationRecord(
                kind: kind,
                status: .applied,
                originalPath: asset.path,
                title: asset.title,
                archivedAsset: archived,
                message: String(format: t(.archivedFileStatus), asset.displayPath)
            )
        } catch {
            managementError = error.localizedDescription
            return ManagementOperationRecord(
                kind: kind,
                status: .failed,
                originalPath: asset.path,
                title: asset.title,
                archivedAsset: nil,
                message: error.localizedDescription
            )
        }
    }

    private func commitManagementOperations(
        title: String,
        source: ManagementOperationSource,
        records: [ManagementOperationRecord]
    ) {
        guard !records.isEmpty else { return }
        let batch = ManagementOperationBatch(title: title, source: source, records: records)
        managementState.addOperationBatch(batch)
        saveManagementState()
        markManagedFileEvent(
            paths: records.map(\.originalPath),
            message: String(format: t(.operationBatchApplied), batch.appliedCount, batch.failedCount)
        )
        rebuildDashboardSummary()
        pruneOrganizationApprovals()
        preserveValidAssetSelectionAfterManagement()
    }

    private func preserveValidAssetSelectionAfterManagement() {
        guard let selectedAssetID else { return }
        if !visibleAssets.contains(where: { $0.id == selectedAssetID }) {
            self.selectedAssetID = filteredAssets.first?.id
        }
    }

    private func mergeArchiveReason(summary: String, primaryPath: String?) -> String {
        let primary = primaryPath.map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
            ?? t(.unknown)
        return String(format: t(.mergedIntoArchiveReason), primary, summary)
    }

    private func markManagedFileEvent(path: String, message: String) {
        markManagedFileEvent(paths: [path], message: message)
    }

    private func markManagedFileEvent(paths: [String], message: String) {
        let displayPaths = paths
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
        isIndexStale = true
        lastFileEventDate = Date()
        lastFileEventPaths = displayPaths
        scanProgress = ScanProgress(
            phase: .completed,
            sourceLabel: t(.management),
            currentPath: displayPaths.first ?? "",
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

    private var memoryMigrationErrorPrefix: String {
        appLanguage == .simplifiedChinese ? "记忆迁移失败：" : "Memory migration failed: "
    }

    private var memoryMigrationProjectDirectory: URL {
        guard projectRootPath != nil else {
            return FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        }
        return Self.projectDirectory(from: projectRootPath)
    }

    private func memoryMigrationSuccessMessage(result: MemoryMigrationResult) -> String {
        let destination = Self.displayPath(result.plan.destinationPath)
        switch appLanguage {
        case .english:
            return "Copied \(result.plan.title) to \(result.plan.targetSide.owner.shortName): \(destination)"
        case .simplifiedChinese:
            let target = result.plan.targetSide == .claude ? t(.claudeCode) : "Codex"
            return "已把 \(result.plan.title) 复制到 \(target)：\(destination)"
        }
    }

    private func memoryMigrationTargetExistsMessage(path: String) -> String {
        let displayPath = Self.displayPath(path)
        switch appLanguage {
        case .english:
            return "\(memoryMigrationErrorPrefix)target already has a matching memory, so nothing was copied: \(displayPath)"
        case .simplifiedChinese:
            return "\(memoryMigrationErrorPrefix)目标 agent 已有对应记忆，未复制：\(displayPath)"
        }
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

        return mergeScanSources(defaultSources: defaultSources, savedSources: savedSources)
    }

    private static func mergeScanSources(defaultSources: [ScanSource], savedSources: [ScanSource]) -> [ScanSource] {
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

    private static func loadProjectRootPath() -> String? {
        guard let value = UserDefaults.standard.string(forKey: projectRootDefaultsKey),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: (value as NSString).expandingTildeInPath).standardizedFileURL.path
    }

    private static func projectDirectory(from path: String?) -> URL {
        guard let path,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
        }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    private static func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private static func loadManagementState() -> AssetManagementState {
        guard let data = UserDefaults.standard.data(forKey: managementStateDefaultsKey),
              let state = try? JSONDecoder().decode(AssetManagementState.self, from: data) else {
            return AssetManagementState()
        }
        return state
    }

    private static func loadAIAuditLog() -> AIAuditLog {
        guard let data = UserDefaults.standard.data(forKey: aiAuditLogDefaultsKey),
              let log = try? JSONDecoder().decode(AIAuditLog.self, from: data) else {
            return AIAuditLog()
        }
        return log
    }
}

private struct WorkspaceNavigationState: Equatable {
    let selectedSection: WorkspaceSection
    let selectedOwner: AgentOwner?
    let selectedKind: AssetKind?
    let selectedHealth: HealthFilter?
    let selectedAssetID: AgentAsset.ID?
    let selectedContextTreeNodeID: ContextTreeNode.ID?
    let selectedSkillTriggerConflictID: SkillTriggerConflict.ID?
}
