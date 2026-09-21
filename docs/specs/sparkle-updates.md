# Spec: Sparkle Updates

**Repo:** palilogy (`inklinglabs/palilogy`, public)
**Created:** 2026-09-21

## 1. Problem

Palilogy 1.0.0 has no way to learn that a newer version exists. Anyone who
installed it stays on that build until they happen to revisit the repo and
download a DMG by hand. The README also has no permanent download link; the
only DMG URL contains a version number.

## 2. Goals

1. An installed copy of version N is offered version N+1 by Check for
   Updates, and installs it, with no manual download.
2. Every release is self-contained on GitHub Releases: nothing is published
   anywhere else, and the feed URL never changes.
3. `https://github.com/inklinglabs/palilogy/releases/latest/download/Palilogy.dmg`
   always downloads the newest release.
4. The release job fails loudly, with the notarization log, when Apple
   rejects a build, instead of failing later at the staple step.
5. No secret is reachable from a fork PR or committed to the repo.

## 3. Non-Goals

- **Licensing, trials, payments.** Palilogy is free. Nothing from Handybar's
  Lemon Squeezy, keychain, or license code comes across.
- **Publishing to the website.** GitHub Releases is the only host. The
  permanent DMG link exists so the website can point at it later.
- **Updating 1.0.0 installs automatically.** 1.0.0 ships without Sparkle;
  those users download 1.1.0 by hand once.
- **Delta updates, beta channels, release notes UI.** Full-DMG updates on one
  channel are enough at this size (the 1.0.0 DMG is 0.8 MB).
- **A new Sparkle key pair.** One key pair covers all Inkling Labs apps.

## 4. Proposed Approach

Port from Handybar (`~/Development/inkling-labs/projects/handybar`) instead
of rebuilding from memory. Differences from Handybar are called out.

**App.** Sparkle 2.9.6 via Swift Package Manager, declared in `project.yml`
(deviation: Handybar commits its Xcode project, Palilogy generates it).
Port `UpdaterManager.swift`, which starts the updater only when
`SUPublicEDKey` is non-empty. Port `AboutWindowController.swift` with its
Check for Updates button; drop the support email and link to
`https://github.com/inklinglabs/palilogy` instead. Palilogy uses the SwiftUI
app lifecycle, so both the About window and a Check for Updates menu item
hook in through `.commands` in `Palilogy/PalilogyApp.swift`. Swift 6 strict
concurrency may require main-actor annotations on the ported files. Port the
`HANDYBAR_SNAPSHOT_DIR` pattern from `DebugSnapshots.swift` as
`PALILOGY_SNAPSHOT_DIR` (Debug builds only) so the About window can be
rendered to PNG and reviewed. Light appearance only, like Handybar's:
offscreen caching does not render a dark window background. The updater
also stays off inside the unit-test host so tests never touch the network.

**Info.plist.** `SUFeedURL` =
`https://github.com/inklinglabs/palilogy/releases/latest/download/appcast.xml`,
`SUPublicEDKey` = the same value as Handybar's Info.plist,
`SUEnableAutomaticChecks` = true.

**Release workflow.** Port the Sparkle parts of Handybar's `release.yml`
into `.github/workflows/release.yml`. Three things come across exactly:

1. `CFBundleVersion` is set from the tag. Sparkle compares it, not the
   marketing version. Today the plist has 1 against 1.0.0.
2. Sparkle's nested helpers (Installer.xpc, Downloader.xpc, Autoupdate,
   Updater.app) are re-signed inside out with Developer ID, `--timestamp`
   and `--options=runtime`, then the framework, then the app, each verified
   before packaging. Without this Apple returns status Invalid.
3. The notarize step reads the status itself and prints `notarytool log`
   when it is not Accepted.

Then, in the same job, `generate_appcast` runs with `--download-url-prefix
https://github.com/inklinglabs/palilogy/releases/download/v<version>/` and
three assets are uploaded (the job fails at its first step if
`SPARKLE_PRIVATE_KEY` is missing, rather than shipping without an appcast): `Palilogy-<version>.dmg`, `appcast.xml`, and
`Palilogy.dmg` (a byte copy with no version in the name). This replaces
Handybar's publish-to-website step. The existing XcodeGen step stays.

**Key handling.** `scripts/set_sparkle_secret.py`, adapted: it reads the
private key from the 1Password item "Handybar Sparkle" and sets only this
repo's `SPARKLE_PRIVATE_KEY` secret. It does not write the public key and
never prints the private key. `generate_keys` is never run. Matt runs it.

**Docs.** `docs/RELEASING.md` describes the flow. README gains a Download
button on the permanent link, "updates itself through Sparkle", the minimum
macOS version, and a note that a local build without Matt's Developer ID
will not update into a signed release.

**Trade-offs.**
- *GitHub's `latest/download` redirect as the feed.* Zero hosting and a
  stable URL, at the cost of two rules that must never be broken: a real
  release is never a draft or prerelease (latest would skip it), and a
  published DMG is never deleted or replaced (the signature covers its exact
  bytes).
- *Each appcast lists only its own release.* Simpler than accumulating
  history; Sparkle only needs the newest entry.

## 5. Alternatives Considered

- **Host the appcast on inkling-labs.com like Handybar.** Rejected:
  Handybar does that only because its repo is private. Palilogy is public,
  so a second publish step would add a way for releases to half-ship.
- **Appcast committed to the repo and served from raw.githubusercontent or
  Pages.** Rejected: needs a push to a branch from CI (or from Matt) on
  every release, which collides with the never-push-main rule, and the
  DMG would still live on Releases.
- **No updater, README link only.** Rejected: that is the current state and
  it is the problem.

## 6. Acceptance Criteria

- GIVEN tag v1.1.0 is pushed WHEN the workflow finishes THEN the release
  holds exactly `Palilogy-1.1.0.dmg`, `Palilogy.dmg` and `appcast.xml`, and
  is neither draft nor prerelease.
- GIVEN that release THEN the appcast enclosure carries `sparkle:edSignature`
  and a URL starting
  `https://github.com/inklinglabs/palilogy/releases/download/v1.1.0/`.
- WHEN `curl -sIL` follows the feed URL THEN the final status is 200 and
  the body reports version 1.1.0.
- WHEN `spctl -a -vv` runs on the installed app THEN it reports
  "Notarized Developer ID".
- GIVEN 1.1.0 is installed and 1.1.1 is released WHEN Matt chooses Check
  for Updates THEN 1.1.1 is offered and installs. Matt sees this happen.
- GIVEN a build whose `SUPublicEDKey` is empty WHEN it launches THEN the
  updater does not start and Check for Updates is disabled.
- WHEN Apple returns a notarization status other than Accepted THE WORKFLOW
  SHALL print the `notarytool log` output and fail at that step.
- WHEN the tag does not match `CFBundleShortVersionString` THE WORKFLOW
  SHALL fail before building (existing behavior, must survive the port).

## 7. Scope and Boundaries

**Allowed write paths:**
- `project.yml`, `Palilogy/Info.plist`, `Palilogy/PalilogyApp.swift`
- `Palilogy/` (new: UpdaterManager, AboutWindowController, DebugSnapshots)
- `.github/workflows/release.yml`
- `scripts/set_sparkle_secret.py` (new directory)
- `docs/RELEASING.md` (new), `docs/specs/sparkle-updates.md`
- `README.md`, `CHANGELOG.md`, `CLAUDE.md`

**Read-only context:**
- `~/Development/inkling-labs/projects/handybar` (port source; ignore Lemon
  Squeezy, license keys, keychain, website publishing)

**Do not touch:**
- `main`, tags, releases (Matt does those; see CLAUDE.md)
- The Sparkle private key, in any form
- The published v1.0.0 release and its DMG
- `images/palilogy-icons.sketch` (Matt has an uncommitted edit)

If this spec conflicts with an ad-hoc prompt, this spec wins.

## 8. Verification

Local builds on this Mac need ad-hoc signing (no Mac Development cert):

```bash
cd ~/Development/inkling-labs/projects/palilogy && xcodegen generate
cd ~/Development/inkling-labs/projects/palilogy && xcodebuild -project Palilogy.xcodeproj -scheme Palilogy test CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=""
```

After each tagged release:

```bash
cd ~/Development/inkling-labs/projects/palilogy && gh release view v1.1.0 --json isDraft,isPrerelease,assets
curl -sIL https://github.com/inklinglabs/palilogy/releases/latest/download/appcast.xml | grep -i '^HTTP'
curl -sL https://github.com/inklinglabs/palilogy/releases/latest/download/appcast.xml | grep -E 'sparkle:(version|edSignature)|enclosure url'
spctl -a -vv /Applications/Palilogy.app
```

## 9. Open Questions

| Question | Resolved by | Blocks implementation? |
|---|---|---|
| ~~Sparkle 2.9.6 under Swift 6 strict concurrency~~ Resolved: compiles with a plain `import Sparkle`; ported classes are `@MainActor` | Implementation, 2026-09-21 | No |
| What small change ships in 1.1.1? Proposed: a Reveal in Finder button beside a job's plist path. Matt can veto | Matt, before T011 | No |

## Security and Privacy

- **Credentials.** The workflow uses the six canonical Apple secrets plus
  one new repo secret, `SPARKLE_PRIVATE_KEY` (EdDSA private key, shared
  across Inkling Labs apps). It is written to a temp file for
  `generate_appcast` and deleted in the same step. Claude never sees it;
  Matt sets it with the script.
- **Public repo exposure.** The workflow triggers on `v*` tag push only. No
  `pull_request` or `pull_request_target` trigger exists or is added, so
  fork PRs cannot reach any secret. Only members who can push tags can run it.
- **Committed material.** Only the Sparkle public key is committed. A full
  history scan on 2026-09-21 found no keys, tokens, `.p12` or `.p8` files.
- **What leaves the Mac.** Sparkle fetches the appcast and the DMG from
  github.com. It sends no system profile (`SUEnableSystemProfiling` stays
  off). The README's "nothing is sent anywhere" line gets amended to say so.
- **Blast radius.** A leaked private key lets an attacker sign updates for
  every Inkling Labs app, but they would still need to control the feed URL
  or the GitHub release to deliver one. A lost key orphans every installed
  copy. It lives in 1Password, Matt's login keychain, and the repo secret.

## Acceptance checklist

- [x] T001 Add Sparkle 2 package and Info.plist keys
- [x] T002 Port UpdaterManager and the Check for Updates menu item
- [x] T003 Port the About window with Check for Updates and the repo link
- [x] T004 Port debug snapshots and review the About window PNG
- [x] T005 Port Sparkle steps into the release workflow with three-asset upload
- [x] T006 Add the Sparkle secret script
- [ ] T007 Matt runs the secret script to set SPARKLE_PRIVATE_KEY
- [x] T008 Write the releasing doc
- [x] T009 Update README: download button, Sparkle note, source-build caveat
- [ ] T010 Release 1.1.0 and verify assets, appcast, feed URL, notarization
- [ ] T011 Release 1.1.1 and Matt sees 1.1.0 offer the update

---

> Update this spec in the same commit as the code it describes. A spec that
> no longer matches the code is worse than no spec.
