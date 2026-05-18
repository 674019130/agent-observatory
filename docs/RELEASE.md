# Release Guide

Agent Observatory can be shipped as a zipped macOS app bundle. The current
release script produces an ad-hoc signed build for quick sharing and local
testing. Developer ID signing and notarization are optional future work if the
project later needs polished public macOS distribution.

## Current Release

- Version: `v0.2.1`
- GitHub Release: <https://github.com/674019130/agent-observatory/releases/tag/v0.2.1>
- Artifact: `dist/AgentObservatory-v0.2.1-macOS.zip`
- SHA-256: `4bb1ebb56f3b41a1c8701c460c171b70ba19c5209f58ff154a462e0cf0dc2551`
- Signing: ad-hoc signed, not Developer ID signed or notarized.
- Install expectation: downloaded builds may require right-click Open or
  approval in macOS Privacy & Security.

## Build a Release Zip

```bash
./script/package_release.sh v0.2.1
```

The script runs `swift test`, builds with `swift build -c release`, assembles
`dist/release/AgentObservatory.app`, ad-hoc signs it, then writes:

```text
dist/AgentObservatory-v0.2.1-macOS.zip
dist/AgentObservatory-v0.2.1-macOS.zip.sha256
```

## Local Verification

Before pushing a release candidate, verify both the test suite and the runnable
macOS bundle:

```bash
swift test
./script/build_and_run.sh --verify
```

The verify command stops any existing `AgentObservatory` process, rebuilds the
SwiftPM app bundle under `dist/AgentObservatory.app`, launches it, and checks
that the process is running.

Use [SMOKE_CHECKLIST.md](SMOKE_CHECKLIST.md) for the manual release checks that
cover Settings -> Sources, context browser selection, path previews, Finder
opening, asset filter layout, copy and migration previews, OpenAI explanation,
and release artifact metadata.

If the release changes a primary screen, refresh the sanitized README screenshots
under `docs/assets/` before publishing. Do not use a live screenshot that exposes
real local paths, private repo names, browser content, or menu bar state.

For changes that affect source discovery, confirm Settings -> Sources still
shows the expected Project Folder and source list. The Project Folder controls
project-scoped `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `.codex`, and `.claude`
sources; workspace memory folders should mark Markdown and plain-text changes as
relevant filesystem events.

## GitHub Release Checklist

1. Confirm the tree is clean and synchronized.

```bash
git status --short --branch
git fetch --tags origin
```

2. Run the release script with the target version.

```bash
./script/package_release.sh v0.2.1
```

3. Verify the bundle version, checksum, and code signature.

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  dist/release/AgentObservatory.app/Contents/Info.plist
cat dist/AgentObservatory-v0.2.1-macOS.zip.sha256
codesign --verify --deep --strict --verbose=2 dist/release/AgentObservatory.app
```

4. Create and push an annotated version tag.

```bash
git tag -a v0.2.1 -m "Agent Observatory v0.2.1"
git push origin v0.2.1
```

5. Draft a GitHub Release with the zip and `.sha256` file attached.

6. Include the checksum and verification commands in the release notes.

7. State the current signing model in the release notes. If the build is still
   ad-hoc signed, mention that macOS may require right-click Open or Privacy &
   Security approval after download.

If `gh release create` fails with a token-scope error, create the release in the
GitHub web UI or retry with a token that can write repository releases.

## Optional Developer ID and Notarization

Ad-hoc signing is enough for local verification and small-scope sharing. A
polished public download would require:

- sign the app with a Developer ID Application certificate
- enable hardened runtime when moving to an Xcode project or a richer bundle
- submit the zip or app for notarization with `notarytool`
- staple the notarization ticket before uploading

This path requires an Apple Developer Program account. Until that is worth doing,
users may need to right-click Open or allow the app from macOS Privacy & Security
after downloading.
