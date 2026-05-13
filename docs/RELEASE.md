# Release Guide

Agent Observatory can be shipped as a zipped macOS app bundle. The current
release script produces an ad-hoc signed build for quick sharing and local
testing. Public distribution should add Developer ID signing and notarization.

## Build a Release Zip

```bash
./script/package_release.sh v0.1.0
```

The script runs `swift test`, builds with `swift build -c release`, assembles
`dist/release/AgentObservatory.app`, ad-hoc signs it, then writes:

```text
dist/AgentObservatory-v0.1.0-macOS.zip
dist/AgentObservatory-v0.1.0-macOS.zip.sha256
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

For changes that affect source discovery, confirm Settings -> Sources still
shows the expected Project Folder and source list. The Project Folder controls
project-scoped `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `.codex`, and `.claude`
sources; workspace memory folders should mark Markdown and plain-text changes as
relevant filesystem events.

## GitHub Release Checklist

1. Create and push a version tag.

```bash
git tag v0.1.0
git push origin v0.1.0
```

2. Run the release script.

```bash
./script/package_release.sh v0.1.0
```

3. Draft a GitHub Release with the zip and `.sha256` file attached.

4. Include the checksum in the release notes.

5. For public users, replace ad-hoc signing with Developer ID signing and
   notarization before announcing the build broadly.

## Developer ID and Notarization

Ad-hoc signing is enough for local verification, but not enough for a polished
public download. The production path should:

- sign the app with a Developer ID Application certificate
- enable hardened runtime when moving to an Xcode project or a richer bundle
- submit the zip or app for notarization with `notarytool`
- staple the notarization ticket before uploading

Until that is wired in, users may need to right-click Open or allow the app from
macOS Privacy & Security after downloading.
