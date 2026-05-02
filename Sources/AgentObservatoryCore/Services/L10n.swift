import Foundation

public enum L10n {
    public enum Key: String, CaseIterable, Sendable {
        case appName
        case settingsTitle
        case settingsSubtitle
        case general
        case language
        case languageDescription
        case indexState
        case currentIndex
        case lastScan
        case noScanYet
        case activeSources
        case existingPaths
        case sources
        case sourcesDescription
        case addFolder
        case resetDefaults
        case custom
        case exists
        case missing
        case removeCustomSource
        case openAI
        case openAIDescription
        case apiKey
        case model
        case modelDescription
        case baseURL
        case openAIBaseURLDescription
        case save
        case management
        case archiveLocation
        case archiveLocationDescription
        case archivedItems
        case hiddenItems
        case unhideAll
        case dashboard
        case aiOrganizer
        case organizerSubtitle
        case organizerDetailMessage
        case buildMap
        case askAIForPlan
        case localPlan
        case applyApproved
        case approved
        case recommendations
        case buckets
        case audiences
        case humanReviewRequired
        case manualOnlyNotice
        case noOrganizationMap
        case noOrganizationRecommendations
        case planSource
        case confidence
        case relatedAssets
        case organizationMap
        case organizationPlan
        case organizing
        case mapReady
        case mapUsesCurrentIndex
        case mapReadyWithCounts
        case scanningForOrganizationMap
        case scanCancelledForMap
        case localPlanReady
        case aiPlanReady
        case aiPlanFailedUsingLocal
        case openAIKeyRequiredForOrganizer
        case appliedOrganizationActions
        case assets
        case archive
        case allSources
        case categories
        case allCategories
        case health
        case allWarnings
        case index
        case refresh
        case refreshStaleIndex
        case cancel
        case explain
        case stale
        case searchPlaceholder
        case reset
        case resetFilters
        case noMatchingAssets
        case noMatchingAssetsMessage
        case selectAsset
        case selectAssetMessage
        case archiveCenter
        case archiveCenterMessage
        case restoreArchivedFilesHint
        case noArchivedAssets
        case noArchivedAssetsMessage
        case hiddenCenterMessage
        case noHiddenAssets
        case noHiddenAssetsMessage
        case restoreToAssets
        case restore
        case showInFinder
        case copyPath
        case copyOriginalPath
        case hide
        case hideFromObservatory
        case archiveAction
        case archiveFile
        case archiveConfirmationMessage
        case archiveReason
        case overview
        case diff
        case impact
        case history
        case raw
        case whatItDoes
        case metadata
        case diagnostics
        case rawContent
        case explainWithOpenAI
        case loadFullContent
        case indexHealth
        case riskQueue
        case claudeCodexDrift
        case recentChanges
        case dependencyHotspots
        case aiCoverage
        case noDashboardRisks
        case noRecentChanges
        case noDependencyHotspots
        case indexCurrent
        case noAssetsIndexed
        case dashboardSubtitle
        case sourceFilesChangedAfterScan
        case items
        case scanningSelectedSources
        case readyToScan
        case updated
        case scanCancelled
        case indexStaleStatus
        case loadingFullContent
        case noRawContentLoaded
        case emptyFile
        case usesRedactedPreviewTextOnly
        case finder
        case ok
        case toggleSidebar
        case clearSearch
        case name
        case kind
        case source
        case status
        case modified
        case size
        case unknown
        case owner
        case all
        case visited
        case found
        case files
        case scanPreparingRoots
        case scanCollectingCandidates
        case scanProcessingCandidate
        case scanFinalizing
        case scanCompleted
        case finished
        case skipped
        case directories
        case readErrors
        case warnings
        case needsAttention
        case changed
        case same
        case added
        case removed
        case comparableNames
        case reviewRelated
        case explained
        case incoming
        case outgoing
        case current
        case asset
        case links
        case hash
        case scope
        case trigger
        case noLocalIssuesDetected
        case duplicateMessage
        case stalePathMessage
        case hasScriptsMessage
        case needsSummaryMessage
        case secretRiskMessage
        case largeFileMessage
        case unreadableMessage
        case noCounterpartFound
        case fieldChanges
        case base
        case counterpart
        case openRelatedAsset
        case unresolvedReference
        case incomingReferences
        case outgoingReferences
        case noIncomingReferences
        case noOutgoingReferences
        case indexStaleMessage
        case indexCurrentMessage
        case lastFileEvent
        case noChangesInLatestComparison
        case hidden
        case duplicates
        case stalePaths
        case secrets
        case explaining
        case path
        case summary
        case dependencies
        case relatedFiles
        case statusFlags
        case frontmatterName
        case frontmatterDescription
        case previewHash
    }

    public static func text(_ key: Key, language: AppLanguage) -> String {
        translations[key]?[language] ?? key.rawValue
    }

    public static func scanProgressMessage(_ progress: ScanProgress, language: AppLanguage) -> String {
        switch progress.phase {
        case .preparing:
            text(.scanPreparingRoots, language: language)
        case .collecting:
            text(.scanCollectingCandidates, language: language)
        case .processing:
            if progress.rootProgress == 1, progress.filesProcessed == progress.filesDiscovered {
                "\(text(.finished, language: language)) \(progress.sourceLabel)"
            } else {
                text(.scanProcessingCandidate, language: language)
            }
        case .finalizing:
            text(.scanFinalizing, language: language)
        case .completed:
            text(.scanCompleted, language: language)
        case .cancelled:
            text(.scanCancelled, language: language)
        }
    }

    public static func assetKind(_ kind: AssetKind, language: AppLanguage) -> String {
        switch (kind, language) {
        case (.skill, .simplifiedChinese): "Skill"
        case (.command, .simplifiedChinese): "Command"
        case (.memory, .simplifiedChinese): "Memory"
        case (.config, .simplifiedChinese): "配置"
        case (.rule, .simplifiedChinese): "规则"
        case (.mcp, .simplifiedChinese): "MCP"
        case (.plugin, .simplifiedChinese): "插件"
        case (.instruction, .simplifiedChinese): "指令"
        case (.script, .simplifiedChinese): "脚本"
        case (.session, .simplifiedChinese): "会话"
        case (.unknown, .simplifiedChinese): text(.unknown, language: language)
        default: kind.rawValue
        }
    }

    public static func agentOwner(_ owner: AgentOwner, language: AppLanguage) -> String {
        switch (owner, language) {
        case (.project, .simplifiedChinese): "项目"
        case (.unknown, .simplifiedChinese): text(.unknown, language: language)
        default: owner.rawValue
        }
    }

    public static func statusFlag(_ flag: AssetStatusFlag, language: AppLanguage) -> String {
        switch (flag, language) {
        case (.duplicate, .simplifiedChinese): "重复"
        case (.stalePath, .simplifiedChinese): "过期路径"
        case (.hasScripts, .simplifiedChinese): "包含脚本"
        case (.needsSummary, .simplifiedChinese): "需要摘要"
        case (.secretRisk, .simplifiedChinese): "密钥风险"
        case (.largeFile, .simplifiedChinese): "大文件"
        case (.unreadable, .simplifiedChinese): "不可读"
        default: flag.rawValue
        }
    }

    public static func shortStatusFlag(_ flag: AssetStatusFlag, language: AppLanguage) -> String {
        switch (flag, language) {
        case (.duplicate, .simplifiedChinese): "重复"
        case (.stalePath, .simplifiedChinese): "路径"
        case (.hasScripts, .simplifiedChinese): "脚本"
        case (.needsSummary, .simplifiedChinese): "摘要"
        case (.secretRisk, .simplifiedChinese): "密钥"
        case (.largeFile, .simplifiedChinese): "大"
        case (.unreadable, .simplifiedChinese): "不可读"
        case (.duplicate, _): "Dup"
        case (.stalePath, _): "Stale"
        case (.hasScripts, _): "Scripts"
        case (.needsSummary, _): "Summary"
        case (.secretRisk, _): "Secret"
        case (.largeFile, _): "Large"
        case (.unreadable, _): "Unreadable"
        }
    }

    public static func statusFlagMessage(_ flag: AssetStatusFlag, language: AppLanguage) -> String {
        switch flag {
        case .duplicate: text(.duplicateMessage, language: language)
        case .stalePath: text(.stalePathMessage, language: language)
        case .hasScripts: text(.hasScriptsMessage, language: language)
        case .needsSummary: text(.needsSummaryMessage, language: language)
        case .secretRisk: text(.secretRiskMessage, language: language)
        case .largeFile: text(.largeFileMessage, language: language)
        case .unreadable: text(.unreadableMessage, language: language)
        }
    }

    public static func comparisonStatus(_ status: AssetComparisonStatus, language: AppLanguage) -> String {
        switch (status, language) {
        case (.same, .simplifiedChinese): text(.same, language: language)
        case (.changed, .simplifiedChinese): text(.changed, language: language)
        case (.missingCounterpart, .simplifiedChinese): "缺少对应项"
        default: status.rawValue
        }
    }

    public static func diffRowStatus(_ status: AssetDiffRowStatus, language: AppLanguage) -> String {
        switch (status, language) {
        case (.same, .simplifiedChinese): text(.same, language: language)
        case (.changed, .simplifiedChinese): text(.changed, language: language)
        case (.missingLeft, .simplifiedChinese): "左侧缺失"
        case (.missingRight, .simplifiedChinese): "右侧缺失"
        default: status.rawValue
        }
    }

    public static func riskSeverity(_ severity: DashboardRiskSeverity, language: AppLanguage) -> String {
        switch (severity, language) {
        case (.critical, .simplifiedChinese): "严重"
        case (.high, .simplifiedChinese): "高"
        case (.medium, .simplifiedChinese): "中"
        case (.low, .simplifiedChinese): "低"
        default: severity.rawValue
        }
    }

    public static func riskCategory(_ category: DashboardRiskCategory, language: AppLanguage) -> String {
        switch (category, language) {
        case (.missingDependency, .simplifiedChinese): "缺失依赖"
        case (.staleReference, .simplifiedChinese): "过期引用"
        case (.sensitiveFile, .simplifiedChinese): "敏感文件"
        case (.unreadable, .simplifiedChinese): "不可读"
        case (.stalePath, .simplifiedChinese): "过期路径"
        case (.duplicate, .simplifiedChinese): "重复"
        case (.largeFile, .simplifiedChinese): "大文件"
        case (.needsSummary, .simplifiedChinese): "需要摘要"
        default: category.rawValue
        }
    }

    public static func organizationAction(_ action: OrganizationAction, language: AppLanguage) -> String {
        switch (action, language) {
        case (.keep, .simplifiedChinese): "保留"
        case (.merge, .simplifiedChinese): "合并"
        case (.archive, .simplifiedChinese): "归档"
        case (.hide, .simplifiedChinese): "隐藏"
        case (.review, .simplifiedChinese): "复核"
        default: action.rawValue
        }
    }

    public static func diffField(_ field: String, language: AppLanguage) -> String {
        switch field {
        case "Path": text(.path, language: language)
        case "Summary": text(.summary, language: language)
        case "Trigger": text(.trigger, language: language)
        case "Dependencies": text(.dependencies, language: language)
        case "Related Files": text(.relatedFiles, language: language)
        case "Status Flags": text(.statusFlags, language: language)
        case "Frontmatter Name": text(.frontmatterName, language: language)
        case "Frontmatter Description": text(.frontmatterDescription, language: language)
        case "Preview Hash": text(.previewHash, language: language)
        default: field
        }
    }

    private static let translations: [Key: [AppLanguage: String]] = [
        .appName: [.english: "Agent Observatory", .simplifiedChinese: "Agent Observatory"],
        .settingsTitle: [.english: "Settings", .simplifiedChinese: "设置"],
        .settingsSubtitle: [.english: "Tune language, sources, AI, and management behavior.", .simplifiedChinese: "调整语言、扫描源、AI 和管理行为。"],
        .general: [.english: "General", .simplifiedChinese: "通用"],
        .language: [.english: "Language", .simplifiedChinese: "语言"],
        .languageDescription: [.english: "Switch the app UI between English and Simplified Chinese. The change applies immediately.", .simplifiedChinese: "在英文和简体中文之间切换界面语言，设置会立即生效。"],
        .indexState: [.english: "Index State", .simplifiedChinese: "索引状态"],
        .currentIndex: [.english: "Current Index", .simplifiedChinese: "当前索引"],
        .lastScan: [.english: "Last scan", .simplifiedChinese: "上次扫描"],
        .noScanYet: [.english: "No scan yet", .simplifiedChinese: "尚未扫描"],
        .activeSources: [.english: "Active Sources", .simplifiedChinese: "启用源"],
        .existingPaths: [.english: "Existing Paths", .simplifiedChinese: "存在路径"],
        .sources: [.english: "Sources", .simplifiedChinese: "扫描源"],
        .sourcesDescription: [.english: "Only enabled sources are scanned. Missing paths stay visible so you can see what the app expected to find.", .simplifiedChinese: "只扫描启用的来源。缺失路径仍会显示，方便你知道应用预期扫描哪些位置。"],
        .addFolder: [.english: "Add Folder", .simplifiedChinese: "添加文件夹"],
        .resetDefaults: [.english: "Reset Defaults", .simplifiedChinese: "恢复默认"],
        .custom: [.english: "Custom", .simplifiedChinese: "自定义"],
        .exists: [.english: "Exists", .simplifiedChinese: "存在"],
        .missing: [.english: "Missing", .simplifiedChinese: "缺失"],
        .removeCustomSource: [.english: "Remove custom source", .simplifiedChinese: "移除自定义来源"],
        .openAI: [.english: "OpenAI", .simplifiedChinese: "OpenAI"],
        .openAIDescription: [.english: "The app sends only redacted file previews for per-file explanations. Sensitive files such as auth.json are never previewed.", .simplifiedChinese: "应用只会发送经过脱敏的文件预览用于逐文件解释。auth.json 等敏感文件永远不会被预览。"],
        .apiKey: [.english: "API key", .simplifiedChinese: "API key"],
        .model: [.english: "Model", .simplifiedChinese: "模型"],
        .modelDescription: [.english: "Default model is gpt-4.1. You can type any OpenAI model name your account can use.", .simplifiedChinese: "默认模型为 gpt-4.1。你也可以输入当前账号可用的任意 OpenAI 模型名。"],
        .baseURL: [.english: "Base URL", .simplifiedChinese: "Base URL"],
        .openAIBaseURLDescription: [.english: "Use https://api.openai.com/v1 for OpenAI. The app appends /responses automatically.", .simplifiedChinese: "OpenAI 默认使用 https://api.openai.com/v1。应用会自动拼接 /responses。"],
        .save: [.english: "Save", .simplifiedChinese: "保存"],
        .management: [.english: "Management", .simplifiedChinese: "管理"],
        .archiveLocation: [.english: "Archive Location", .simplifiedChinese: "归档位置"],
        .archiveLocationDescription: [.english: "Archived files are moved out of active agent locations and can be restored later.", .simplifiedChinese: "归档文件会移出 agent 生效目录，并且之后可以恢复。"],
        .archivedItems: [.english: "Archived Items", .simplifiedChinese: "已归档项目"],
        .hiddenItems: [.english: "Hidden Items", .simplifiedChinese: "隐藏项目"],
        .unhideAll: [.english: "Unhide All", .simplifiedChinese: "全部取消隐藏"],
        .dashboard: [.english: "Dashboard", .simplifiedChinese: "仪表盘"],
        .aiOrganizer: [.english: "AI Organizer", .simplifiedChinese: "AI 整理器"],
        .organizerSubtitle: [.english: "Map local agent assets, ask AI for conservative cleanup advice, then approve exactly what should be applied.", .simplifiedChinese: "先映射本地 agent 资产，再让 AI 给出保守整理建议，最后只执行你明确批准的操作。"],
        .organizerDetailMessage: [.english: "Use the center pane to build a map, generate a plan, and approve archive or hide actions.", .simplifiedChinese: "在中间栏生成资产地图、整理计划，并批准归档或隐藏操作。"],
        .buildMap: [.english: "Build Map", .simplifiedChinese: "生成地图"],
        .askAIForPlan: [.english: "Ask AI for Plan", .simplifiedChinese: "让 AI 规划"],
        .localPlan: [.english: "Local Plan", .simplifiedChinese: "本地计划"],
        .applyApproved: [.english: "Apply Approved", .simplifiedChinese: "执行已批准"],
        .approved: [.english: "Approved", .simplifiedChinese: "已批准"],
        .recommendations: [.english: "Recommendations", .simplifiedChinese: "建议"],
        .buckets: [.english: "Buckets", .simplifiedChinese: "分组"],
        .audiences: [.english: "Audiences", .simplifiedChinese: "使用对象"],
        .humanReviewRequired: [.english: "Human review required", .simplifiedChinese: "需要人工确认"],
        .manualOnlyNotice: [.english: "Only approved Archive and Hide actions are executed. Keep, Merge, and Review remain manual follow-up notes.", .simplifiedChinese: "只有已批准的归档和隐藏会被执行。保留、合并、复核会作为人工后续事项保留。"],
        .noOrganizationMap: [.english: "No organization map yet.", .simplifiedChinese: "尚未生成整理地图。"],
        .noOrganizationRecommendations: [.english: "No recommendations yet. Build a local plan or ask AI for a plan.", .simplifiedChinese: "尚无整理建议。可以生成本地计划，或让 AI 规划。"],
        .planSource: [.english: "Plan source", .simplifiedChinese: "计划来源"],
        .confidence: [.english: "Confidence", .simplifiedChinese: "置信度"],
        .relatedAssets: [.english: "Related Assets", .simplifiedChinese: "相关资产"],
        .organizationMap: [.english: "Organization Map", .simplifiedChinese: "整理地图"],
        .organizationPlan: [.english: "Organization Plan", .simplifiedChinese: "整理计划"],
        .organizing: [.english: "Asking AI for an organization plan", .simplifiedChinese: "正在让 AI 生成整理计划"],
        .mapReady: [.english: "Map ready", .simplifiedChinese: "地图已生成"],
        .mapUsesCurrentIndex: [.english: "Map uses the current index. Click Build Map to scan first when the index is empty or stale.", .simplifiedChinese: "地图基于当前索引生成。如果索引为空或过期，点击“生成地图”会先扫描再生成。"],
        .mapReadyWithCounts: [.english: "Map ready: %d assets in %d buckets.", .simplifiedChinese: "地图已生成：%d 个资产，%d 个分组。"],
        .scanningForOrganizationMap: [.english: "Scanning enabled sources before building the map.", .simplifiedChinese: "正在先扫描启用来源，然后生成地图。"],
        .scanCancelledForMap: [.english: "Map build cancelled with the scan.", .simplifiedChinese: "扫描已取消，地图生成也已取消。"],
        .localPlanReady: [.english: "Local plan ready", .simplifiedChinese: "本地计划已生成"],
        .aiPlanReady: [.english: "AI plan ready", .simplifiedChinese: "AI 计划已生成"],
        .aiPlanFailedUsingLocal: [.english: "AI plan failed. Showing the local plan instead.", .simplifiedChinese: "AI 计划失败，已显示本地计划。"],
        .openAIKeyRequiredForOrganizer: [.english: "Add an OpenAI API key in Settings to generate an AI plan.", .simplifiedChinese: "请先在设置中添加 OpenAI API key，才能生成 AI 计划。"],
        .appliedOrganizationActions: [.english: "Applied %d actions. %d approved items remain manual follow-up.", .simplifiedChinese: "已执行 %d 个操作。%d 个已批准项目保留为人工后续事项。"],
        .assets: [.english: "Assets", .simplifiedChinese: "资产"],
        .archive: [.english: "Archive", .simplifiedChinese: "归档"],
        .allSources: [.english: "All Sources", .simplifiedChinese: "全部来源"],
        .categories: [.english: "Categories", .simplifiedChinese: "分类"],
        .allCategories: [.english: "All Categories", .simplifiedChinese: "全部分类"],
        .health: [.english: "Health", .simplifiedChinese: "健康状态"],
        .allWarnings: [.english: "All Warnings", .simplifiedChinese: "全部警告"],
        .index: [.english: "Index", .simplifiedChinese: "索引"],
        .refresh: [.english: "Refresh", .simplifiedChinese: "刷新"],
        .refreshStaleIndex: [.english: "Refresh Stale Index", .simplifiedChinese: "刷新过期索引"],
        .cancel: [.english: "Cancel", .simplifiedChinese: "取消"],
        .explain: [.english: "Explain", .simplifiedChinese: "解释"],
        .stale: [.english: "Stale", .simplifiedChinese: "过期"],
        .searchPlaceholder: [.english: "Search files, summaries, paths, preview text", .simplifiedChinese: "搜索文件、摘要、路径、预览文本"],
        .reset: [.english: "Reset", .simplifiedChinese: "重置"],
        .resetFilters: [.english: "Reset Filters", .simplifiedChinese: "重置筛选"],
        .noMatchingAssets: [.english: "No matching assets", .simplifiedChinese: "没有匹配资产"],
        .noMatchingAssetsMessage: [.english: "The current source, health, category, or text filters hide all indexed files.", .simplifiedChinese: "当前来源、健康状态、分类或文本筛选隐藏了所有已索引文件。"],
        .selectAsset: [.english: "Select an asset", .simplifiedChinese: "选择一个资产"],
        .selectAssetMessage: [.english: "Choose a skill, memory, command, or config file to inspect.", .simplifiedChinese: "选择一个 skill、memory、command 或 config 文件进行检查。"],
        .archiveCenter: [.english: "Archive Center", .simplifiedChinese: "归档中心"],
        .archiveCenterMessage: [.english: "Restore archived files from the center pane, then refresh the index.", .simplifiedChinese: "在中间栏恢复归档文件，然后刷新索引。"],
        .restoreArchivedFilesHint: [.english: "Restore returns files to their original path.", .simplifiedChinese: "恢复会把文件放回原路径。"],
        .noArchivedAssets: [.english: "No archived assets", .simplifiedChinese: "暂无归档资产"],
        .noArchivedAssetsMessage: [.english: "Files you archive from Claude, Codex, Agents, or project sources will appear here.", .simplifiedChinese: "从 Claude、Codex、Agents 或项目来源归档的文件会显示在这里。"],
        .hiddenCenterMessage: [.english: "Restore hidden files from the center pane, or keep them out of the main index view.", .simplifiedChinese: "在中间栏恢复隐藏文件，或继续让它们不出现在主索引视图。"],
        .noHiddenAssets: [.english: "No hidden assets", .simplifiedChinese: "暂无隐藏资产"],
        .noHiddenAssetsMessage: [.english: "Files hidden from the main asset list will appear here until you restore them.", .simplifiedChinese: "从主资产列表隐藏的文件会显示在这里，直到你恢复它们。"],
        .restoreToAssets: [.english: "Restore to Assets", .simplifiedChinese: "恢复到资产列表"],
        .restore: [.english: "Restore", .simplifiedChinese: "恢复"],
        .showInFinder: [.english: "Show in Finder", .simplifiedChinese: "在 Finder 中显示"],
        .copyPath: [.english: "Copy Path", .simplifiedChinese: "复制路径"],
        .copyOriginalPath: [.english: "Copy Original Path", .simplifiedChinese: "复制原路径"],
        .hide: [.english: "Hide", .simplifiedChinese: "隐藏"],
        .hideFromObservatory: [.english: "Hide from Observatory", .simplifiedChinese: "从 Observatory 隐藏"],
        .archiveAction: [.english: "Archive", .simplifiedChinese: "归档"],
        .archiveFile: [.english: "Archive File", .simplifiedChinese: "归档文件"],
        .archiveConfirmationMessage: [.english: "The file will be moved out of its active agent location and can be restored from Archive.", .simplifiedChinese: "该文件会被移出当前 agent 生效目录，并且可以从归档中恢复。"],
        .archiveReason: [.english: "Reason", .simplifiedChinese: "原因"],
        .overview: [.english: "Overview", .simplifiedChinese: "概览"],
        .diff: [.english: "Diff", .simplifiedChinese: "差异"],
        .impact: [.english: "Impact", .simplifiedChinese: "影响"],
        .history: [.english: "History", .simplifiedChinese: "历史"],
        .raw: [.english: "Raw", .simplifiedChinese: "原文"],
        .whatItDoes: [.english: "What It Does", .simplifiedChinese: "它是做什么的"],
        .metadata: [.english: "Metadata", .simplifiedChinese: "元数据"],
        .diagnostics: [.english: "Diagnostics", .simplifiedChinese: "诊断"],
        .rawContent: [.english: "Raw Content", .simplifiedChinese: "原始内容"],
        .explainWithOpenAI: [.english: "Explain with OpenAI", .simplifiedChinese: "用 OpenAI 解释"],
        .loadFullContent: [.english: "Load Full Content", .simplifiedChinese: "加载全文"],
        .indexHealth: [.english: "Index Health", .simplifiedChinese: "索引健康"],
        .riskQueue: [.english: "Risk Queue", .simplifiedChinese: "风险队列"],
        .claudeCodexDrift: [.english: "Claude vs Codex Drift", .simplifiedChinese: "Claude 与 Codex 差异"],
        .recentChanges: [.english: "Recent Changes", .simplifiedChinese: "最近变化"],
        .dependencyHotspots: [.english: "Dependency Hotspots", .simplifiedChinese: "依赖热点"],
        .aiCoverage: [.english: "AI Coverage", .simplifiedChinese: "AI 覆盖率"],
        .noDashboardRisks: [.english: "No dashboard risks found in the current index.", .simplifiedChinese: "当前索引中没有发现仪表盘风险。"],
        .noRecentChanges: [.english: "No changes compared with the previous completed scan.", .simplifiedChinese: "与上一次完成扫描相比没有变化。"],
        .noDependencyHotspots: [.english: "No dependency hotspots found yet.", .simplifiedChinese: "暂未发现依赖热点。"],
        .indexCurrent: [.english: "Index is current", .simplifiedChinese: "索引是最新的"],
        .noAssetsIndexed: [.english: "No assets indexed yet.", .simplifiedChinese: "尚未索引任何资产。"],
        .dashboardSubtitle: [.english: "Prioritized view of local agent configuration health.", .simplifiedChinese: "本地 agent 配置健康状态的优先级视图。"],
        .sourceFilesChangedAfterScan: [.english: "Source files changed after the last scan.", .simplifiedChinese: "源文件在上次扫描后发生了变化。"],
        .items: [.english: "items", .simplifiedChinese: "项"],
        .scanningSelectedSources: [.english: "Scanning selected sources", .simplifiedChinese: "正在扫描选中的来源"],
        .readyToScan: [.english: "Ready to scan", .simplifiedChinese: "准备扫描"],
        .updated: [.english: "Updated", .simplifiedChinese: "已更新"],
        .scanCancelled: [.english: "Scan cancelled", .simplifiedChinese: "扫描已取消"],
        .indexStaleStatus: [.english: "Index stale", .simplifiedChinese: "索引已过期"],
        .loadingFullContent: [.english: "Loading full content", .simplifiedChinese: "正在加载全文"],
        .noRawContentLoaded: [.english: "No raw content loaded.", .simplifiedChinese: "尚未加载原始内容。"],
        .emptyFile: [.english: "Empty file", .simplifiedChinese: "空文件"],
        .usesRedactedPreviewTextOnly: [.english: "Uses redacted preview text only.", .simplifiedChinese: "只使用脱敏后的预览文本。"],
        .finder: [.english: "Finder", .simplifiedChinese: "Finder"],
        .ok: [.english: "OK", .simplifiedChinese: "正常"],
        .toggleSidebar: [.english: "Toggle sidebar", .simplifiedChinese: "切换侧边栏"],
        .clearSearch: [.english: "Clear search", .simplifiedChinese: "清空搜索"],
        .name: [.english: "Name", .simplifiedChinese: "名称"],
        .kind: [.english: "Kind", .simplifiedChinese: "类型"],
        .source: [.english: "Source", .simplifiedChinese: "来源"],
        .status: [.english: "Status", .simplifiedChinese: "状态"],
        .modified: [.english: "Modified", .simplifiedChinese: "修改时间"],
        .size: [.english: "Size", .simplifiedChinese: "大小"],
        .unknown: [.english: "Unknown", .simplifiedChinese: "未知"],
        .owner: [.english: "Owner", .simplifiedChinese: "归属"],
        .all: [.english: "All", .simplifiedChinese: "全部"],
        .visited: [.english: "visited", .simplifiedChinese: "已访问"],
        .found: [.english: "found", .simplifiedChinese: "已发现"],
        .files: [.english: "files", .simplifiedChinese: "文件"],
        .scanPreparingRoots: [.english: "Preparing scan roots", .simplifiedChinese: "正在准备扫描根目录"],
        .scanCollectingCandidates: [.english: "Collecting candidate files", .simplifiedChinese: "正在收集候选文件"],
        .scanProcessingCandidate: [.english: "Processing candidate file", .simplifiedChinese: "正在处理候选文件"],
        .scanFinalizing: [.english: "Checking duplicates and sorting", .simplifiedChinese: "正在检查重复项并排序"],
        .scanCompleted: [.english: "Scan completed", .simplifiedChinese: "扫描完成"],
        .finished: [.english: "Finished", .simplifiedChinese: "已完成"],
        .skipped: [.english: "Skipped", .simplifiedChinese: "跳过"],
        .directories: [.english: "directories", .simplifiedChinese: "目录"],
        .readErrors: [.english: "read errors", .simplifiedChinese: "读取错误"],
        .warnings: [.english: "Warnings", .simplifiedChinese: "警告"],
        .needsAttention: [.english: "Needs attention", .simplifiedChinese: "需要关注"],
        .changed: [.english: "Changed", .simplifiedChinese: "已变化"],
        .same: [.english: "Same", .simplifiedChinese: "相同"],
        .added: [.english: "Added", .simplifiedChinese: "新增"],
        .removed: [.english: "Removed", .simplifiedChinese: "移除"],
        .comparableNames: [.english: "comparable names", .simplifiedChinese: "个可比较名称"],
        .reviewRelated: [.english: "Review Related", .simplifiedChinese: "查看相关项"],
        .explained: [.english: "explained", .simplifiedChinese: "已解释"],
        .incoming: [.english: "incoming", .simplifiedChinese: "传入"],
        .outgoing: [.english: "outgoing", .simplifiedChinese: "传出"],
        .current: [.english: "Current", .simplifiedChinese: "当前"],
        .asset: [.english: "asset", .simplifiedChinese: "资产"],
        .links: [.english: "links", .simplifiedChinese: "链接"],
        .hash: [.english: "Hash", .simplifiedChinese: "哈希"],
        .scope: [.english: "Scope", .simplifiedChinese: "范围"],
        .trigger: [.english: "Trigger", .simplifiedChinese: "触发方式"],
        .noLocalIssuesDetected: [.english: "No local issues detected in the first-pass scan.", .simplifiedChinese: "首轮扫描未发现本地问题。"],
        .duplicateMessage: [.english: "Another asset has the same normalized name and type.", .simplifiedChinese: "另一个资产拥有相同的规范化名称和类型。"],
        .stalePathMessage: [.english: "This non-Claude file still references a Claude-era path.", .simplifiedChinese: "这个非 Claude 文件仍引用 Claude 时期的路径。"],
        .hasScriptsMessage: [.english: "The asset points at scripts or has script files nearby.", .simplifiedChinese: "该资产指向脚本，或附近存在脚本文件。"],
        .needsSummaryMessage: [.english: "No explicit description was found locally.", .simplifiedChinese: "本地没有找到明确描述。"],
        .secretRiskMessage: [.english: "Preview and LLM enrichment avoid sending likely secret material.", .simplifiedChinese: "预览和 LLM 增强会避开发送疑似密钥内容。"],
        .largeFileMessage: [.english: "The file was too large for full local preview.", .simplifiedChinese: "该文件过大，不适合自动完整预览。"],
        .unreadableMessage: [.english: "The scanner could not read this file.", .simplifiedChinese: "扫描器无法读取该文件。"],
        .noCounterpartFound: [.english: "No same-name counterpart was found across the indexed stores.", .simplifiedChinese: "已索引位置中没有找到同名对应项。"],
        .fieldChanges: [.english: "Field Changes", .simplifiedChinese: "字段变化"],
        .base: [.english: "Base", .simplifiedChinese: "基准"],
        .counterpart: [.english: "Counterpart", .simplifiedChinese: "对应项"],
        .openRelatedAsset: [.english: "Open related asset", .simplifiedChinese: "打开相关资产"],
        .unresolvedReference: [.english: "Unresolved reference", .simplifiedChinese: "未解析引用"],
        .incomingReferences: [.english: "Incoming References", .simplifiedChinese: "传入引用"],
        .outgoingReferences: [.english: "Outgoing References", .simplifiedChinese: "传出引用"],
        .noIncomingReferences: [.english: "No indexed asset references this file.", .simplifiedChinese: "没有已索引资产引用该文件。"],
        .noOutgoingReferences: [.english: "This asset has no indexed path or script dependencies.", .simplifiedChinese: "该资产没有已索引路径或脚本依赖。"],
        .indexStaleMessage: [.english: "Index stale: source files changed after the last scan.", .simplifiedChinese: "索引已过期：源文件在上次扫描后发生变化。"],
        .indexCurrentMessage: [.english: "Index is current for the last completed scan.", .simplifiedChinese: "索引与最近一次完成扫描一致。"],
        .lastFileEvent: [.english: "Last file event", .simplifiedChinese: "最近文件事件"],
        .noChangesInLatestComparison: [.english: "No assets in the latest scan comparison.", .simplifiedChinese: "最近一次扫描对比中没有资产。"],
        .hidden: [.english: "Hidden", .simplifiedChinese: "已隐藏"],
        .duplicates: [.english: "Duplicates", .simplifiedChinese: "重复项"],
        .stalePaths: [.english: "Stale Paths", .simplifiedChinese: "过期路径"],
        .secrets: [.english: "Secrets", .simplifiedChinese: "密钥风险"],
        .explaining: [.english: "Explaining", .simplifiedChinese: "正在解释"],
        .path: [.english: "Path", .simplifiedChinese: "路径"],
        .summary: [.english: "Summary", .simplifiedChinese: "摘要"],
        .dependencies: [.english: "Dependencies", .simplifiedChinese: "依赖"],
        .relatedFiles: [.english: "Related Files", .simplifiedChinese: "相关文件"],
        .statusFlags: [.english: "Status Flags", .simplifiedChinese: "状态标记"],
        .frontmatterName: [.english: "Frontmatter Name", .simplifiedChinese: "Frontmatter 名称"],
        .frontmatterDescription: [.english: "Frontmatter Description", .simplifiedChinese: "Frontmatter 描述"],
        .previewHash: [.english: "Preview Hash", .simplifiedChinese: "预览哈希"]
    ]
}
