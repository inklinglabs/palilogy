#if DEBUG
import Cocoa

/// Debug-only (ported from Handybar): when `PALILOGY_SNAPSHOT_DIR` is set,
/// open each AppKit window in turn, write a PNG of it to that directory,
/// then quit. Lets layout be checked without screen-recording permission.
/// Light appearance only: offscreen caching does not render dark backgrounds.
@MainActor
enum DebugSnapshots {

    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["PALILOGY_SNAPSHOT_DIR"], !dir.isEmpty else { return }
        let directory = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSApp.appearance = NSAppearance(named: .aqua)

        func snapshot(_ window: NSWindow?, _ name: String) {
            guard let window, let view = window.contentView else {
                print("snapshot: no window for \(name)")
                return
            }
            window.layoutIfNeeded()
            view.displayIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            let composed = NSImage(size: view.bounds.size)
            composed.lockFocus()
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: view.bounds.size).fill()
            rep.draw(in: NSRect(origin: .zero, size: view.bounds.size))
            composed.unlockFocus()
            if let tiff = composed.tiffRepresentation, let out = NSBitmapImageRep(data: tiff) {
                try? out.representation(using: .png, properties: [:])?
                    .write(to: directory.appendingPathComponent("\(name).png"))
            }
            print("snapshot: wrote \(name).png \(view.bounds.size)")
        }

        let steps: [@MainActor () -> Void] = [
            { AboutWindowController.shared.show() },
            { snapshot(NSApp.windows.first { $0.title == "About Palilogy" }, "01-about") },
            { NSApp.terminate(nil) },
        ]

        var delay: TimeInterval = 1.0
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { step() }
            delay += 0.6
        }
    }
}
#endif
