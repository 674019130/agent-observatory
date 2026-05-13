<p align="center">
  <img src="docs/assets/app-icon.png" width="128" height="128" alt="Agent Observatory app icon">
</p>

<h1 align="center">Agent Observatory</h1>

<p align="center">
  A native macOS command center for inspecting, understanding, and managing your local AI-agent files.
</p>

<p align="center">
  <a href="#features">Features</a>
  ·
  <a href="#quick-start">Quick Start</a>
  ·
  <a href="#privacy-first">Privacy</a>
  ·
  <a href="#architecture">Architecture</a>
</p>

---

Agent Observatory gives you one place to see what Claude Code, Codex, local
agent skills, commands, memories, rules, MCP configs, and project instructions
are doing on your machine.

It is built for people who run more than one AI coding tool and eventually lose
track of which tool has which memory, skill, command, or stale path. The app
scans a focused set of local directories, classifies the files it finds, explains
what they do, highlights drift, and lets you hide or archive files without
losing them.

## Features

- **Focused local scanning**  
  Index Claude, Codex, Agents, plugin, and project sources without crawling your
  whole filesystem. Project-scoped sources resolve from a configurable Project
  Folder, so app launches are not tied to the process working directory.

- **Search with real context**  
  Search across titles, summaries, paths, preview text, dependencies, triggers,
  and status flags.

- **Context browser for Claude Code and Codex**  
  See memories, capabilities, and assembly steps side by side so it is clear
  which files become prompt material, registries, support files, or history.
  Small official-doc tips link back to the relevant OpenAI and Claude Code
  documentation sections.

- **Skill trigger radar**  
  Detect user, project, bundled, and plugin skills that compete for the same
  intent before the wrong capability answers first. Copied handling prompts
  include a required Markdown result format for conclusions, file decisions,
  verification, remaining human choices, and rollback notes.

- **Dashboard for risk and drift**  
  See stale paths, duplicate identities, unreadable files, large files, missing
  descriptions, dependency hotspots, and Claude/Codex drift in one view.

- **AI explanations with redaction**  
  Use your own OpenAI API key to generate short explanations. Sensitive files are
  detected locally and excluded from LLM enrichment.

- **Raw content inspection**  
  Open the full raw file content when needed, with large-file preflight and
  secret redaction. Truncated paths can be hovered to preview the full path and
  clicked to reveal the file in Finder.

- **Soft management tools**  
  Hide noisy files from the main index, restore hidden files later, or archive
  files into a managed location with restore support.

- **Bilingual UI**  
  Switch between English and Simplified Chinese from Settings.

- **Native macOS experience**  
  SwiftUI, NavigationSplitView, local Keychain storage, filesystem watching, and
  a proper macOS app bundle icon.

## Quick Start

Requirements:

- macOS 14 or newer
- Xcode command line tools
- Swift 5.9+

Clone and run:

```bash
git clone https://github.com/674019130/agent-observatory.git
cd agent-observatory
./script/build_and_run.sh
```

Run tests:

```bash
swift test
```

Build and verify that the app launches:

```bash
./script/build_and_run.sh --verify
```

After launch, open Settings -> Sources and set the Project Folder for the repo or
workspace you want to inspect. The app keeps that folder in local preferences and
uses it for project-level `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `.codex`, and
`.claude` sources.

Package a local release zip:

```bash
./script/package_release.sh v0.1.0
```

## What It Finds

Agent Observatory looks for local agent assets such as:

- skills and `SKILL.md` files
- slash commands
- memory and instruction files
- rule files
- MCP configuration
- plugin metadata
- scripts related to agent workflows
- workspace memory folders containing Markdown or plain-text context
- sensitive config files that should not be sent to an LLM

The scanner uses explicit source definitions, depth limits, and a shared source
rule resolver that is also used by filesystem change detection. You can enable,
disable, add workspace memory folders, set the project folder, or reset sources
from Settings.

## Privacy First

Agent Observatory is local-first.

- Files are scanned locally.
- API keys are stored in the macOS Keychain.
- OpenAI enrichment uses your own API key.
- Only redacted previews are sent for AI explanations.
- Sensitive paths such as auth files, token files, and key material are blocked
  from preview and LLM enrichment.
- Hidden and archived state is stored locally in `UserDefaults`.

## Architecture

The project is a SwiftPM package with two targets:

```text
AgentObservatory
├─ AgentObservatory        # SwiftUI macOS app
└─ AgentObservatoryCore    # scanning, classification, redaction, diffing, archive logic
```

Core services include:

- `AssetSourceRules` for the shared scanner and watcher file-matching rules
- `FileSystemAssetScanner` for focused streaming scans with progress updates
- `AssetClassifier` for extracting names, summaries, triggers, and health flags
- `ContextLoadAnalyzer` and `ContextCatalogAnalyzer` for explaining how local
  files map into Claude Code and Codex memory, capability, and assembly surfaces
- `SkillTriggerConflictAnalyzer` for finding overlapping skill trigger contracts
- `DashboardAnalyzer` for risk ranking and dependency hotspots
- `AssetImpactAnalyzer` for incoming/outgoing reference analysis
- `RawContentReader` for safe full-content inspection
- `AssetArchiveService` for soft-delete style archive and restore
- `OpenAIEnricher` for optional file explanations

## Development

Useful commands:

```bash
swift build
swift test
./script/build_and_run.sh
./script/build_and_run.sh --verify
./script/package_release.sh v0.1.0
```

The app bundle is created at:

```text
dist/AgentObservatory.app
```

## Roadmap

- Dependency graph visualization
- Source presets for additional agent runtimes
- Import/export for management state
- Developer ID signing and notarization

## License

MIT
