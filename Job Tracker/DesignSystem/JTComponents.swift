import SwiftUI

private struct JTGlassBackgroundModifier<S: Shape>: ViewModifier {
    let shape: S
    let strokeColor: Color
    let strokeWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(.ultraThinMaterial)
            }
            .overlay {
                shape.stroke(strokeColor, lineWidth: strokeWidth)
            }
            .clipShape(shape)
    }
}

@MainActor public extension View {
    func jtGlassBackground(cornerRadius: CGFloat = JTShapes.cardCornerRadius,
                           strokeColor: Color? = nil,
                           strokeWidth: CGFloat = 1) -> some View {
        jtGlassBackground(
            shape: JTShapes.roundedRectangle(cornerRadius: cornerRadius),
            strokeColor: strokeColor,
            strokeWidth: strokeWidth
        )
    }

    func jtGlassBackground<S: Shape>(shape: S,
                                     strokeColor: Color? = nil,
                                     strokeWidth: CGFloat = 1) -> some View {
        modifier(
            JTGlassBackgroundModifier(
                shape: shape,
                strokeColor: strokeColor ?? JTColors.glassStroke,
                strokeWidth: strokeWidth
            )
        )
    }
}

/// Glass-morphism surface used for dashboard cards and detail panels.
@MainActor
struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let strokeColor: Color
    private let strokeWidth: CGFloat
    private let shadow: JTShadow
    private let content: () -> Content

    init(cornerRadius: CGFloat = JTShapes.cardCornerRadius,
         strokeColor: Color? = nil,
         strokeWidth: CGFloat = 1,
         shadow: JTShadow = JTElevations.card,
         @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.strokeColor = strokeColor ?? JTColors.glassStroke
        self.strokeWidth = strokeWidth
        self.shadow = shadow
        self.content = content
    }

    var body: some View {
        content()
            .jtGlassBackground(cornerRadius: cornerRadius, strokeColor: strokeColor, strokeWidth: strokeWidth)
            .jtShadow(shadow)
    }
}

/// A filled button that represents the primary call to action on a screen.
@MainActor
struct JTPrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: JTSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(JTTypography.button)
        }
        .buttonStyle(.jtPrimary)
    }
}

@MainActor
struct JTPrimaryButtonStyle: ButtonStyle {
    static var jtPrimary: Self { .init() }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(JTColors.onAccent)
            .padding(.vertical, JTSpacing.md)
            .padding(.horizontal, JTSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(JTColors.accent, in: JTShapes.roundedRectangle(cornerRadius: JTShapes.buttonCornerRadius))
            .jtShadow(JTElevations.button)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

@MainActor
extension ButtonStyle where Self == JTPrimaryButtonStyle {
    static var jtPrimary: JTPrimaryButtonStyle { JTPrimaryButtonStyle.jtPrimary }
}

@MainActor
struct JTPrimaryPrimitiveButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
        }
        .buttonStyle(JTPrimaryButtonStyle.jtPrimary)
    }
}

@MainActor
extension PrimitiveButtonStyle where Self == JTPrimaryPrimitiveButtonStyle {
    static var jtPrimary: JTPrimaryPrimitiveButtonStyle { JTPrimaryPrimitiveButtonStyle() }
}

/// Text input that sits on top of the glass surface styling.
enum JTInputState: Equatable {
    case neutral
    case success
    case error

    @MainActor
    func strokeColor(isFocused: Bool) -> Color {
        switch self {
        case .neutral:
            return isFocused ? JTColors.accent : JTColors.glassStroke
        case .success:
            return JTColors.success
        case .error:
            return JTColors.error
        }
    }

    @MainActor
    func iconColor(isFocused: Bool) -> Color {
        switch self {
        case .neutral:
            return isFocused ? JTColors.accent : JTColors.textMuted
        case .success:
            return JTColors.success
        case .error:
            return JTColors.error
        }
    }

    @MainActor
    var supportingTextColor: Color {
        switch self {
        case .neutral:
            return JTColors.textMuted
        case .success:
            return JTColors.success
        case .error:
            return JTColors.error
        }
    }
}

/// Glass-backed text field that supports icons, inline messaging, and password reveals.
@MainActor
struct JTTextField: View {
    private let title: String
    @Binding private var text: String
    private let icon: String?
    private let isSecure: Bool
    private let allowsSecureToggle: Bool
    private let state: JTInputState
    private let supportingText: String?
    private let customAccessibilityLabel: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPasswordVisible = false
    @FocusState private var isFocused: Bool

    init(_ title: String,
         text: Binding<String>,
         icon: String? = nil,
         isSecure: Bool = false,
         allowsSecureToggle: Bool = true,
         state: JTInputState = .neutral,
         supportingText: String? = nil,
         accessibilityLabel: String? = nil) {
        self.title = title
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.allowsSecureToggle = allowsSecureToggle
        self.state = state
        self.supportingText = supportingText
        self.customAccessibilityLabel = accessibilityLabel
    }

    private var usesSecureEntry: Bool { isSecure && !isPasswordVisible }
    private var fieldAccessibilityLabel: String { customAccessibilityLabel ?? title }

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            HStack(spacing: JTSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(state.iconColor(isFocused: isFocused))
                        .accessibilityHidden(true)
                }

                Group {
                    if usesSecureEntry {
                        SecureField(title, text: $text)
                    } else {
                        TextField(title, text: $text)
                    }
                }
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textPrimary)
                .focused($isFocused)
                .accessibilityLabel(fieldAccessibilityLabel)

                if isSecure, allowsSecureToggle {
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(state.iconColor(isFocused: isFocused))
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                    .accessibilityHint("Double tap to toggle password visibility")
                }
            }
            .padding(.vertical, JTSpacing.md)
            .padding(.horizontal, JTSpacing.lg)
            .jtGlassBackground(cornerRadius: JTShapes.fieldCornerRadius,
                               strokeColor: state.strokeColor(isFocused: isFocused),
                               strokeWidth: 1.2)
            .tint(JTColors.accent)

            if let supportingText, !supportingText.isEmpty {
                Text(supportingText)
                    .font(JTTypography.caption)
                    .foregroundStyle(state.supportingTextColor)
                    .accessibilityLabel(supportingText)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFocused)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: state)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: supportingText)
    }
}
