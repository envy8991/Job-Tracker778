import SwiftUI

/// Shadow styles that express elevation and depth.
struct JTShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let none = JTShadow(color: .clear, radius: 0, x: 0, y: 0)
}

enum JTElevations {
    static let card = JTShadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 6)
    static let raised = JTShadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 12)
    static let button = JTShadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
}

extension View {
    func jtShadow(_ shadow: JTShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
