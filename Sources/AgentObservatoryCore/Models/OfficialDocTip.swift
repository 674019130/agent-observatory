import Foundation

public struct OfficialDocTip: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let sourceTitle: String
    public let sourceURL: String
    public let sourceLocation: String

    public init(
        id: String,
        title: String,
        body: String,
        sourceTitle: String,
        sourceURL: String,
        sourceLocation: String
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.sourceLocation = sourceLocation
    }
}

public enum OfficialDocTipPlacement: Sendable {
    case contextOverview
    case memories
    case capabilities
    case mcpTools
    case assembly
    case triggerRadar
}

public enum OfficialDocTips {
    public static func tips(for placement: OfficialDocTipPlacement, language: AppLanguage) -> [OfficialDocTip] {
        switch placement {
        case .contextOverview:
            [codexAgents(language: language), claudeMemory(language: language)]
        case .memories:
            [codexMemories(language: language), claudeMemory(language: language)]
        case .capabilities:
            [codexSkills(language: language), claudeSkills(language: language)]
        case .mcpTools:
            [codexMCP(language: language), claudeMCP(language: language)]
        case .assembly:
            [codexAgents(language: language), claudeMemory(language: language), codexMemories(language: language)]
        case .triggerRadar:
            [codexSkills(language: language), claudeSkills(language: language)]
        }
    }

    public static func tips(
        for asset: AgentAsset,
        route: ContextLoadRoute,
        language: AppLanguage
    ) -> [OfficialDocTip] {
        var tips: [OfficialDocTip] = []

        if asset.kind == .instruction || route.destination == .projectContextBlock {
            if isCodexInstruction(asset: asset, route: route) {
                tips.append(codexAgents(language: language))
            }
            if isClaudeInstruction(asset: asset, route: route) {
                tips.append(claudeMemory(language: language))
            }
        }

        if asset.kind == .memory || route.destination == .memoryBlock {
            if asset.owner == .codex || route.surfaces.contains(.codex) {
                tips.append(codexMemories(language: language))
            }
            if asset.owner == .claude || route.surfaces.contains(.claude) {
                tips.append(claudeMemory(language: language))
            }
        }

        if asset.kind == .skill || route.destination == .skillRegistry {
            if asset.owner == .claude || route.surfaces.contains(.claude) {
                tips.append(claudeSkills(language: language))
            }
            if asset.owner == .codex || asset.owner == .agents || route.surfaces.contains(.codex) {
                tips.append(codexSkills(language: language))
            }
        }

        if asset.kind == .mcp || route.destination == .toolRegistry || route.trigger == .mcpConfiguration {
            if asset.owner == .claude || route.surfaces.contains(.claude) {
                tips.append(claudeMCP(language: language))
            }
            if asset.owner == .codex || route.surfaces.contains(.codex) {
                tips.append(codexMCP(language: language))
            }
        }

        return unique(tips).prefix(2).map { $0 }
    }

    private static func isCodexInstruction(asset: AgentAsset, route: ContextLoadRoute) -> Bool {
        let path = asset.path.lowercased()
        return asset.owner == .codex
            || route.surfaces.contains(.codex)
            || path.contains("agents.md")
            || path.contains("agents.override.md")
    }

    private static func isClaudeInstruction(asset: AgentAsset, route: ContextLoadRoute) -> Bool {
        let path = asset.path.lowercased()
        return asset.owner == .claude
            || route.surfaces.contains(.claude)
            || path.contains("claude.md")
            || path.contains(".claude/rules")
    }

    private static func unique(_ tips: [OfficialDocTip]) -> [OfficialDocTip] {
        var seen: Set<String> = []
        return tips.filter { seen.insert($0.id).inserted }
    }

    private static func codexAgents(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "codex-agents-md",
            title: text(
                english: "AGENTS.md is Codex’s project instruction entrypoint.",
                chinese: "AGENTS.md 是 Codex 的项目说明入口。",
                language: language
            ),
            body: text(
                english: "Codex reads AGENTS.md before work starts and builds an instruction chain from global, project, and nested files.",
                chinese: "Codex 开始工作前会读取 AGENTS.md，并把全局、项目和更深目录里的说明组成一条指令链。",
                language: language
            ),
            sourceTitle: "OpenAI Codex docs",
            sourceURL: "https://developers.openai.com/codex/guides/agents-md",
            sourceLocation: "Custom instructions with AGENTS.md > How Codex discovers guidance"
        )
    }

    private static func codexMemories(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "codex-memories",
            title: text(
                english: "Codex memories are local recall, not the source of policy.",
                chinese: "Codex Memories 是本地回忆层，不是规则的唯一来源。",
                language: language
            ),
            body: text(
                english: "Use memories for stable preferences and recurring workflows; keep required team guidance in AGENTS.md or checked-in docs.",
                chinese: "Memories 适合保存稳定偏好和常见流程；必须执行的团队规则仍应放在 AGENTS.md 或仓库文档里。",
                language: language
            ),
            sourceTitle: "OpenAI Codex docs",
            sourceURL: "https://developers.openai.com/codex/memories",
            sourceLocation: "Memories > How Codex carries useful context forward across threads"
        )
    }

    private static func codexSkills(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "codex-skills",
            title: text(
                english: "Codex skills are discoverable capabilities.",
                chinese: "Codex Skills 是可被发现和调用的能力。",
                language: language
            ),
            body: text(
                english: "Codex scans project, user, admin, and bundled skill folders; metadata can control whether a skill is invoked implicitly.",
                chinese: "Codex 会扫描项目、用户、管理员和内置 skill 目录；metadata 可以控制 skill 是否允许被隐式触发。",
                language: language
            ),
            sourceTitle: "OpenAI Codex docs",
            sourceURL: "https://developers.openai.com/codex/skills",
            sourceLocation: "Agent Skills > Skill locations / Optional metadata"
        )
    }

    private static func codexMCP(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "codex-mcp",
            title: text(
                english: "MCP configuration wires tools and context into Codex.",
                chinese: "MCP 配置是在给 Codex 接入工具和外部上下文。",
                language: language
            ),
            body: text(
                english: "Codex stores MCP server settings in config.toml, globally or in trusted project-scoped .codex/config.toml files.",
                chinese: "Codex 的 MCP server 通常写在 config.toml，也可以放在受信任项目里的 .codex/config.toml。",
                language: language
            ),
            sourceTitle: "OpenAI Codex docs",
            sourceURL: "https://developers.openai.com/codex/mcp",
            sourceLocation: "Model Context Protocol > Connect Codex to an MCP server"
        )
    }

    private static func claudeMemory(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "claude-memory",
            title: text(
                english: "CLAUDE.md is persistent instruction for Claude Code.",
                chinese: "CLAUDE.md 是 Claude Code 的持久项目说明。",
                language: language
            ),
            body: text(
                english: "Claude reads CLAUDE.md at session start; use it for build commands, conventions, project layout, and always-apply rules.",
                chinese: "Claude 会在会话开始时读取 CLAUDE.md；它适合放构建命令、约定、项目结构和总是适用的规则。",
                language: language
            ),
            sourceTitle: "Claude Code docs",
            sourceURL: "https://code.claude.com/docs/en/memory",
            sourceLocation: "CLAUDE.md files > Choose where to put CLAUDE.md files"
        )
    }

    private static func claudeSkills(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "claude-skills",
            title: text(
                english: "Claude skills are task-specific instructions loaded when relevant.",
                chinese: "Claude Skills 是按任务触发的专项说明。",
                language: language
            ),
            body: text(
                english: "Claude can invoke enabled skills when relevant; project skills can be shared through .claude/skills and plugins can bundle skills.",
                chinese: "Claude 会在相关时调用已启用的 skills；项目 skills 可放在 .claude/skills 共享，插件也可以打包 skills。",
                language: language
            ),
            sourceTitle: "Claude Code docs",
            sourceURL: "https://code.claude.com/docs/en/skills",
            sourceLocation: "Extend Claude with skills > Restrict Claude’s skill access / Share skills"
        )
    }

    private static func claudeMCP(language: AppLanguage) -> OfficialDocTip {
        OfficialDocTip(
            id: "claude-mcp",
            title: text(
                english: "MCP servers let Claude Code use external tools directly.",
                chinese: "MCP servers 让 Claude Code 直接使用外部工具。",
                language: language
            ),
            body: text(
                english: "Claude Code uses MCP to connect to tools, databases, and APIs, reducing the need to paste data into chat.",
                chinese: "Claude Code 用 MCP 连接工具、数据库和 API，减少把外部系统数据手动复制进聊天的需要。",
                language: language
            ),
            sourceTitle: "Claude Code docs",
            sourceURL: "https://code.claude.com/docs/en/mcp",
            sourceLocation: "Connect Claude Code to tools via MCP > What you can do with MCP"
        )
    }

    private static func text(english: String, chinese: String, language: AppLanguage) -> String {
        switch language {
        case .english:
            english
        case .simplifiedChinese:
            chinese
        }
    }
}
