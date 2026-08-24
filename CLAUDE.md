# CLAUDE.md

This file provides guidance to Claude Code when working with code in this
repository.

## What this is

Palilogy: Create, view, edit, and delete scheduled jobs on your Mac from a friendly native app.

## Standards

This repo follows the Inkling Labs standards
(github.com/inklinglabs/inkling-labs-dev-standards, STANDARDS.md). The short version:

- Work on `dev` or a feature branch. PRs into `dev` are fine.
- Never push to `main`, merge into `main`, or push tags. Matt does those.
- Releases: prepare the version bump, changelog, and dev-to-main PR, then
  print the tag commands for Matt. The `v*` tag triggers the release
  workflow.
- Secrets use the canonical names from STANDARDS.md. Never print or store
  secret values.
- No em dashes in any prose or docs.

## Styling

UI design language and Mac app patterns live in
[docs/mac-app-styling.md](docs/mac-app-styling.md), based on Captain's Log
(the reference implementation). Follow it for colors, typography, window
layout, settings, and menu bar behavior. Bundle ID: `com.inklinglabs.palilogy`.

## Commands

- `xcodegen generate` regenerates `Palilogy.xcodeproj` from `project.yml`
  (the `.xcodeproj` is gitignored; rerun after changing `project.yml` or
  adding files).
- Build: `xcodebuild -project Palilogy.xcodeproj -scheme Palilogy -configuration Debug build`
- Test: `xcodebuild -project Palilogy.xcodeproj -scheme Palilogy test`

## Architecture

- SwiftUI, Swift 6 strict concurrency, macOS 14.0 minimum, no sandbox
  (the app shells out to launchctl and crontab).
- App source in `Palilogy/`, tests in `PalilogyTests/` (Swift Testing).
- The v1 design lives in [docs/specs/palilogy-v1.md](docs/specs/palilogy-v1.md).
