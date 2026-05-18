# LLM Agent Install And Launch Guide

This file is written for an LLM coding agent helping a macOS user install,
launch, or verify Agent Observatory.

## Goal

Install and open Agent Observatory on macOS, then guide the user to choose the
local project or workspace they want the app to inspect.

## System Requirements

- macOS 14 or newer.
- For source builds: Xcode command line tools and Swift 5.9 or newer.
- For release downloads: no Apple Developer Program account is required.

## Preferred Path: Download The Release

Use this path when the user wants the app, not the source tree.

1. Open the latest release:

   <https://github.com/674019130/agent-observatory/releases/latest>

2. Download the macOS zip asset:

   ```text
   AgentObservatory-v0.2.2-macOS.zip
   ```

3. Unzip it. The archive contains:

   ```text
   AgentObservatory.app
   ```

4. Move `AgentObservatory.app` to `/Applications` if the user wants a normal app
   install.

5. Launch the app:

   ```bash
   open /Applications/AgentObservatory.app
   ```

   If the app is still in Downloads or another folder, launch that exact path:

   ```bash
   open "/path/to/AgentObservatory.app"
   ```

6. If macOS blocks the app because it is ad-hoc signed, use one of these user
   approval paths:

   - Finder: right-click `AgentObservatory.app`, choose Open, then confirm.
   - System Settings: Privacy & Security, allow the blocked app.

   Do not tell the user the app is notarized. Current public builds are ad-hoc
   signed and may need this first-launch approval.

## Source Build Path

Use this path when the user wants to run from source or verify the project
locally.

```bash
git clone https://github.com/674019130/agent-observatory.git
cd agent-observatory
./script/build_and_run.sh
```

To run tests:

```bash
swift test
```

To build and verify that the app process launches:

```bash
./script/build_and_run.sh --verify
```

To create a local release zip:

```bash
./script/package_release.sh v0.2.2
```

## First Launch Setup

After the app opens:

1. Open Settings.
2. Go to Sources.
3. Set Project Folder to the repository or workspace the user wants to inspect.
4. Confirm Claude Code, Codex, Agents, plugin, MCP, and workspace memory sources
   look correct.
5. Click Refresh or wait for the scan to complete.

Expected result: the sidebar shows counts for Overview, Memories, Capabilities,
MCP, Assembly, and All files. Selecting a row should update the right-side
inspector.

## Troubleshooting

### `xcode-select` Or Swift Is Missing

Ask the user to install Xcode command line tools:

```bash
xcode-select --install
```

Then re-run:

```bash
swift --version
```

### macOS Says The App Cannot Be Opened

This is expected for ad-hoc signed release builds on some machines. Prefer the
Finder right-click Open path or Privacy & Security approval.

Only if the user explicitly accepts terminal-based quarantine removal, use:

```bash
xattr -dr com.apple.quarantine "/path/to/AgentObservatory.app"
open "/path/to/AgentObservatory.app"
```

### The App Opens But Shows No Project Files

Check Settings -> Sources:

- Project Folder should point at the intended repo or workspace.
- The relevant sources should be enabled.
- Run Refresh after changing sources.

### The App Launches From Source But The Release Build Fails

Run:

```bash
swift test
./script/build_and_run.sh --verify
./script/package_release.sh v0.2.2
codesign --verify --deep --strict --verbose=2 dist/release/AgentObservatory.app
```

If `codesign` passes but macOS still warns on first launch, that is a
distribution trust prompt, not necessarily a broken bundle.

## Agent Safety Rules

- Do not scan the user's whole home directory unless they explicitly ask.
- Do not upload local agent files, memory files, secrets, or screenshots with
  private paths.
- Do not claim the release is Developer ID signed or notarized.
- Prefer reversible actions in the app: inspect first, then hide, archive, copy,
  or migrate only after previewing the target.
