import SwiftUI

/// Centralized color tokens for the Job Tracker design system.
public enum JTColors {
    // MARK: App chroma
    public static let backgroundTop = Color(red: 0.1725, green: 0.2431, blue: 0.3137)
    public static let backgroundBottom = Color(red: 0.2980, green: 0.6314, blue: 0.6863)

    public static let accent = Color.accentColor
    public static let onAccent = Color.white

    // MARK: Text
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.85)
    public static let textMuted = Color.white.opacity(0.6)

    // MARK: Surfaces
    public static let glassStroke = Color.white.opacity(0.18)
    public static let glassSoftStroke = Color.white.opacity(0.06)
    public static let glassHighlight = Color.white.opacity(0.12)
    public static let fieldPlaceholder = Color.white.opacity(0.5)

    // MARK: Semantic status
    public static let success = Color.green.opacity(0.9)
    public static let warning = Color.yellow.opacity(0.9)
    public static let info = Color.blue.opacity(0.9)
    public static let error = Color(red: 0.96, green: 0.33, blue: 0.33)
}

/// Gradients that compose reusable backgrounds.
public enum JTGradients {
    public static let background = LinearGradient(
        colors: [JTColors.backgroundTop, JTColors.backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
