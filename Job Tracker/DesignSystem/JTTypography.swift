import SwiftUI

/// Font styles that keep typography consistent across screens.
enum JTTypography {
    static let screenTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)
    static let captionEmphasized = Font.system(size: 13, weight: .semibold, design: .default)
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)

    static func monospacedCaption(weight: Font.Weight = .medium) -> Font {
        Font.system(size: 12, weight: weight, design: .monospaced)
    }
}
