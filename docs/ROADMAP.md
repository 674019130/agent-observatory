# Roadmap

Last updated: 2026-05-19

Current release: `v0.2.1`

Agent Observatory is now useful as a local command center for understanding
Claude Code and Codex context files. The main branch now continues the `v0.2.x`
line with UI stability, capability grouping, memory migration previews, and
clearer copy flows before the larger relationship-map milestone.

## Product Direction

Keep the product local-first and inspection-first:

- Explain local agent context before changing it.
- Keep management actions reversible or auditable.
- Prefer official documentation links for runtime-specific guidance.
- Treat privacy as a core feature: sensitive files stay local and are blocked
  from LLM enrichment.
- Make the right pane a reliable detail surface for every middle-column
  selection.
- Keep user-authored files easier to find than bundled or official assets.
- When an action copies or migrates context, show the source, destination, and
  existing-target status before writing anything.

## Current v0.2.x Iteration

This is the active polish track after `v0.2.1`:

- Capability browsing is grouped by package or repository and collapsed by
  default, so large skill installs do not render hundreds of rows at once.
- MCP entries are split from general capabilities, because skills and tool
  servers answer different user questions.
- Memory rows show Claude Code vs Codex presence before migration, and migration
  plans check whether the destination file already exists.
- Copy-to-agent actions use visible preview sheets instead of silent clipboard or
  filesystem actions.
- The Assets page uses an adaptive filter header; compact windows collapse owner
  and health filters into menus instead of overlapping labels.
- Tree-style context browsing should stay lazy-loaded for large indexes while
  preserving the existing hierarchy.

## v0.2.x: Practical Release Maintenance

Goal: keep the current ad-hoc release flow honest and repeatable without making
Developer ID signing a blocker.

- Keep ad-hoc release packaging as the supported sharing path for now.
- Document that downloaded builds may require right-click Open or approval in
  macOS Privacy & Security.
- Maintain the manual smoke checklist for Settings -> Sources, context browser
  selection, path preview popovers, Finder opening, and OpenAI explanation.
- Keep focused regression coverage around the context selection and inspector
  state paths that caused the post-`v0.2.0` selection bug.
- Keep copy and migration flows conservative when the target file already exists.
- Keep list rendering incremental for large memory, capability, MCP, and asset
  indexes.
- Keep Developer ID signing, hardened runtime, notarization, and stapling as an
  optional future path, not the next milestone.

Done when a release can be built, checked, uploaded, and explained without
surprising the user about macOS security prompts.

## v0.3.0: Relationship Map

Goal: show how files influence each other, not only what each file is.

- Add dependency graph visualization for memories, capabilities, MCP configs,
  project instructions, skills, and commands.
- Show incoming and outgoing references with risk indicators.
- Add a drift view for Claude Code vs Codex files that represent the same
  intent.
- Keep the graph inspectable and sparse by default; avoid turning it into a
  decorative canvas.

Done when a user can answer "what will this file affect?" without reading raw
content first.

## v0.4.0: Management Portability

Goal: make user decisions durable across machines and reinstalls.

- Add import/export for hidden, archived, and management history state.
- Include a dry-run preview before importing state.
- Add backup metadata: export time, app version, project root, and source list.
- Keep restore behavior conservative when target paths already exist.

Done when a user can move their observatory decisions to another Mac without
manually recreating hide/archive state.

## v0.5.0: Source Presets

Goal: expand coverage only after the Claude Code and Codex model stays stable.

- Add presets for additional agent runtimes and coding assistants.
- Keep each preset backed by explicit source rules and tests.
- Separate official, curated, project-local, and user-authored files in the UI.
- Avoid broad home-directory scanning unless the user explicitly opts in.

Done when adding another runtime does not weaken the current privacy and
performance boundaries.

## Later

- Developer ID signing and notarization if an Apple Developer Program account
  becomes worth the cost later.
- Better release automation once the final distribution path is clear.
- Optional update checking.
- More official-doc tips as upstream Codex and Claude Code documentation changes.
- Richer AI audit filtering and export.
