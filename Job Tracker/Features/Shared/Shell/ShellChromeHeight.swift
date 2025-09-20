import SwiftUI

/// Preference key used to capture the rendered height of the shell chrome overlay.
struct ShellChromeHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ShellChromeHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// The measured height of the shell chrome overlay, including the status-bar inset.
    var shellChromeHeight: CGFloat {
        get { self[ShellChromeHeightEnvironmentKey.self] }
        set { self[ShellChromeHeightEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Reads the global frame of the current view to report the shell chrome height.
    func measureShellChromeHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: ShellChromeHeightPreferenceKey.self,
                        value: max(0, proxy.frame(in: .global).maxY)
                    )
            }
        )
    }
}
