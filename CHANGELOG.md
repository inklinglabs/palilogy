# Changelog

## 1.0.0 (2026-08-24)

First release.

- Create, edit, enable, disable, delete, and run launchd jobs from a
  native three-pane window; no plists or launchctl required.
- Schedule editor with three modes: interval, days and time, and cron
  expressions with live validation and translation.
- Live job status (loaded, running, last exit code) and a built-in log
  viewer for stdout and stderr.
- Lists every user LaunchAgent, including ones installed by other apps
  (enable, disable, and delete only; never rewritten).
- Crontab entries listed read-only with one-click conversion to launchd
  jobs; converted or unwanted lines can be removed on request. Palilogy
  never creates or edits cron entries.
- Settings: System, Light, or Dark appearance and an always-clean-up
  option for conversions.
