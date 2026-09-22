#if DEBUG
import Cocoa

/// Debug-only (pattern ported from Handybar): when `PALILOGY_SNAPSHOT_DIR`
/// is set, drive the app through its main screens in light and dark, write a
/// PNG of each window to that directory, then quit. Always runs on demo data
/// (see DemoMode), so the images never contain a real user's jobs. Lets
/// layout be checked without screen-recording permission.
///
/// For layout review only, not marketing: on macOS 26 and later the sidebar
/// and toolbar are Liquid Glass, which the window server composites, so
/// offscreen capture leaves the sidebar blank. Real screenshots come from
/// running demo mode and capturing the window with Cmd-Shift-4, Space.
@MainActor
enum DebugSnapshots {

    private static var hasRun = false

    static func runIfRequested(appState: AppState) {
        guard !hasRun, let dir = ProcessInfo.processInfo.environment["PALILOGY_SNAPSHOT_DIR"], !dir.isEmpty
        else { return }
        hasRun = true
        let directory = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var mainWindow: NSWindow? {
            NSApp.windows.first { $0.isVisible && $0.canBecomeMain && $0.title != "About Palilogy" }
        }
        var aboutWindow: NSWindow? { NSApp.windows.first { $0.title == "About Palilogy" } }
        func agent(_ name: String) -> AgentFile? { appState.agents.first { $0.agent.displayName == name } }
        func save(_ image: NSImage?, _ name: String) {
            guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                print("snapshot: nothing to write for \(name)")
                return
            }
            try? png.write(to: directory.appendingPathComponent("\(name).png"))
            print("snapshot: wrote \(name).png \(rep.pixelsWide)x\(rep.pixelsHigh)")
        }

        var steps: [@MainActor () -> Void] = [
            {
                mainWindow?.setContentSize(NSSize(width: 1080, height: 680))
                mainWindow?.center()
                mainWindow?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            },
        ]
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            steps += [
                { NSApp.appearance = NSAppearance(named: appearance) },
                { appState.scope = .all; appState.selectedJobID = agent("Nightly Backup")?.id },
                { save(render(mainWindow), "01-jobs-\(suffix)") },
                { if let job = agent("Daily Summary") { appState.presentEdit(job) } },
                { save(render(mainWindow, includingSheet: true), "02-editor-\(suffix)") },
                { appState.editorDraft = nil },
                {
                    appState.scope = .cron
                    appState.selectedJobID = appState.cronEntries
                        .first { $0.command.contains("standup") }.map { "cron-\($0.id)" }
                },
                { save(render(mainWindow), "03-cron-\(suffix)") },
                { AboutWindowController.shared.show() },
                { save(render(aboutWindow), "04-about-\(suffix)"); aboutWindow?.orderOut(nil) },
            ]
        }
        steps.append { NSApp.terminate(nil) }

        var delay: TimeInterval = 1.5
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { step() }
            delay += 0.9
        }
    }

    /// Renders the whole window, title bar included, by caching the frame
    /// view that draws the chrome and background. An attached sheet is
    /// composited on top at its real position.
    private static func render(_ window: NSWindow?, includingSheet: Bool = false) -> NSImage? {
        guard let window, let base = capture(window) else { return nil }
        var layers = [(base, NSRect(origin: .zero, size: window.frame.size))]
        if includingSheet, let sheet = window.attachedSheet, let sheetImage = capture(sheet) {
            let origin = NSPoint(x: sheet.frame.minX - window.frame.minX, y: sheet.frame.minY - window.frame.minY)
            layers.append((sheetImage, NSRect(origin: origin, size: sheet.frame.size)))
        }
        let image = NSImage(size: window.frame.size)
        image.lockFocus()
        for (rep, rect) in layers { rep.draw(in: rect) }
        image.unlockFocus()
        return image
    }

    private static func capture(_ window: NSWindow) -> NSBitmapImageRep? {
        guard let frameView = window.contentView?.superview else { return nil }
        frameView.layoutSubtreeIfNeeded()
        frameView.displayIfNeeded()
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return nil }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        return rep
    }

}
#endif
