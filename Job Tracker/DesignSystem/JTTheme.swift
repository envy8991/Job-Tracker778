import SwiftUI
import UIKit

/// Describes a complete color palette for the Job Tracker experience.
public struct JTTheme: Identifiable, Codable, Equatable {
    public enum Style: String, Codable, Identifiable {
        case dark

        public var id: String { rawValue }

        public var colorScheme: ColorScheme {
            switch self {
            case .dark: return .dark
            }
        }

        var textPrimary: Color {
            Color.white
        }

        var textSecondary: Color {
            Color.white.opacity(0.85)
        }

        var textMuted: Color {
            Color.white.opacity(0.6)
        }

        var fieldPlaceholder: Color {
            Color.white.opacity(0.5)
        }

        var glassStroke: Color {
            Color.white.opacity(0.18)
        }

        var glassSoftStroke: Color {
            Color.white.opacity(0.06)
        }

        var glassHighlight: Color {
            Color.white.opacity(0.12)
        }
    }

    public struct ColorValue: Codable, Equatable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var alpha: Double

        public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        public init(color: Color) {
            self.init(uiColor: UIColor(color))
        }

        public init(uiColor: UIColor) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            self.red = Double(r)
            self.green = Double(g)
            self.blue = Double(b)
            self.alpha = Double(a)
        }

        public var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }

        public var uiColor: UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        public func interpolated(to other: ColorValue, fraction: Double) -> ColorValue {
            let t = fraction.clamped(to: 0...1)
            return ColorValue(
                red: red + (other.red - red) * t,
                green: green + (other.green - green) * t,
                blue: blue + (other.blue - blue) * t,
                alpha: alpha + (other.alpha - alpha) * t
            )
        }

        public var relativeLuminance: Double {
            func adjust(_ component: Double) -> Double {
                if component <= 0.03928 {
                    return component / 12.92
                } else {
                    return pow((component + 0.055) / 1.055, 2.4)
                }
            }

            let r = adjust(red)
            let g = adjust(green)
            let b = adjust(blue)
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
    }

    public var id: String
    public var name: String
    public var subtitle: String?
    public var style: Style
    public var backgroundTop: ColorValue
    public var backgroundBottom: ColorValue
    public var accent: ColorValue
    public var onAccentOverride: ColorValue?

    public init(id: String = UUID().uuidString,
                name: String,
                subtitle: String? = nil,
                style: Style,
                backgroundTop: Color,
                backgroundBottom: Color,
                accent: Color,
                onAccentOverride: Color? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.style = style
        self.backgroundTop = ColorValue(color: backgroundTop)
        self.backgroundBottom = ColorValue(color: backgroundBottom)
        self.accent = ColorValue(color: accent)
        if let onAccentOverride {
            self.onAccentOverride = ColorValue(color: onAccentOverride)
        } else {
            self.onAccentOverride = nil
        }
    }

    public init(id: String,
                name: String,
                subtitle: String? = nil,
                style: Style,
                backgroundTop: ColorValue,
                backgroundBottom: ColorValue,
                accent: ColorValue,
                onAccentOverride: ColorValue? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.style = style
        self.backgroundTop = backgroundTop
        self.backgroundBottom = backgroundBottom
        self.accent = accent
        self.onAccentOverride = onAccentOverride
    }

    public var backgroundTopColor: Color { backgroundTop.color }
    public var backgroundBottomColor: Color { backgroundBottom.color }
    public var accentColor: Color { accent.color }

    public var onAccentColor: Color {
        if let override = onAccentOverride {
            return override.color
        }
        return accent.relativeLuminance > 0.55 ? Color.black : Color.white
    }

    public var colorScheme: ColorScheme { style.colorScheme }
    public var textPrimaryColor: Color { style.textPrimary }
    public var textSecondaryColor: Color { style.textSecondary }
    public var textMutedColor: Color { style.textMuted }
    public var fieldPlaceholderColor: Color { style.fieldPlaceholder }
    public var glassStrokeColor: Color { style.glassStroke }
    public var glassSoftStrokeColor: Color { style.glassSoftStroke }
    public var glassHighlightColor: Color { style.glassHighlight }

    public func backgroundGradientStops(count: Int) -> [Color] {
        guard count > 1 else { return [backgroundTopColor] }
        let steps = max(2, count)
        return (0..<steps).map { index in
            let fraction = Double(index) / Double(steps - 1)
            return backgroundTop.interpolated(to: backgroundBottom, fraction: fraction).color
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
