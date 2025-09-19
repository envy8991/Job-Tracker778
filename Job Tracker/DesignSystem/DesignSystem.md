# Job Tracker Design System

The `DesignSystem/` module collects the tokens and reusable components that keep
screens feeling consistent. Start here when building new UI rather than
recreating colors or glass effects in individual views.

## Tokens

| Area | Type | Notes |
| --- | --- | --- |
| Colors | `JTColors` | Brand gradient stops (`backgroundTop`, `backgroundBottom`), semantic text colors, and glass strokes. Use `JTGradients.background` for full-screen backgrounds. Includes semantic accents such as `success`, `warning`, `info`, and `error`. |
| Typography | `JTTypography` | Preconfigured fonts for screen titles, headlines, captions, and buttons. |
| Spacing | `JTSpacing` | Baseline spacing units (`xs`–`xxl`). Multiply these rather than inventing ad-hoc constants. |
| Shapes | `JTShapes` | Corner radii for cards, buttons, fields, and helper factories such as `roundedRectangle(cornerRadius:)`. |
| Elevation | `JTElevations` | Shadow recipes. Apply via `.jtShadow(JTElevations.card)` etc. |

## Surfaces and modifiers

* `.jtGlassBackground(cornerRadius:strokeColor:strokeWidth:)` wraps the ultra-thin material background, stroke, and clipping in a single modifier. Use the overload that accepts a `Shape` when you need capsules or custom shapes.
* `GlassCard` combines the glass background with the standard card shadow. Wrap content that should float above the gradient background.

## Components

* `JTPrimaryButton` renders the primary call to action. Provide the label text (and optionally a SF Symbol) and the tap action.
* `JTTextField` renders a material-backed text input. Supply the placeholder and `Binding<String>`, plus optional `icon`, secure entry, and a `JTInputState` for validation feedback. Inline helper or error messaging is supported through the `supportingText` parameter, and secure fields expose a built-in visibility toggle for accessibility.

These components already consume the tokens above. Compose them together whenever you are building new flows so typography, spacing, and color stay aligned with the rest of the experience.

### Example

```swift
VStack(spacing: JTSpacing.lg) {
    Text("Invite a teammate")
        .font(JTTypography.screenTitle)
        .foregroundStyle(JTColors.textPrimary)

    GlassCard {
        VStack(alignment: .leading, spacing: JTSpacing.md) {
            JTTextField("Email", text: $email, icon: "envelope")
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            JTPrimaryButton("Send Invite", systemImage: "paperplane.fill") {
                sendInvite()
            }
        }
        .padding(JTSpacing.lg)
    }
}
.background(JTGradients.background.ignoresSafeArea())
```
