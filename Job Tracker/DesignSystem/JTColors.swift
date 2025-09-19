import SwiftUI

/// Centralized color tokens for the Job Tracker design system.
enum JTColors {
    // MARK: App chroma
    static let backgroundTop = Color(red: 0.1725, green: 0.2431, blue: 0.3137)
    static let backgroundBottom = Color(red: 0.2980, green: 0.6314, blue: 0.6863)

    static let accent = Color.accentColor
    static let onAccent = Color.white

    // MARK: Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.85)
    static let textMuted = Color.white.opacity(0.6)

    // MARK: Surfaces
    static let glassStroke = Color.white.opacity(0.18)
    static let glassSoftStroke = Color.white.opacity(0.06)
    static let glassHighlight = Color.white.opacity(0.12)
    static let fieldPlaceholder = Color.white.opacity(0.5)

    // MARK: Semantic status
    static let success = Color.green.opacity(0.9)
    static let warning = Color.yellow.opacity(0.9)
    static let info = Color.blue.opacity(0.9)
    static let error = Color(red: 0.96, green: 0.33, blue: 0.33)
}

/// Gradients that compose reusable backgrounds.
enum JTGradients {
    static let background = LinearGradient(
        colors: [JTColors.backgroundTop, JTColors.backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
