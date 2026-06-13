import SwiftUI

/// Built-in themes that users can choose from without customization.
public enum JTThemePreset: String, CaseIterable, Identifiable, Codable, Equatable {
    case oceanCurrent
    case midnightDrift
    case forestTrail
    case sunsetGlow
    case glacierLight
    case emberForge
    case lunarMist

    public var id: String { rawValue }

    public var theme: JTTheme {
        switch self {
        case .oceanCurrent:
            return JTTheme(
                id: rawValue,
                name: "Ocean Current",
                subtitle: "Teal gradients with aqua accents",
                style: .dark,
                backgroundTop: Color(red: 0.10, green: 0.15, blue: 0.22),
                backgroundBottom: Color(red: 0.28, green: 0.59, blue: 0.66),
                accent: Color(red: 0.37, green: 0.80, blue: 0.78)
            )
        case .midnightDrift:
            return JTTheme(
                id: rawValue,
                name: "Midnight Drift",
                subtitle: "Purple dusk with electric violet",
                style: .dark,
                backgroundTop: Color(red: 0.07, green: 0.06, blue: 0.16),
                backgroundBottom: Color(red: 0.25, green: 0.16, blue: 0.40),
                accent: Color(red: 0.76, green: 0.45, blue: 0.98)
            )
        case .forestTrail:
            return JTTheme(
                id: rawValue,
                name: "Forest Trail",
                subtitle: "Deep greens with neon moss",
                style: .dark,
                backgroundTop: Color(red: 0.07, green: 0.18, blue: 0.15),
                backgroundBottom: Color(red: 0.08, green: 0.43, blue: 0.29),
                accent: Color(red: 0.42, green: 0.85, blue: 0.58)
            )
        case .sunsetGlow:
            return JTTheme(
                id: rawValue,
                name: "Sunset Glow",
                subtitle: "Deep sunset oranges with bold coral",
                style: .dark,
                backgroundTop: Color(red: 0.26, green: 0.07, blue: 0.13),
                backgroundBottom: Color(red: 0.64, green: 0.19, blue: 0.23),
                accent: Color(red: 0.96, green: 0.42, blue: 0.36)
            )
        case .glacierLight:
            return JTTheme(
                id: rawValue,
                name: "Glacier Night",
                subtitle: "Icy blues with aurora teal",
                style: .dark,
                backgroundTop: Color(red: 0.07, green: 0.12, blue: 0.23),
                backgroundBottom: Color(red: 0.12, green: 0.35, blue: 0.47),
                accent: Color(red: 0.30, green: 0.73, blue: 0.88)
            )
        case .emberForge:
            return JTTheme(
                id: rawValue,
                name: "Ember Forge",
                subtitle: "Molten embers with copper highlights",
                style: .dark,
                backgroundTop: Color(red: 0.12, green: 0.05, blue: 0.03),
                backgroundBottom: Color(red: 0.47, green: 0.18, blue: 0.06),
                accent: Color(red: 0.98, green: 0.57, blue: 0.24)
            )
        case .lunarMist:
            return JTTheme(
                id: rawValue,
                name: "Lunar Mist",
                subtitle: "Moonlit indigo with silver mist",
                style: .dark,
                backgroundTop: Color(red: 0.05, green: 0.10, blue: 0.18),
                backgroundBottom: Color(red: 0.27, green: 0.39, blue: 0.52),
                accent: Color(red: 0.72, green: 0.84, blue: 0.96)
            )
        }
    }
}
