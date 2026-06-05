<h1 align="center">Agent Observatory</h1>

<p align="center">
  A native macOS command center for inspecting, understanding, and managing your local AI-agent files.
</p>

<p align="center">
  <a href="#features">Features</a>
  ·
  <a href="#interface-preview">Interface Preview</a>
  ·
  <a href="#quick-start">Quick Start</a>
  ·
  <a href="docs/LLM_AGENT_INSTALL.md">LLM Agent Install</a>
  ·
  <a href="#privacy-first">Privacy</a>
  ·
  <a href="#architecture">Architecture</a>
</p>

<p align="center">
  English
  ·
  <a href="README.zh-CN.md">简体中文</a>
  ·
  <a href="README.zh-TW.md">繁體中文</a>
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

## Interface Preview

No screenshots are embedded in the README. The preview below is built from
plain Markdown/HTML so it works in private repos, forks, release notes, and LLM
readers without broken image links.

<table>
  <tr>
    <td width="24%" valign="top">
      <strong>Source List</strong><br>
      <sub>Quiet native navigation for large local agent setups.</sub><br><br>
      <kbd>Overview 1,056</kbd><br><br>
      <kbd>Memories 185</kbd><br><br>
      <kbd>Capabilities 734</kbd><br><br>
      <kbd>MCP 4</kbd><br><br>
      <kbd>Prompt Preview 923</kbd>
    </td>
    <td width="46%" valign="top">
      <strong>Context Weight by App</strong><br>
      <sub>Largest prompt files grouped by the app that loads them.</sub><br><br>
      <strong>Claude Code</strong> <kbd>221</kbd> <kbd>19%</kbd><br>
      <code>install-counts-cache</code> <kbd>Plugin</kbd><br>
      <code>interactive-command-patterns</code> <kbd>Command</kbd><br><br>
      <strong>Codex</strong> <kbd>625</kbd> <kbd>67%</kbd><br>
      <code>browser-client</code> <kbd>Script</kbd><br>
      <code>raw_memories.md</code> <kbd>Memory</kbd><br><br>
      <strong>Agents</strong> <kbd>77</kbd> <kbd>13%</kbd><br>
      <code>macos-design-guidelines</code> <kbd>Skill</kbd>
    </td>
    <td width="30%" valign="top">
      <strong>Fixed Inspector</strong><br>
      <sub>Details stay visible while the ranking scrolls.</sub><br><br>
      <kbd>Codex</kbd> <kbd>Script</kbd> <kbd>5.5%</kbd><br><br>
      <code>~/.codex/plugins/.../browser-client.mjs</code><br><br>
      Token: <strong>55.0k</strong><br>
      Global share: <strong>3.7%</strong><br>
      Placement: <strong>Support file</strong><br><br>
      <kbd>Open Asset Detail</kbd>
    </td>
  </tr>
</table>

The app is designed as a native Mac control surface: a quiet source-list
sidebar, dense context ranking in the center, and a fixed inspector that stays
visible while you scroll. Compact badges and Finder-first file actions keep
large Claude Code and Codex setups scannable.

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
  documentation sections. Large capability sets are grouped by package or
  repository and collapsed by default; MCP entries stay in their own section so
  skills and tool servers do not blur together.

- **Memory migration preview**
  See whether a memory exists in Claude Code, Codex, or both before copying it
  to the other agent system. Destination files are checked first, so the UI can
  show whether a copy will create a file, skip an existing target, or need
  manual review.

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
  files into a managed location with restore support. Copy and migration actions
  use preview sheets so the source, destination, and overwrite status are visible
  before anything is written.

- **Bilingual UI**  
  Switch between English and Simplified Chinese from Settings.

- **Native macOS experience**  
  SwiftUI, NavigationSplitView, local Keychain storage, filesystem watching, and
  a proper macOS app bundle icon.

## Quick Start

Helping someone install this with an LLM agent? Use the
[LLM Agent Install And Launch Guide](docs/LLM_AGENT_INSTALL.md) for a
step-by-step, agent-friendly flow.

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
./script/package_release.sh v0.2.2
```

The latest packaged release is
[Agent Observatory v0.2.2](https://github.com/674019130/agent-observatory/releases/tag/v0.2.2).

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
./script/package_release.sh v0.2.2
```

The app bundle is created at:

```text
dist/AgentObservatory.app
```

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md) for the working roadmap. The next
sequence is:

- Keep ad-hoc release packaging and document the macOS security prompt tradeoff.
- Keep regression coverage around context browser selection, lazy tree loading,
  asset filter layout, path preview, Finder opening, copy preview, and OpenAI
  explanation selection flow.
- Build dependency graph visualization for memory, capability, MCP, and project
  instruction relationships.
- Add import/export for management state so hide/archive decisions can be backed
  up or moved between machines.
- Add source presets for more agent runtimes after the Claude Code and Codex
  model stays stable.

## License

MIT
