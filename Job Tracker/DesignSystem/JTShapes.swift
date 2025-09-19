import SwiftUI

/// Component shapes used throughout the app.
enum JTShapes {
    static let cardCornerRadius: CGFloat = 16
    static let smallCardCornerRadius: CGFloat = 14
    static let largeCardCornerRadius: CGFloat = 20
    static let buttonCornerRadius: CGFloat = 12
    static let fieldCornerRadius: CGFloat = 12
    static let chipCornerRadius: CGFloat = 10

    static func roundedRectangle(cornerRadius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}
