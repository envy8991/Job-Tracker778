import SwiftUI

/// Component shapes used throughout the app.
public enum JTShapes {
    public static let cardCornerRadius: CGFloat = 16
    public static let smallCardCornerRadius: CGFloat = 14
    public static let largeCardCornerRadius: CGFloat = 20
    public static let buttonCornerRadius: CGFloat = 12
    public static let fieldCornerRadius: CGFloat = 12
    public static let chipCornerRadius: CGFloat = 10

    public static func roundedRectangle(cornerRadius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}
