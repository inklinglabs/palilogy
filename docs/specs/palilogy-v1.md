# Spec: Palilogy v1

**Repo:** palilogy
**Created:** 2026-08-23

## 1. Problem

Scheduling a job on macOS means hand-writing a launchd plist in
`~/Library/LaunchAgents` and driving it with `launchctl`, whose subcommands
have changed across macOS versions and give little feedback on failure. Many
people fall back to cron, which macOS still runs but treats as legacy: cron
jobs skip silently when the Mac is asleep and their syntax is cryptic. There
is no built-in way to see everything scheduled on your Mac, whether it ran,
or why it failed.

## 2. Goals

1. Create, edit, enable, disable, and delete user LaunchAgents from a native
   SwiftUI window without ever showing the user a plist.
2. List existing crontab entries read-only, each with a Convert action that
   produces an equivalent LaunchAgent.
3. Schedule editor accepts both a visual picker and a 5-field cron expression,
   translated to `StartCalendarInterval`/`StartInterval`.
4. Every job shows live status: loaded or not, last exit code, and captured
   stdout/stderr viewable in the app.
5. A job created in the app runs at its scheduled time and its output appears
   in the app's log viewer.

## 3. Non-Goals

- **Menu bar presence.** Excluded entirely per Matt, not backlogged.
- **Managing cron as a backend.** Cron is read-only, with one opt-in
  exception: a settings toggle (default off) lets Convert also remove the
  converted line from the crontab. No other crontab writes exist.
- **System agents/daemons (`/Library/LaunchAgents`, `/Library/LaunchDaemons`).**
  Root-owned, high blast radius, excluded from v1.
- **Advanced launchd triggers (WatchPaths, Sockets, MachServices).** v1 is
  time-based scheduling plus RunAtLoad only. Keeps the editor simple.
- **App Store distribution.** launchctl and `crontab -l` do not work sandboxed.
  Developer ID + notarized DMG only, which the release workflow already does.

## 4. Proposed Approach

SwiftUI app, Swift 6 strict concurrency, XcodeGen `project.yml`, following
the conventions and reference implementation in `docs/mac-app-styling.md`
(NavigationSplitView three-pane layout, AppState/AppSettings patterns, theme
setting, grouped-form Settings window).

**Data sources.** Two, merged into one job list:

- `~/Library/LaunchAgents/*.plist`, parsed with `PropertyListDecoder`.
  Jobs the app created carry a marker key (`PalilogyManaged: true`) in
  the plist and are fully editable. Agents the app did not create (foreign
  agents) are enable/disable/delete only; the editor is not offered for
  them, since third-party apps own those files and rewriting them risks
  breaking their owners.
- `crontab -l` output, parsed into entries. Read-only rows in a separate
  sidebar scope, each with a Convert button.

**launchd integration.** A `LaunchdService` actor shells out to `launchctl`
using the modern subcommands: `bootstrap gui/$UID` / `bootout gui/$UID` for
enable/disable, `kickstart` for Run Now, `print` for loaded state and last
exit code. Plist writes go to `~/Library/LaunchAgents` followed by a
bootout/bootstrap cycle so edits take effect immediately.

**Logs.** Jobs the app creates or edits get `StandardOutPath` /
`StandardErrorPath` pointing at `~/Library/Logs/Palilogy/<label>.out.log`
and `.err.log`. The detail pane tails the files. Jobs with their own log
paths show those instead; jobs with none show an explanatory empty state.

**Schedule editor.** Two input modes over one internal model: a visual picker
(every N minutes/hours, or calendar: weekdays + time) and a cron expression
field. Cron parsing covers the 5-field syntax including lists, ranges, and
steps, expanding to one or more `StartCalendarInterval` dictionaries;
`*/N` on minutes with the other fields `*` maps to `StartInterval`. The two
modes stay in sync: a parsed cron expression populates the picker when it
can be represented there.

**Trade-offs.**

- Shelling out to `launchctl` instead of private frameworks: the output is
  not a stable API and needs parsing, but it is the only supported surface,
  and it is what every competitor does.
- Showing all user agents, not just app-created ones: riskier (users can
  break third-party updaters) but "see everything scheduled on my Mac" is
  the core value. Mitigated by foreign agents being enable/disable/delete
  only, never rewritten.

## 5. Alternatives Considered

- **Cron as a write backend alongside launchd.** Rejected: doubles the edit,
  validation, status, and logging surface for a backend that skips jobs
  during sleep and is legacy on macOS. Cron stays read-only.
- **SMAppService (ServiceManagement framework) instead of launchctl.**
  Rejected for v1: it only manages agents bundled inside the app, so it
  cannot list or control arbitrary user agents, which is the whole point.
- **Menu bar app.** Rejected per Matt: no point for this tool.

## 6. Acceptance Criteria

- GIVEN the schedule "every weekday at 5:00" WHEN the user saves a new job
  THEN a plist exists in `~/Library/LaunchAgents` with five
  `StartCalendarInterval` entries (Weekday 1 through 5, Hour 5, Minute 0)
  and `launchctl print gui/$UID/<label>` reports the job loaded.
- GIVEN the cron expression `*/15 * * * *` WHEN entered in the cron field
  THEN the picker shows "every 15 minutes" and the saved plist contains
  `StartInterval` 900.
- GIVEN an invalid cron expression (e.g. `61 * * * *`) WHEN entered THE
  SYSTEM SHALL disable Save and show which field is out of range.
- GIVEN a job whose command exits non-zero WHEN it runs THEN the job list
  shows the exit code and the detail pane shows the captured stderr.
- GIVEN a crontab with at least one entry WHEN the app launches THEN the
  entry appears under the Cron scope with no edit or delete controls.
- GIVEN a cron entry and the always-clean-up setting off (default) WHEN the
  user clicks Convert THEN the dialog offers "Convert" and "Convert and
  Remove from Crontab"; the first leaves the entry in the crontab marked
  Converted, the second removes its line. Either way an equivalent loaded
  LaunchAgent exists afterward.
- GIVEN the always-clean-up setting on WHEN the user converts THEN the
  entry's line is removed from the crontab without a keep option; every
  other crontab line is unchanged.
- GIVEN an empty crontab (`crontab -l` exits 1) WHEN the app launches THEN
  the Cron scope shows a ContentUnavailableView, not an error.
- GIVEN a LaunchAgent the app did not create WHEN the user selects it THEN
  no Edit control is offered; enable, disable, and delete are available,
  and delete requires a confirmation naming the plist path.
- GIVEN a disabled job WHEN its scheduled time passes THEN the command does
  not run.
- WHEN the user clicks Run Now on a loaded job THEN the command executes
  within 5 seconds and its output appears in the log viewer.

## 7. Scope and Boundaries

**Allowed write paths:**
- `project.yml`, `Palilogy/` (app source, to be created)
- `docs/specs/palilogy-v1.md` (this file)
- `CLAUDE.md` (Commands and Architecture sections as they solidify)
- At runtime: `~/Library/LaunchAgents/`, `~/Library/Logs/Palilogy/`

**Read-only context:**
- `docs/mac-app-styling.md`
- `.github/workflows/release.yml` (defines scheme/project names; do not edit)
- At runtime: user crontab via `crontab -l`

**Do not touch:**
- The crontab, except removing a just-converted line when the clean-up
  setting is on
- `/Library/LaunchAgents`, `/Library/LaunchDaemons`, anything under `/System`
- `main` branch, tags, releases (per CLAUDE.md)

If this spec conflicts with an ad-hoc prompt, this spec wins.

## 8. Verification

Project does not exist yet; commands assume the XcodeGen setup from T001 and
match the names in `.github/workflows/release.yml`.

```bash
xcodegen generate
xcodebuild -project Palilogy.xcodeproj -scheme Palilogy -configuration Debug build
xcodebuild -project Palilogy.xcodeproj -scheme Palilogy test
```

Manual pass: create a job that appends `date` to a file every minute, watch
it fire twice, check status and logs in the app, disable it, confirm it
stops, delete it, confirm the plist is gone.

## 9. Open Questions

| Question | Resolved by | Blocks implementation? |
|---|---|---|
| ~~Convert crontab clean-up~~ Resolved: settings toggle, default off | Matt, 2026-08-23 | No |
| ~~Minimum macOS version~~ Resolved: 14.0 | Matt, 2026-08-23 | No |
| ~~Foreign agent editing~~ Resolved: enable/disable/delete only in v1, no editor | Matt, 2026-08-23 | No |

## Task Breakdown

- [x] T001 XcodeGen scaffold: `project.yml`, app target Palilogy, bundle ID `com.inklinglabs.palilogy`, Swift 6, no sandbox, min macOS version (`project.yml`, `Palilogy/`)
- [x] T002 Job model + LaunchAgent plist codec with round-trip tests (`Palilogy/Models/`)
- [x] T003 [P] Cron expression parser to StartCalendarInterval/StartInterval with tests (`Palilogy/Models/CronParser.swift`)
- [x] T004 [P] `LaunchdService` actor: list, bootstrap, bootout, kickstart, print parsing (`Palilogy/Services/LaunchdService.swift`)
- [x] T005 [P] `CrontabService` actor: read and parse `crontab -l` (`Palilogy/Services/CrontabService.swift`)
- [x] T006 AppState + three-pane main window: sidebar scopes (All, Enabled, Disabled, Cron), job list, detail pane per styling guide (`Palilogy/UI/`)
- [x] T007 Job editor sheet: name, command, schedule picker + cron field, validation (`Palilogy/UI/JobEditor/`)
- [x] T008 Status + log capture: launchctl print polling, log file tail view (`Palilogy/UI/`)
- [x] T009 Convert flow: cron entry to LaunchAgent, Converted badge, opt-in crontab clean-up setting (`Palilogy/UI/`)
- [ ] T010 Settings window and light/dark verification done; remaining: app icon (Matt) (`Palilogy/Settings/`)

---

> Update this spec in the same commit as the code it describes. A spec that
> no longer matches the code is worse than no spec.
