<p align="center">
  <img src="Palilogy/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="Palilogy icon">
</p>

# Palilogy

*(pronounced pa-LIL-uh-jee)*

Palilogy is a rhetorical device: the deliberate repetition of a word or
phrase for emphasis. It comes from the Greek *palin* ("again," the same
root as *palindrome*) and *-logia* ("speaking"). Saying it again, on
purpose, because it matters.

That is also exactly what a scheduled job is: a command your Mac repeats,
deliberately, on a schedule you chose. Hence the icon, one shape said
twice.

Palilogy schedules jobs on your Mac. Name a command, pick a time, and it
writes the launchd agent, loads it, and shows you whether it ran. It also
lists everything else already scheduled on your Mac, including your crontab.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/screen-jobs-dark.png">
  <img src="images/screen-jobs-light.png" alt="Palilogy's main window: every scheduled job on the Mac, with the selected job's status, schedule, and log output" width="100%">
</picture>

## What it does

- **Schedule jobs without touching a plist.** Name a job, give it a
  command, pick a schedule. Palilogy writes the launchd agent, loads it,
  and shows you that it is running.
- **Three ways to describe a schedule.** A simple interval ("every 15
  minutes"), days and a time ("weekdays at 5:00"), or a cron expression
  (`0 5 * * 1-5`) for people who already think in cron. Cron input is
  translated live and fills in the visual picker when it can.
- **See everything scheduled on your Mac.** Palilogy lists every user
  LaunchAgent, including ones other apps installed, with live status:
  loaded, running, last exit code. Third-party agents can be enabled,
  disabled, or deleted, but never silently rewritten.
- **Logs built in.** Jobs created in Palilogy capture stdout and stderr to
  `~/Library/Logs/Palilogy/`, viewable right in the app. If a job failed
  at 5 a.m., the answer is one click away.
- **Cron, handled respectfully.** Your existing crontab entries are listed
  read-only. Any entry can be converted to an equivalent launchd job in
  one click, and you choose whether the original line stays or goes.
  Palilogy never creates or edits cron entries.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/screen-editor-dark.png">
  <img src="images/screen-editor-light.png" alt="The job editor, with interval, days and time, and cron schedule modes" width="100%">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/screen-cron-dark.png">
  <img src="images/screen-cron-light.png" alt="Crontab entries listed read only, each with Convert and Delete actions" width="100%">
</picture>

## Why launchd

Cron still works on macOS, but Apple has treated it as legacy for years,
and it has a real flaw on laptops: if your Mac is asleep at the scheduled
minute, the job silently never runs. launchd is the scheduler macOS
actually wants you to use. It runs missed jobs after wake, and it is what
every job Palilogy creates uses under the hood. The catch has always been
that launchd wants hand-written XML and `launchctl` incantations. Palilogy
exists so you never see either.

## Requirements

- macOS 14 (Sonoma) or later.
- Palilogy is not sandboxed, because it needs to talk to `launchctl` and
  read your crontab. For the same reason it is distributed as a signed,
  notarized DMG rather than through the Mac App Store.

## Install

<p>
  <a href="https://github.com/inklinglabs/palilogy/releases/latest/download/Palilogy.dmg">
    <img src="https://img.shields.io/badge/Download-Palilogy.dmg-2ea44f?style=for-the-badge&logo=apple" alt="Download Palilogy">
  </a>
</p>

Open the DMG and drag Palilogy to Applications. Requires macOS 14 (Sonoma)
or later. Palilogy is free, signed with a Developer ID, and notarized by
Apple.

After that, Palilogy updates itself through
[Sparkle](https://sparkle-project.org): it checks for a new version now and
then, and **Palilogy > Check for Updates** checks on demand. Version 1.0.0
shipped before the updater existed, so if you have it, download the current
version once by hand.

### Build from source

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`):

```
xcodegen generate
xcodebuild -project Palilogy.xcodeproj -scheme Palilogy -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=""
```

The signing overrides give you an ad-hoc signed build without needing an
Apple developer certificate. A build you make yourself is not signed with
the Inkling Labs Developer ID, so it will not update itself into an official
release cleanly. That is expected; to move to an official build, download
the DMG above.

## What it touches

Everything Palilogy does with your jobs happens on your Mac. The only
network traffic is the update check: Palilogy fetches its update feed and
new versions from GitHub. It sends no information about you or your Mac.

- `~/Library/LaunchAgents/`: reads all agents; writes only jobs you create
  or edit (marked with a `PalilogyManaged` key).
- `launchctl`: load, unload, and run jobs, and read their status.
- Your crontab: read via `crontab -l`. The only writes are removals you
  explicitly ask for (deleting an entry, or cleaning up after a convert).
- `~/Library/Logs/Palilogy/`: log files for jobs created in the app.

## Development

Work happens on the `dev` branch; `main` is stable. The v1 design lives in
[docs/specs/palilogy-v1.md](docs/specs/palilogy-v1.md).

```
xcodebuild -project Palilogy.xcodeproj -scheme Palilogy test
```

## License

MIT. See [LICENSE](LICENSE).

Palilogy is an [Inkling Labs](https://www.inkling-labs.com) project.
