import SwiftUI

/// Centralized color tokens for the Job Tracker design system.
@MainActor
public enum JTColors {
    private static var theme: JTTheme { JTThemeManager.shared.theme }

    // MARK: App chroma
    public static var backgroundTop: Color { theme.backgroundTopColor }
    public static var backgroundBottom: Color { theme.backgroundBottomColor }

    public static var accent: Color { theme.accentColor }
    public static var onAccent: Color { theme.onAccentColor }

    // MARK: Text
    public static var textPrimary: Color { theme.textPrimaryColor }
    public static var textSecondary: Color { theme.textSecondaryColor }
    public static var textMuted: Color { theme.textMutedColor }

    // MARK: Surfaces
    public static var glassStroke: Color { theme.glassStrokeColor }
    public static var glassSoftStroke: Color { theme.glassSoftStrokeColor }
    public static var glassHighlight: Color { theme.glassHighlightColor }
    public static var fieldPlaceholder: Color { theme.fieldPlaceholderColor }

    // MARK: Semantic status
    public static var success: Color { Color.green.opacity(0.9) }
    public static var warning: Color { Color.yellow.opacity(0.9) }
    public static var info: Color { Color.blue.opacity(0.9) }
    public static var error: Color { Color(red: 0.96, green: 0.33, blue: 0.33) }
}

/// Gradients that compose reusable backgrounds.
@MainActor
public enum JTGradients {
    public static var background: LinearGradient { background(stops: 2) }

    public static func background(stops count: Int) -> LinearGradient {
        let colors = JTThemeManager.shared.theme.backgroundGradientStops(count: count)
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
