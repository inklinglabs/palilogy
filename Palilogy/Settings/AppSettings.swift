import AppKit

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// UserDefaults-backed settings, one key constant per setting.
@MainActor
enum AppSettings {
    static let appearanceKey = "appearance"
    static let removeCronAfterConvertKey = "removeCronAfterConvert"
    /// [raw crontab line: label of the job the conversion created].
    static let convertedCronJobsKey = "convertedCronJobs"

    static var appearance: AppearanceOption {
        AppearanceOption(
            rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? ""
        ) ?? .system
    }

    static var removeCronAfterConvert: Bool {
        UserDefaults.standard.bool(forKey: removeCronAfterConvertKey)
    }

    static func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
