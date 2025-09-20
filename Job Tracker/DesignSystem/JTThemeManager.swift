import SwiftUI

@MainActor
final class JTThemeManager: ObservableObject {
    enum Selection: Equatable {
        case preset(JTThemePreset)
        case custom(JTTheme)
    }

    static let shared = JTThemeManager()

    @Published private(set) var theme: JTTheme
    @Published private(set) var selection: Selection

    private let defaults: UserDefaults

    private struct Keys {
        static let selectionMode = "com.jobtracker.theme.selectionMode"
        static let selectedPreset = "com.jobtracker.theme.selectedPreset"
        static let customTheme = "com.jobtracker.theme.customTheme"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let mode = defaults.string(forKey: Keys.selectionMode)
        switch mode {
        case "custom":
            if let custom = defaults.data(forKey: Keys.customTheme),
               let theme = try? JSONDecoder().decode(JTTheme.self, from: custom) {
                self.theme = theme
                self.selection = .custom(theme)
                return
            }
            fallthrough
        case "preset":
            if let presetName = defaults.string(forKey: Keys.selectedPreset),
               let preset = JTThemePreset(rawValue: presetName) {
                let theme = preset.theme
                self.theme = theme
                self.selection = .preset(preset)
                return
            }
            fallthrough
        default:
            let preset = JTThemePreset.oceanCurrent
            self.theme = preset.theme
            self.selection = .preset(preset)
        }
    }

    var availablePresets: [JTThemePreset] { JTThemePreset.allCases }

    var isUsingCustomTheme: Bool {
        if case .custom = selection { return true }
        return false
    }

    var selectedPreset: JTThemePreset? {
        if case let .preset(preset) = selection { return preset }
        return nil
    }

    func applyPreset(_ preset: JTThemePreset) {
        selection = .preset(preset)
        theme = preset.theme
        defaults.set("preset", forKey: Keys.selectionMode)
        defaults.set(preset.rawValue, forKey: Keys.selectedPreset)
    }

    func applyCustom(_ theme: JTTheme) {
        selection = .custom(theme)
        self.theme = theme
        defaults.set("custom", forKey: Keys.selectionMode)
        defaults.removeObject(forKey: Keys.selectedPreset)
        if let data = try? JSONEncoder().encode(theme) {
            defaults.set(data, forKey: Keys.customTheme)
        }
    }

    func storedCustomTheme() -> JTTheme? {
        if case let .custom(theme) = selection { return theme }
        if let data = defaults.data(forKey: Keys.customTheme),
           let decoded = try? JSONDecoder().decode(JTTheme.self, from: data) {
            return decoded
        }
        return nil
    }
}
