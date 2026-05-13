# Smoke Checklist

Use this checklist before publishing an ad-hoc release, after changing source
discovery, or after touching the three-column selection flow.

## Preflight

- [ ] `git status --short --branch` shows a clean branch.
- [ ] `swift test` passes.
- [ ] `./script/build_and_run.sh --verify` launches the app process.
- [ ] If packaging a release, `./script/package_release.sh <version>` completes
      and writes both the zip and `.sha256` files.

## Settings -> Sources

- [ ] Open Settings -> Sources.
- [ ] Confirm Project Folder points to the workspace or repo being inspected.
- [ ] Confirm global Claude, Codex, Agents, plugin, and workspace memory sources
      are visible as expected.
- [ ] Toggle one non-critical source off and back on; the enabled count should
      update without losing the source row.
- [ ] Run Refresh and confirm scan progress completes.

## Context Browser Selection

- [ ] Open Context Overview and select a group; the right pane should show the
      group inspector.
- [ ] Open Memories and click at least two different memory rows; the right pane
      title and path should change each time.
- [ ] Search for a memory term, click a filtered memory row, then clear search;
      the right pane should keep showing the selected row until another row is
      selected.
- [ ] Open Capabilities and click a skill or plugin row; the right pane should
      show that asset, not the first asset-table row.
- [ ] Open Assembly and click a pipeline item; the right pane should switch to
      the selected item.

## Path Preview And Finder

- [ ] Find a row or inspector header with a truncated path.
- [ ] Hover the path; a small popover should show the full path.
- [ ] Click the path; Finder should reveal the file.
- [ ] Use the explicit Finder button in the inspector header; Finder should reveal
      the same file.

## OpenAI Explanation

- [ ] Select a non-sensitive asset and click Explain with OpenAI.
- [ ] While or after the explanation runs, click another memory row; the right
      pane should switch to the newly selected memory.
- [ ] Select a sensitive or blocked asset; Explain with OpenAI should be disabled
      or should report a local-only safety block.
- [ ] Open Settings diagnostics and confirm the AI audit list records the
      explanation attempt without storing raw sensitive payload text.

## Release Artifact

- [ ] Check bundle version:
      `/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/release/AgentObservatory.app/Contents/Info.plist`
- [ ] Verify code signature:
      `codesign --verify --deep --strict --verbose=2 dist/release/AgentObservatory.app`
- [ ] Check SHA-256:
      `cat dist/AgentObservatory-<version>-macOS.zip.sha256`
- [ ] Release notes mention that current builds are ad-hoc signed and may require
      right-click Open or approval in macOS Privacy & Security.
