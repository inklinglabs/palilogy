import SwiftUI

/// Tails a job's log files in the detail pane, refreshing while visible.
struct LogView: View {
    var agent: LaunchAgent

    private enum Stream: String, CaseIterable, Identifiable {
        case output = "Output"
        case errors = "Errors"
        var id: String { rawValue }
    }

    @State private var stream: Stream = .output
    @State private var text: String?

    private var path: String? {
        stream == .output ? agent.standardOutPath : agent.standardErrorPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Logs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $stream) {
                    ForEach(Stream.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            logBody
        }
        .task(id: "\(agent.label)-\(stream.rawValue)") {
            while !Task.isCancelled {
                text = path.flatMap { LogReader.tail(path: $0) }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @ViewBuilder
    private var logBody: some View {
        if path == nil {
            Text("This job does not write \(stream == .output ? "its output" : "errors") to a log file.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if text?.isEmpty != false {
            Text(text == nil ? "Nothing logged yet." : "The log file is empty.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("logEnd")
                }
                .frame(height: 220)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: text) {
                    proxy.scrollTo("logEnd", anchor: .bottom)
                }
            }
        }
    }
}
