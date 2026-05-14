# Roadmap

Last updated: 2026-05-14

Current release: `v0.2.1`

Agent Observatory is now useful as a local command center for understanding
Claude Code and Codex context files. The next route is to keep releases practical
without an Apple Developer Program account, make key flows harder to regress, and
show why one agent file affects another.

## Product Direction

Keep the product local-first and inspection-first:

- Explain local agent context before changing it.
- Keep management actions reversible or auditable.
- Prefer official documentation links for runtime-specific guidance.
- Treat privacy as a core feature: sensitive files stay local and are blocked
  from LLM enrichment.
- Make the right pane a reliable detail surface for every middle-column
  selection.

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
