import Foundation

enum LogReader {
    /// The last `maxBytes` of the file at `path`, or nil when the file does
    /// not exist yet. Large logs are truncated from the front; the viewer
    /// cares about recent output.
    static func tail(path: String, maxBytes: Int = 64 * 1024) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return "" }
        var text = String(decoding: data, as: UTF8.self)
        // Drop a partial first line when truncated mid-stream.
        if start > 0, let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }
        return text
    }
}
