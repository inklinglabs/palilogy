# Mac App Styling Conventions (from Captain's Log)

Design language and UI patterns from Captain's Log (github.com/mattlinebarger/captains-log, local at `~/Development/inkling-labs/projects/captains-log`). Reference implementation for new Inkling Labs Mac apps. Lift code from the paths noted rather than reinventing.

## Design philosophy

Modeled on Things by Cultured Code: calm, quiet, generous white space, restrained typography, nothing decorative that does not carry information. Native SwiftUI look, never web-styled. The app should feel like it shipped with macOS.

## Color rules

- Semantic system colors only. Never hardcode a color for UI chrome. `Color(nsColor: .textBackgroundColor)` for content backgrounds, `.secondary` for supporting text, system accent where selection color is needed.
- Light and dark mode both work automatically because of the rule above; verify both before calling any screen done.
- Offer a theme setting: System, Light, Dark. Implement by setting `NSApp.appearance` (nil for System, `NSAppearance(named: .aqua/.darkAqua)`), stored in UserDefaults, applied at launch and live on change. See `CaptainsLog/Settings/AppSettings.swift` (AppearanceOption) and `applyAppearance` in AppState.
- Highlighting matches (search etc.): `NSColor.findHighlightColor` background with black foreground.

## Typography

- System font everywhere. Reading/content text: `.font(.system(size: 15))` with `.lineSpacing(6)`, max content width around 640pt, left aligned, `.textSelection(.enabled)`.
- List rows: `.subheadline.weight(.semibold)` for the primary line, `.callout` + `.secondary` for the preview line, `.caption` + `.secondary` for metadata.
- Explanatory text under controls: `.font(.caption)` + `.foregroundStyle(.secondary)`.

## Window layout

- Browser-style windows: `NavigationSplitView` three-pane. Sidebar `.listStyle(.sidebar)` with `Label` rows and section headers; content list `.listStyle(.inset)` with card-like rows (`.padding(.vertical, 6)`); detail pane in a `ScrollView` with `.padding(28)`.
- Sidebar scopes follow the Things pattern: Today, This Week, All, then history (by month) in a second section.
- Empty states: `ContentUnavailableView` always, including a distinct search empty state (`ContentUnavailableView.search(text:)`). Never a blank pane, never stale results.
- Default window size around 960x620.

## Settings window

- `TabView` with `.tabItem` Labels, one pane per topic (General, Recording, Models, Chat with AI in the reference). Frame `.frame(width: 500)` + `.fixedSize(horizontal: false, vertical: true)` so each tab is exactly as tall as its content. `Form` + `.formStyle(.grouped)` inside each pane.
- Every non-obvious control gets a one-sentence plain-language caption underneath. Write for a non-technical user: say what the thing does for them, not what it is ("Turns your voice into text", not "Whisper model selection").
- State honesty in UI copy: privacy claims stated plainly ("Everything runs on this Mac; nothing is sent anywhere"), unsupported things stated plainly too, with the reason.
- Settings changes apply live wherever possible (onChange writes UserDefaults and applies immediately); when they cannot, a caption says when they apply.

## Menu bar apps

- `MenuBarExtra` + `LSUIElement`. Idle icon is a custom template image: pure black + alpha PNG (512px source), `isTemplate = true`, rendered at 15x15pt so macOS recolors it for light/dark menu bars. Transient states (recording, busy) switch to SF Symbols so the change is unmistakable. See `CaptainsLogApp.swift` (menuBarLabel).
- Offer a presence setting: Menu Bar, Dock, or both, via `NSApp.setActivationPolicy` applied live. Dock-click with no windows opens the main window (`applicationShouldHandleReopen`).
- Two mandatory gotcha fixes: call `NSApp.activate(ignoringOtherApps: true)` before `openSettings()` or the Settings window opens behind others; implement `applicationShouldTerminateAfterLastWindowClosed` returning false in the app delegate or closing any window quits the app.
- Global hotkeys: Carbon `RegisterEventHotKey` (no Accessibility permission, actually consumes the keystroke). See `CaptainsLog/Capture/HotKeyManager.swift`. Offer a small set of preset combos in Settings rather than a free-form recorder.

## Notifications

- `UNUserNotificationCenter`. Success notifications carry a useful payload (duration plus first line of the result) and clicking opens the produced artifact. Failure notifications say what happened and what the app did about it. Remember macOS Focus modes swallow banners silently; mention it in troubleshooting docs.

## App icon

- Flat vector style, two-color palette, one bold silhouette readable at 16px, no text. Captain's Log uses deep navy + gold with a subtle starfield. Source assets live in `images/` (Sketch file + raw PNG + icns). Menu bar icon is a separate, simpler glyph, not a shrunken app icon.

## Writing voice in UI

- Direct and plain. No jargon in user-facing text (models, MCP, transcription engines get plain descriptions). No exclamation marks, no marketing tone inside the app. No em dashes anywhere.

## Supporting technical conventions

- Project defined in `project.yml` with XcodeGen; `.xcodeproj` gitignored. Swift 6, strict concurrency (expect `@Sendable` requirements on system-framework callbacks and `nonisolated(unsafe)` for C context pointers freed in deinit).
- Long-running work (inference, file processing) lives in actors, off the main thread; UI state on a `@MainActor @Observable` AppState.
- UserDefaults-backed settings behind a small `AppSettings` enum namespace, one defaults key constant per setting.
- Follow Inkling Labs standards for repo setup, branching, and releases (github.com/mattlinebarger/inkling-labs-dev-standards). New projects scaffold with /project-init.
