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
        case addWorkspaceMemoryFolder
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
        case modelPreset
        case customModel
        case baseURL
        case openAIBaseURLDescription
        case aiAuditTrail
        case noAIAuditRecords
        case aiAuditPrivacyNote
        case save
        case management
        case archiveLocation
        case archiveLocationDescription
        case archivedItems
        case hiddenItems
        case unhideAll
        case dashboard
        case aiOrganizer
        case contextBrowser
        case contextBrowserSubtitle
        case memories
        case capabilities
        case assembly
        case allFiles
        case surfaces
        case claudeCode
        case sharedAgents
        case memoryDomain
        case capabilityDomain
        case finalContext
        case viewMemories
        case viewCapabilities
        case viewAssembly
        case contextDetailPlaceholder
        case contextDetailPlaceholderMessage
        case longTermMemory
        case projectMemory
        case workspaceMemory
        case sharedContext
        case pluginProvidedContext
        case configurationContext
        case sessionContext
        case contextLayerGlobal
        case contextLayerProject
        case contextLayerWorkspace
        case contextRoleMemory
        case contextRoleCapability
        case usedBy
        case layer
        case noContextItems
        case memoryTypeOverview
        case chooseMemoryType
        case showingItems
        case showMore
        case assembledFor
        case contextPipelineEmpty
        case advisorTitle
        case advisorSubtitle
        case advancedDetails
        case configurationBrief
        case currentShape
        case priorityFocus
        case recommendedNextStep
        case runRecommendedReview
        case organizeNow
        case organizerRunReady
        case organizerRunScanning
        case organizerRunReviewTitle
        case organizerRunReviewSubtitle
        case organizerRunCurrentState
        case organizerRunActionPacks
        case organizerRunNoActions
        case organizerRunAgreeAndApply
        case organizerRunViewDetails
        case organizerRunReversible
        case organizerRunManualReview
        case organizerRunAutomatic
        case organizerRunProtected
        case organizerRunReviewPack
        case actionPackReviewTitle
        case actionPackReviewSubtitle
        case copyAffectedPaths
        case openFirstAffectedFile
        case sensitiveActionGuidance
        case unreadableActionGuidance
        case clarifyActionGuidance
        case stalePathActionGuidance
        case moreCleanupActions
        case presetRecommendedDescription
        case presetClassify
        case presetCopyBrief
        case organizerBriefCopied
        case cleanupPreviewTitle
        case cleanupPreviewSubtitle
        case cleanupPreviewAgree
        case cleanupPreviewDone
        case cleanupPreviewNoAutomaticChanges
        case cleanupPreviewManualOnly
        case cleanupPreviewWillHide
        case cleanupPreviewWillMerge
        case cleanupPreviewWillArchive
        case cleanupPreviewManualGroups
        case aiPlanNotes
        case organizerSubtitle
        case organizerDetailMessage
        case organizerInspector
        case organizerInspectorMessage
        case recommendationDetail
        case bucketDetail
        case primaryAsset
        case openPrimaryAsset
        case approveForApply
        case manualFollowUp
        case manualRecommendationRequired
        case manualRecommendationRequiredMessage
        case noExecutableApprovedActions
        case mergedIntoArchiveReason
        case affectedAssets
        case cleanupReview
        case cleanupReviewSubtitle
        case cleanupGoal
        case startCleanupReview
        case cleanupGroups
        case executableActions
        case inventoryEvidence
        case noCleanupGroups
        case recommendedAction
        case cleanupEvidence
        case openGroup
        case applyApprovedCleanup
        case cleanupReviewReadyWithCounts
        case scanningForCleanupReview
        case scanCancelledForCleanupReview
        case appliedCleanupActions
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
        case aiPlanErrorPrefix
        case openAIKeyRequiredForOrganizer
        case appliedOrganizationActions
        case sensitiveFilesNotSentToOpenAI
        case archivedFileStatus
        case restoredFileStatus
        case hiddenFileStatus
        case unhiddenFileStatus
        case latestOperation
        case operationHistory
        case operationResult
        case noOperationHistory
        case undoLatestOperation
        case operationBatchApplied
        case operationBatchUndone
        case operationUndoNotAvailable
        case affectedFiles
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
        case rawSensitiveFileHidden
        case showRedactedLocalPreview
        case redactedLocalPreviewNote
        case rawLargeFileRequiresExplicitLoad
        case rawFileTooLargeForInline
        case rawUnableToReadFile
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

    public static func planSource(_ source: String, language: AppLanguage) -> String {
        switch source.lowercased() {
        case "openai + local":
            language == .simplifiedChinese ? "OpenAI + 本地" : "OpenAI + local"
        case "openai":
            "OpenAI"
        case "local":
            language == .simplifiedChinese ? "本地" : "Local"
        case "empty":
            language == .simplifiedChinese ? "空" : "Empty"
        default:
            source
        }
    }

    public static func cleanupGoal(_ goal: CleanupReviewGoal, language: AppLanguage) -> String {
        switch (goal, language) {
        case (.fullReview, .simplifiedChinese): "完整整理"
        case (.legacyClaudeCleanup, .simplifiedChinese): "清理 Claude 旧配置"
        case (.duplicateCleanup, .simplifiedChinese): "合并重复项"
        case (.noiseCleanup, .simplifiedChinese): "隐藏噪音"
        case (.riskCleanup, .simplifiedChinese): "检查风险"
        default: goal.rawValue
        }
    }

    public static func cleanupAction(_ action: CleanupReviewAction, language: AppLanguage) -> String {
        switch (action, language) {
        case (.archive, .simplifiedChinese): "归档"
        case (.hide, .simplifiedChinese): "隐藏"
        case (.merge, .simplifiedChinese): "合并"
        case (.review, .simplifiedChinese): "复核"
        case (.keep, .simplifiedChinese): "保留"
        default: action.rawValue
        }
    }

    public static func cleanupRisk(_ risk: CleanupReviewRisk, language: AppLanguage) -> String {
        switch (risk, language) {
        case (.low, .simplifiedChinese): "低风险"
        case (.medium, .simplifiedChinese): "中风险"
        case (.high, .simplifiedChinese): "高风险"
        case (.low, _): "Low risk"
        case (.medium, _): "Medium risk"
        case (.high, _): "High risk"
        }
    }

    public static func memoryType(_ type: AgentMemoryType, language: AppLanguage) -> String {
        switch (type, language) {
        case (.longTerm, .simplifiedChinese): "长期记忆"
        case (.project, .simplifiedChinese): "项目记忆"
        case (.workspace, .simplifiedChinese): "工作区记忆"
        case (.automation, .simplifiedChinese): "自动化记忆"
        case (.preference, .simplifiedChinese): "偏好与工具记忆"
        case (.sessionHistory, .simplifiedChinese): "会话历史"
        case (.shared, .simplifiedChinese): "共享记忆"
        case (.instructions, .simplifiedChinese): "入口指令"
        case (.contextRules, .simplifiedChinese): "上下文规则"
        case (.pluginProvided, .simplifiedChinese): "插件注入上下文"
        case (.longTerm, _): "Long-term Memory"
        case (.project, _): "Project Memory"
        case (.workspace, _): "Workspace Memory"
        case (.automation, _): "Automation Memory"
        case (.preference, _): "Preference and Tool Memory"
        case (.sessionHistory, _): "Session History"
        case (.shared, _): "Shared Memory"
        case (.instructions, _): "Entry Instructions"
        case (.contextRules, _): "Context Rules"
        case (.pluginProvided, _): "Plugin-injected Context"
        }
    }

    public static func memoryTypeDescription(_ type: AgentMemoryType, language: AppLanguage) -> String {
        switch (type, language) {
        case (.longTerm, .simplifiedChinese): "跨会话保留的长期事实、总结和原始记忆。"
        case (.project, .simplifiedChinese): "按项目或当前仓库生效的 CLAUDE、AGENTS 与 project memory。"
        case (.workspace, .simplifiedChinese): "按工作区或 workspace 目录生效的上下文。"
        case (.automation, .simplifiedChinese): "定时任务、自动化流程自己保存的运行记忆。"
        case (.preference, .simplifiedChinese): "用户偏好、常用工具和工作流选择。"
        case (.sessionHistory, .simplifiedChinese): "会话总结、rollout summary、plans 和历史记录。"
        case (.shared, .simplifiedChinese): "Claude Code 与 Codex 都可能复用的共享 agent 上下文。"
        case (.instructions, .simplifiedChinese): "入口级系统说明、AGENTS.md、CLAUDE.md。"
        case (.contextRules, .simplifiedChinese): "规则文件、设计规范和运行时约束。"
        case (.pluginProvided, .simplifiedChinese): "插件、市场和 skill 包注入的说明性上下文。"
        case (.longTerm, _): "Durable facts, summaries, and raw memory retained across sessions."
        case (.project, _): "Project-scoped CLAUDE, AGENTS, and project memory files."
        case (.workspace, _): "Workspace-scoped context from workspace folders."
        case (.automation, _): "Memory owned by scheduled automations and recurring workflows."
        case (.preference, _): "User preferences, favorite tools, and workflow choices."
        case (.sessionHistory, _): "Session summaries, rollout summaries, plans, and history."
        case (.shared, _): "Shared agent context that Claude Code and Codex can both reuse."
        case (.instructions, _): "Entry-level instructions such as AGENTS.md and CLAUDE.md."
        case (.contextRules, _): "Rule files, design rules, and runtime constraints."
        case (.pluginProvided, _): "Instructional context injected by plugins, marketplaces, and skill bundles."
        }
    }

    public static func managementOperationKind(_ kind: ManagementOperationKind, language: AppLanguage) -> String {
        switch (kind, language) {
        case (.hide, .simplifiedChinese): "隐藏"
        case (.archive, .simplifiedChinese): "归档"
        case (.mergeArchive, .simplifiedChinese): "合并归档"
        case (.hide, _): "Hide"
        case (.archive, _): "Archive"
        case (.mergeArchive, _): "Merge archive"
        }
    }

    public static func managementOperationStatus(_ status: ManagementOperationStatus, language: AppLanguage) -> String {
        switch (status, language) {
        case (.applied, .simplifiedChinese): "已执行"
        case (.failed, .simplifiedChinese): "失败"
        case (.undone, .simplifiedChinese): "已撤销"
        case (.undoFailed, .simplifiedChinese): "撤销失败"
        case (.applied, _): "Applied"
        case (.failed, _): "Failed"
        case (.undone, _): "Undone"
        case (.undoFailed, _): "Undo failed"
        }
    }

    public static func managementOperationSource(_ source: ManagementOperationSource, language: AppLanguage) -> String {
        switch (source, language) {
        case (.manual, .simplifiedChinese): "手动"
        case (.cleanupReview, .simplifiedChinese): "整理审查"
        case (.aiOrganizer, .simplifiedChinese): "AI 整理器"
        case (.manual, _): "Manual"
        case (.cleanupReview, _): "Cleanup review"
        case (.aiOrganizer, _): "AI organizer"
        }
    }

    public static func aiAuditOperation(_ operation: AIAuditOperation, language: AppLanguage) -> String {
        switch (operation, language) {
        case (.assetExplanation, .simplifiedChinese): "文件解释"
        case (.organizationPlan, .simplifiedChinese): "整理规划"
        case (.assetExplanation, _): "Asset explanation"
        case (.organizationPlan, _): "Organization plan"
        }
    }

    public static func aiAuditStatus(_ status: AIAuditStatus, language: AppLanguage) -> String {
        switch (status, language) {
        case (.started, .simplifiedChinese): "进行中"
        case (.succeeded, .simplifiedChinese): "成功"
        case (.failed, .simplifiedChinese): "失败"
        case (.cancelled, .simplifiedChinese): "已取消"
        case (.started, _): "Started"
        case (.succeeded, _): "Succeeded"
        case (.failed, _): "Failed"
        case (.cancelled, _): "Cancelled"
        }
    }

    public static func organizerActionPackKind(_ kind: OrganizerActionPackKind, language: AppLanguage) -> String {
        switch (kind, language) {
        case (.mergeDuplicates, .simplifiedChinese): "合并重复"
        case (.hideNoise, .simplifiedChinese): "隐藏噪音"
        case (.reviewSensitive, .simplifiedChinese): "保护敏感文件"
        case (.reviewUnreadable, .simplifiedChinese): "检查不可读文件"
        case (.clarifyUnknown, .simplifiedChinese): "澄清说明"
        case (.reviewStalePaths, .simplifiedChinese): "复核旧路径"
        case (.mergeDuplicates, _): "Merge duplicates"
        case (.hideNoise, _): "Hide noise"
        case (.reviewSensitive, _): "Protect sensitive files"
        case (.reviewUnreadable, _): "Check unreadable files"
        case (.clarifyUnknown, _): "Clarify descriptions"
        case (.reviewStalePaths, _): "Review stale paths"
        }
    }

    public static func organizerActionPackRisk(_ risk: OrganizerActionPackRisk, language: AppLanguage) -> String {
        switch (risk, language) {
        case (.low, .simplifiedChinese): "低风险"
        case (.medium, .simplifiedChinese): "中风险"
        case (.high, .simplifiedChinese): "高风险"
        case (.low, _): "Low risk"
        case (.medium, _): "Medium risk"
        case (.high, _): "High risk"
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
        .addWorkspaceMemoryFolder: [.english: "Add Workspace Memory Folder", .simplifiedChinese: "添加工作区记忆文件夹"],
        .resetDefaults: [.english: "Reset Defaults", .simplifiedChinese: "恢复默认"],
        .custom: [.english: "Custom", .simplifiedChinese: "自定义"],
        .exists: [.english: "Exists", .simplifiedChinese: "存在"],
        .missing: [.english: "Missing", .simplifiedChinese: "缺失"],
        .removeCustomSource: [.english: "Remove custom source", .simplifiedChinese: "移除自定义来源"],
        .openAI: [.english: "OpenAI", .simplifiedChinese: "OpenAI"],
        .openAIDescription: [.english: "The app sends only redacted file previews for per-file explanations. Sensitive files such as auth.json are never previewed.", .simplifiedChinese: "应用只会发送经过脱敏的文件预览用于逐文件解释。auth.json 等敏感文件永远不会被预览。"],
        .apiKey: [.english: "API key", .simplifiedChinese: "API key"],
        .model: [.english: "Model", .simplifiedChinese: "模型"],
        .modelDescription: [.english: "Default model is gpt-5.5. You can type any OpenAI model name your account can use.", .simplifiedChinese: "默认模型为 gpt-5.5。你也可以输入当前账号可用的任意 OpenAI 模型名。"],
        .modelPreset: [.english: "Model Preset", .simplifiedChinese: "模型预设"],
        .customModel: [.english: "Custom", .simplifiedChinese: "自定义"],
        .baseURL: [.english: "Base URL", .simplifiedChinese: "Base URL"],
        .openAIBaseURLDescription: [.english: "Use https://api.openai.com/v1 for OpenAI. The app appends /responses automatically.", .simplifiedChinese: "OpenAI 默认使用 https://api.openai.com/v1。应用会自动拼接 /responses。"],
        .aiAuditTrail: [.english: "AI Audit Trail", .simplifiedChinese: "AI 审计记录"],
        .noAIAuditRecords: [.english: "No AI requests recorded yet.", .simplifiedChinese: "尚未记录 AI 请求。"],
        .aiAuditPrivacyNote: [.english: "Audit records keep model, endpoint, status, and counts only. Prompts and file contents are not stored.", .simplifiedChinese: "审计记录只保存模型、端点、状态和数量，不保存 prompt 或文件内容。"],
        .save: [.english: "Save", .simplifiedChinese: "保存"],
        .management: [.english: "Management", .simplifiedChinese: "管理"],
        .archiveLocation: [.english: "Archive Location", .simplifiedChinese: "归档位置"],
        .archiveLocationDescription: [.english: "Archived files are moved out of active agent locations and can be restored later.", .simplifiedChinese: "归档文件会移出 agent 生效目录，并且之后可以恢复。"],
        .archivedItems: [.english: "Archived Items", .simplifiedChinese: "已归档项目"],
        .hiddenItems: [.english: "Hidden Items", .simplifiedChinese: "隐藏项目"],
        .unhideAll: [.english: "Unhide All", .simplifiedChinese: "全部取消隐藏"],
        .dashboard: [.english: "Dashboard", .simplifiedChinese: "仪表盘"],
        .aiOrganizer: [.english: "AI Organizer", .simplifiedChinese: "AI 整理器"],
        .contextBrowser: [.english: "Context Browser", .simplifiedChinese: "上下文浏览器"],
        .contextBrowserSubtitle: [.english: "See what Claude Code and Codex remember, which capabilities they can call, and how those pieces assemble into the final agent context.", .simplifiedChinese: "查看 Claude Code 和 Codex 记住了什么、能调用哪些能力，以及这些内容如何组装成最终上下文。"],
        .memories: [.english: "Memories", .simplifiedChinese: "记忆"],
        .capabilities: [.english: "Capabilities", .simplifiedChinese: "能力"],
        .assembly: [.english: "Assembly", .simplifiedChinese: "组装"],
        .allFiles: [.english: "All Files", .simplifiedChinese: "全部文件"],
        .surfaces: [.english: "Surfaces", .simplifiedChinese: "工具域"],
        .claudeCode: [.english: "Claude Code", .simplifiedChinese: "Claude Code"],
        .sharedAgents: [.english: "Shared Agents", .simplifiedChinese: "共享 Agents"],
        .memoryDomain: [.english: "Memory Domain", .simplifiedChinese: "记忆域"],
        .capabilityDomain: [.english: "Capability Domain", .simplifiedChinese: "能力域"],
        .finalContext: [.english: "Final Context", .simplifiedChinese: "最终上下文"],
        .viewMemories: [.english: "View Memories", .simplifiedChinese: "查看记忆"],
        .viewCapabilities: [.english: "View Capabilities", .simplifiedChinese: "查看能力"],
        .viewAssembly: [.english: "View Assembly", .simplifiedChinese: "查看组装"],
        .contextDetailPlaceholder: [.english: "Select a context item", .simplifiedChinese: "选择一个上下文项目"],
        .contextDetailPlaceholderMessage: [.english: "Choose a memory, skill, plugin, command, or assembly item to inspect its source file.", .simplifiedChinese: "选择一条记忆、skill、插件、command 或组装项目后，在这里检查源文件。"],
        .longTermMemory: [.english: "Long-term Memory", .simplifiedChinese: "长期记忆"],
        .projectMemory: [.english: "Project Memory", .simplifiedChinese: "项目记忆"],
        .workspaceMemory: [.english: "Workspace Memory", .simplifiedChinese: "工作区记忆"],
        .sharedContext: [.english: "Shared Context", .simplifiedChinese: "共享上下文"],
        .pluginProvidedContext: [.english: "Plugin-provided Context", .simplifiedChinese: "插件提供的上下文"],
        .configurationContext: [.english: "Configuration", .simplifiedChinese: "配置"],
        .sessionContext: [.english: "Session Context", .simplifiedChinese: "会话上下文"],
        .contextLayerGlobal: [.english: "Global Context", .simplifiedChinese: "全局上下文"],
        .contextLayerProject: [.english: "Project Context", .simplifiedChinese: "项目上下文"],
        .contextLayerWorkspace: [.english: "Workspace Context", .simplifiedChinese: "工作区上下文"],
        .contextRoleMemory: [.english: "Memory", .simplifiedChinese: "记忆"],
        .contextRoleCapability: [.english: "Capability", .simplifiedChinese: "能力"],
        .usedBy: [.english: "Used by", .simplifiedChinese: "使用者"],
        .layer: [.english: "Layer", .simplifiedChinese: "层级"],
        .noContextItems: [.english: "No matching context items.", .simplifiedChinese: "没有匹配的上下文项目。"],
        .memoryTypeOverview: [.english: "Memory Types", .simplifiedChinese: "记忆类型"],
        .chooseMemoryType: [.english: "Choose a type, then inspect only that bucket.", .simplifiedChinese: "先选类型，再只查看这一类。"],
        .showingItems: [.english: "Showing %d of %d items", .simplifiedChinese: "显示 %d / %d 项"],
        .showMore: [.english: "Show More", .simplifiedChinese: "显示更多"],
        .assembledFor: [.english: "Assembled for", .simplifiedChinese: "组装给"],
        .contextPipelineEmpty: [.english: "No context pipeline yet. Refresh the index to scan enabled sources.", .simplifiedChinese: "尚无上下文组装链路。刷新索引以扫描启用来源。"],
        .advisorTitle: [.english: "AI Organization Advisor", .simplifiedChinese: "AI 整理顾问"],
        .advisorSubtitle: [.english: "Start with one recommended cleanup. The app explains the changes before anything is applied.", .simplifiedChinese: "从一次推荐整理开始。应用会先说明改动，再由你确认执行。"],
        .advancedDetails: [.english: "Advanced Details", .simplifiedChinese: "高级细节"],
        .configurationBrief: [.english: "Configuration Brief", .simplifiedChinese: "配置概览"],
        .currentShape: [.english: "Current Shape", .simplifiedChinese: "当前结构"],
        .priorityFocus: [.english: "Priority Focus", .simplifiedChinese: "优先关注"],
        .recommendedNextStep: [.english: "Recommended", .simplifiedChinese: "推荐"],
        .runRecommendedReview: [.english: "Recommended Cleanup", .simplifiedChinese: "推荐整理"],
        .organizeNow: [.english: "Organize Now", .simplifiedChinese: "整理一下"],
        .organizerRunReady: [.english: "Organizer plan ready.", .simplifiedChinese: "整理计划已准备好。"],
        .organizerRunScanning: [.english: "Scanning enabled sources before preparing the organizer plan.", .simplifiedChinese: "正在先扫描启用来源，然后准备整理计划。"],
        .organizerRunReviewTitle: [.english: "Review Organizer Plan", .simplifiedChinese: "查看整理计划"],
        .organizerRunReviewSubtitle: [.english: "These are the changes the app can make after one approval.", .simplifiedChinese: "这是应用在一次确认后可以执行的改动。"],
        .organizerRunCurrentState: [.english: "Current State", .simplifiedChinese: "当前状态"],
        .organizerRunActionPacks: [.english: "Action Packs", .simplifiedChinese: "行动包"],
        .organizerRunNoActions: [.english: "No automatic action packs. Review the details manually.", .simplifiedChinese: "没有可自动执行的行动包，请人工查看细节。"],
        .organizerRunAgreeAndApply: [.english: "Agree and Apply", .simplifiedChinese: "同意执行"],
        .organizerRunViewDetails: [.english: "View Details", .simplifiedChinese: "查看细节"],
        .organizerRunReversible: [.english: "Reversible", .simplifiedChinese: "可撤销"],
        .organizerRunManualReview: [.english: "Manual review", .simplifiedChinese: "人工复核"],
        .organizerRunAutomatic: [.english: "Automatic", .simplifiedChinese: "自动执行"],
        .organizerRunProtected: [.english: "Protected", .simplifiedChinese: "受保护"],
        .organizerRunReviewPack: [.english: "Review", .simplifiedChinese: "复核"],
        .actionPackReviewTitle: [.english: "Manual Review", .simplifiedChinese: "人工复核"],
        .actionPackReviewSubtitle: [.english: "These items are protected. The app will not change them automatically.", .simplifiedChinese: "这些项目受保护，应用不会自动改动。"],
        .copyAffectedPaths: [.english: "Copy Paths", .simplifiedChinese: "复制路径"],
        .openFirstAffectedFile: [.english: "Open First File", .simplifiedChinese: "打开第一个文件"],
        .sensitiveActionGuidance: [.english: "Open the files one by one to confirm permissions, contents, and whether they should stay visible. Sensitive content is not sent to AI.", .simplifiedChinese: "逐个打开文件，确认权限、内容以及是否需要继续保留可见。敏感内容不会发送给 AI。"],
        .unreadableActionGuidance: [.english: "The scanner could not read these files. Reveal them in Finder or copy the paths, then check permissions or whether the files still exist.", .simplifiedChinese: "扫描器无法读取这些文件。可以在 Finder 中定位或复制路径，再检查权限或文件是否仍存在。"],
        .clarifyActionGuidance: [.english: "Open each file and add a clearer summary, description, or name before deciding whether it should be archived or merged.", .simplifiedChinese: "逐个打开文件，先补充更清晰的 summary、description 或名称，再决定是否归档或合并。"],
        .stalePathActionGuidance: [.english: "Open each file and inspect stale path references. Migrate the references or archive the file only after manual confirmation.", .simplifiedChinese: "逐个打开文件检查旧路径引用。确认后再迁移引用或归档文件。"],
        .moreCleanupActions: [.english: "More", .simplifiedChinese: "更多"],
        .presetRecommendedDescription: [.english: "Review the planned changes, then approve once.", .simplifiedChinese: "先看计划改动，再一次确认执行。"],
        .presetClassify: [.english: "View Classification Map", .simplifiedChinese: "查看分类地图"],
        .presetCopyBrief: [.english: "Copy Diagnosis Brief", .simplifiedChinese: "复制诊断简报"],
        .organizerBriefCopied: [.english: "Diagnosis brief copied to clipboard.", .simplifiedChinese: "诊断简报已复制到剪贴板。"],
        .cleanupPreviewTitle: [.english: "Ready to Apply", .simplifiedChinese: "准备执行"],
        .cleanupPreviewSubtitle: [.english: "Review what will happen. Nothing changes until you agree.", .simplifiedChinese: "先看清楚会发生什么。点同意前不会改动文件。"],
        .cleanupPreviewAgree: [.english: "Agree and Apply", .simplifiedChinese: "同意并执行"],
        .cleanupPreviewDone: [.english: "Done", .simplifiedChinese: "完成"],
        .cleanupPreviewNoAutomaticChanges: [.english: "No automatic file changes. The review queue is ready for manual inspection.", .simplifiedChinese: "不会自动改动文件。复核队列已准备好，供你人工查看。"],
        .cleanupPreviewManualOnly: [.english: "Review queue ready. No automatic file changes were applied.", .simplifiedChinese: "复核队列已准备好，没有自动改动文件。"],
        .cleanupPreviewWillHide: [.english: "Hide %d low-signal items from the active view.", .simplifiedChinese: "从活跃视图隐藏 %d 个低信号项目。"],
        .cleanupPreviewWillMerge: [.english: "Merge duplicates by keeping primary files and archiving %d related duplicates.", .simplifiedChinese: "执行合并：保留主文件，并归档 %d 个相关重复项。"],
        .cleanupPreviewWillArchive: [.english: "Archive %d files so they can be restored later.", .simplifiedChinese: "归档 %d 个文件，之后可恢复。"],
        .cleanupPreviewManualGroups: [.english: "%d groups will remain for manual review.", .simplifiedChinese: "%d 个分组会保留为人工复核。"],
        .aiPlanNotes: [.english: "AI Plan Notes", .simplifiedChinese: "AI 规划备注"],
        .organizerSubtitle: [.english: "Map local agent assets, ask AI for conservative cleanup advice, then approve exactly what should be applied.", .simplifiedChinese: "先映射本地 agent 资产，再让 AI 给出保守整理建议，最后只执行你明确批准的操作。"],
        .organizerDetailMessage: [.english: "Use the center pane to build a map, generate a plan, and approve archive or hide actions.", .simplifiedChinese: "在中间栏生成资产地图、整理计划，并批准归档或隐藏操作。"],
        .organizerInspector: [.english: "Organizer Inspector", .simplifiedChinese: "整理器检查器"],
        .organizerInspectorMessage: [.english: "Select a bucket or recommendation to inspect details here.", .simplifiedChinese: "选择一个分组或建议后，在这里查看详情。"],
        .recommendationDetail: [.english: "Recommendation Detail", .simplifiedChinese: "建议详情"],
        .bucketDetail: [.english: "Bucket Detail", .simplifiedChinese: "分组详情"],
        .primaryAsset: [.english: "Primary Asset", .simplifiedChinese: "主资产"],
        .openPrimaryAsset: [.english: "Open Primary Asset", .simplifiedChinese: "打开主资产"],
        .approveForApply: [.english: "Approve for apply", .simplifiedChinese: "批准执行"],
        .manualFollowUp: [.english: "Manual Follow-up", .simplifiedChinese: "人工后续"],
        .manualRecommendationRequired: [.english: "Manual follow-up required", .simplifiedChinese: "需要人工后续"],
        .manualRecommendationRequiredMessage: [.english: "Keep and Review recommendations are planning notes. Open the assets when you want to inspect the details before taking action.", .simplifiedChinese: "保留和复核属于规划备注。需要细看时再打开相关资产检查即可。"],
        .noExecutableApprovedActions: [.english: "No executable approved actions. Archive, Hide, and Merge are the actions the app can apply automatically.", .simplifiedChinese: "没有可执行的已批准操作。应用目前可自动执行归档、隐藏和合并。"],
        .mergedIntoArchiveReason: [.english: "Merged into %@. %@", .simplifiedChinese: "已合并到 %@。%@"],
        .affectedAssets: [.english: "Affected Assets", .simplifiedChinese: "涉及资产"],
        .cleanupReview: [.english: "Cleanup Review", .simplifiedChinese: "整理审查"],
        .cleanupReviewSubtitle: [.english: "Start with a goal, review issue groups with evidence, then apply only reversible actions.", .simplifiedChinese: "先选择目标，再按问题组看证据，最后只执行可回滚的操作。"],
        .cleanupGoal: [.english: "Cleanup Goal", .simplifiedChinese: "整理目标"],
        .startCleanupReview: [.english: "Start Cleanup Review", .simplifiedChinese: "开始整理审查"],
        .cleanupGroups: [.english: "Issue Groups", .simplifiedChinese: "问题组"],
        .executableActions: [.english: "Executable Actions", .simplifiedChinese: "可执行操作"],
        .inventoryEvidence: [.english: "Inventory Evidence", .simplifiedChinese: "索引证据"],
        .noCleanupGroups: [.english: "No issue groups for this goal. Try another goal or refresh the index.", .simplifiedChinese: "这个目标下没有问题组。可以换一个目标，或刷新索引。"],
        .recommendedAction: [.english: "Recommended Action", .simplifiedChinese: "推荐动作"],
        .cleanupEvidence: [.english: "Evidence", .simplifiedChinese: "证据"],
        .openGroup: [.english: "Open Group", .simplifiedChinese: "打开问题组"],
        .applyApprovedCleanup: [.english: "Apply Approved Cleanup", .simplifiedChinese: "执行已批准整理"],
        .cleanupReviewReadyWithCounts: [.english: "Cleanup review ready: %d groups affecting %d assets.", .simplifiedChinese: "整理审查已生成：%d 个问题组，涉及 %d 个资产。"],
        .scanningForCleanupReview: [.english: "Scanning enabled sources before starting cleanup review.", .simplifiedChinese: "正在先扫描启用来源，然后开始整理审查。"],
        .scanCancelledForCleanupReview: [.english: "Cleanup review cancelled with the scan.", .simplifiedChinese: "扫描已取消，整理审查也已取消。"],
        .appliedCleanupActions: [.english: "Applied %d cleanup actions.", .simplifiedChinese: "已执行 %d 个整理操作。"],
        .buildMap: [.english: "Build Map", .simplifiedChinese: "生成地图"],
        .askAIForPlan: [.english: "Ask AI for Plan", .simplifiedChinese: "让 AI 规划"],
        .localPlan: [.english: "Local Plan", .simplifiedChinese: "本地计划"],
        .applyApproved: [.english: "Apply Approved", .simplifiedChinese: "执行已批准"],
        .approved: [.english: "Approved", .simplifiedChinese: "已批准"],
        .recommendations: [.english: "Recommendations", .simplifiedChinese: "建议"],
        .buckets: [.english: "Buckets", .simplifiedChinese: "分组"],
        .audiences: [.english: "Audiences", .simplifiedChinese: "使用对象"],
        .humanReviewRequired: [.english: "Human review required", .simplifiedChinese: "需要人工确认"],
        .manualOnlyNotice: [.english: "Approved Archive, Hide, and Merge actions are reversible. Merge keeps the primary asset and archives the duplicate related assets.", .simplifiedChinese: "已批准的归档、隐藏和合并都是可恢复操作。合并会保留主资产，并归档相关重复资产。"],
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
        .aiPlanErrorPrefix: [.english: "AI plan error: %@", .simplifiedChinese: "AI 计划错误：%@"],
        .openAIKeyRequiredForOrganizer: [.english: "Add an OpenAI API key in Settings to generate an AI plan.", .simplifiedChinese: "请先在设置中添加 OpenAI API key，才能生成 AI 计划。"],
        .appliedOrganizationActions: [.english: "Applied %d actions. %d approved items remain manual follow-up.", .simplifiedChinese: "已执行 %d 个操作。%d 个已批准项目保留为人工后续事项。"],
        .sensitiveFilesNotSentToOpenAI: [.english: "Sensitive files are not sent to OpenAI.", .simplifiedChinese: "敏感文件不会发送给 OpenAI。"],
        .archivedFileStatus: [.english: "Archived %@", .simplifiedChinese: "已归档 %@"],
        .restoredFileStatus: [.english: "Restored %@", .simplifiedChinese: "已恢复 %@"],
        .hiddenFileStatus: [.english: "Hidden %@", .simplifiedChinese: "已隐藏 %@"],
        .unhiddenFileStatus: [.english: "Restored hidden %@", .simplifiedChinese: "已恢复隐藏项 %@"],
        .latestOperation: [.english: "Latest Operation", .simplifiedChinese: "最近操作"],
        .operationHistory: [.english: "Operation History", .simplifiedChinese: "操作历史"],
        .operationResult: [.english: "Operation Result", .simplifiedChinese: "执行结果"],
        .noOperationHistory: [.english: "No management operations yet.", .simplifiedChinese: "暂无管理操作记录。"],
        .undoLatestOperation: [.english: "Undo Latest", .simplifiedChinese: "撤销最近操作"],
        .operationBatchApplied: [.english: "Applied %d actions. %d failed.", .simplifiedChinese: "已执行 %d 个操作，%d 个失败。"],
        .operationBatchUndone: [.english: "Undid %d actions. %d failed.", .simplifiedChinese: "已撤销 %d 个操作，%d 个失败。"],
        .operationUndoNotAvailable: [.english: "No reversible actions in the latest operation.", .simplifiedChinese: "最近操作中没有可撤销的动作。"],
        .affectedFiles: [.english: "Affected Files", .simplifiedChinese: "影响文件"],
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
        .rawSensitiveFileHidden: [.english: "Sensitive file intentionally not displayed.", .simplifiedChinese: "敏感文件已隐藏，原始内容不会显示。"],
        .showRedactedLocalPreview: [.english: "Show Redacted Local Preview", .simplifiedChinese: "显示本地脱敏预览"],
        .redactedLocalPreviewNote: [.english: "Local-only redacted preview. It is not sent to AI or saved in the audit log.", .simplifiedChinese: "仅本地显示脱敏预览，不会发送给 AI，也不会写入审计日志。"],
        .rawLargeFileRequiresExplicitLoad: [.english: "File is %@. Load explicitly to display the full raw content.", .simplifiedChinese: "文件大小为 %@。请点击加载全文后显示完整原始内容。"],
        .rawFileTooLargeForInline: [.english: "File is %@. It is too large to render safely inside the app. Open it in Finder or a dedicated editor.", .simplifiedChinese: "文件大小为 %@，过大，无法在应用内安全渲染。请用 Finder 或专门的编辑器打开。"],
        .rawUnableToReadFile: [.english: "Unable to read full file: %@", .simplifiedChinese: "无法读取完整文件：%@"],
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
