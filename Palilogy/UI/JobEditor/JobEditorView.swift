import SwiftUI

struct JobEditorView: View {
    @Environment(AppState.self) private var state
    @State var draft: JobDraft
    @State private var isSaving = false

    private var isNew: Bool { draft.existingLabel == nil }

    private var validationError: String? {
        draft.validationError(existingLabels: state.labelsInUse(excluding: draft.existingLabel))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text("Nightly Backup"))
                    TextField(
                        "Command", text: $draft.command,
                        prompt: Text("/Users/you/bin/backup.sh"), axis: .vertical
                    )
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1...4)
                    caption("Runs in zsh. Use full paths; jobs do not see your shell profile.")
                }
                Section("Schedule") {
                    Picker("Repeats", selection: $draft.mode) {
                        Text("Interval").tag(JobDraft.Mode.interval)
                        Text("Days & Time").tag(JobDraft.Mode.calendar)
                        Text("Cron").tag(JobDraft.Mode.cron)
                        if draft.mode == .advanced {
                            Text("Current").tag(JobDraft.Mode.advanced)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch draft.mode {
                    case .interval: intervalFields
                    case .calendar: calendarFields
                    case .cron: cronFields
                    case .advanced: advancedFields
                    }
                }
                Section {
                    Toggle("Also run when enabled", isOn: $draft.runAtLoad)
                    caption("Runs the command once right away each time the job is turned on.")
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if let validationError, !draft.name.isEmpty || !draft.command.isEmpty {
                    Text(validationError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { state.editorDraft = nil }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Create Job" : "Save Changes") {
                    isSaving = true
                    Task {
                        await state.save(draft)
                        isSaving = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil || isSaving)
            }
            .padding(16)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Schedule fields

    private var intervalFields: some View {
        HStack {
            Text("Every")
            TextField("", value: $draft.intervalValue, format: .number)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
            Stepper("", value: $draft.intervalValue, in: 1...999)
                .labelsHidden()
            Picker("", selection: $draft.intervalUnit) {
                Text("minutes").tag(JobDraft.IntervalUnit.minutes)
                Text("hours").tag(JobDraft.IntervalUnit.hours)
            }
            .labelsHidden()
            .frame(width: 110)
        }
    }

    private var calendarFields: some View {
        Group {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { day in
                    Toggle(
                        ["S", "M", "T", "W", "T", "F", "S"][day],
                        isOn: Binding(
                            get: { draft.weekdays.contains(day) },
                            set: { on in
                                if on { draft.weekdays.insert(day) } else { draft.weekdays.remove(day) }
                            }
                        )
                    )
                    .toggleStyle(.button)
                    .frame(minWidth: 28)
                }
            }
            caption(draft.weekdays.isEmpty ? "No days selected means every day." : daySummary)
            DatePicker(
                "At",
                selection: Binding(
                    get: {
                        Calendar.current.date(
                            from: DateComponents(hour: draft.hour, minute: draft.minute)
                        ) ?? .now
                    },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        draft.hour = parts.hour ?? 0
                        draft.minute = parts.minute ?? 0
                    }
                ),
                displayedComponents: .hourAndMinute
            )
        }
    }

    private var cronFields: some View {
        Group {
            TextField("Expression", text: $draft.cronText, prompt: Text("*/15 * * * *"))
                .font(.system(size: 13, design: .monospaced))
                .autocorrectionDisabled()
                .onChange(of: draft.cronText) {
                    // A representable expression fills in the picker too, so
                    // flipping back to Interval or Days & Time shows it.
                    if let schedule = try? CronParser.parse(draft.cronText) {
                        var copy = draft
                        if copy.adopt(schedule) {
                            copy.mode = .cron
                            draft = copy
                        }
                    }
                }
            caption(cronCaption)
        }
    }

    private var advancedFields: some View {
        Group {
            Text(draft.preservedSchedule?.displayText ?? "Runs on demand")
            caption("This schedule is more detailed than the picker shows. Saving keeps it exactly as it is.")
        }
    }

    // MARK: - Captions

    private var cronCaption: String {
        if draft.cronText.isEmpty {
            return "Five fields: minute, hour, day, month, weekday."
        }
        do {
            return try CronParser.parse(draft.cronText).displayText
        } catch {
            return error.localizedDescription
        }
    }

    private var daySummary: String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return draft.weekdays.sorted().map { names[$0] }.joined(separator: ", ")
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    JobEditorView(draft: JobDraft()).environment(AppState())
}
