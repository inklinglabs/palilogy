import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = AppearanceOption.system.rawValue
    @AppStorage(AppSettings.removeCronAfterConvertKey) private var removeCronAfterConvert = false

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceOption.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .onChange(of: appearance) {
                    AppSettings.applyAppearance()
                }
            }
            Section {
                Toggle("Always clean up crontab after converting", isOn: $removeCronAfterConvert)
                Text(removeCronAfterConvert
                    ? "Converting a cron entry always deletes its line from your crontab. This is the only time Palilogy changes your crontab."
                    : "Each conversion asks whether to keep the cron entry or remove its line. Palilogy never changes your crontab otherwise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
