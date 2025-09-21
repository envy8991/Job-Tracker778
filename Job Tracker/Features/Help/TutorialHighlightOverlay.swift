import SwiftUI
import UIKit

/// Describes a highlight target captured from the layout using anchors.
struct TutorialHighlightTarget: Equatable, Identifiable {
    let id: String
    let message: String
    let arrowEdge: Edge
    let shape: TutorialHighlightShape
    let padding: CGFloat
    let showsPulse: Bool
    let anchor: Anchor<CGRect>
}

/// Shape options supported by the highlight overlay.
enum TutorialHighlightShape: Equatable {
    case rounded(cornerRadius: CGFloat)
    case capsule
    case circle
}

/// Preference key storing an array of highlight targets.
struct TutorialHighlightPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialHighlightTarget] { [] }

    static func reduce(value: inout [TutorialHighlightTarget], nextValue: () -> [TutorialHighlightTarget]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TutorialHighlightModifier: ViewModifier {
    let id: String
    let message: String
    let arrowEdge: Edge
    let shape: TutorialHighlightShape
    let padding: CGFloat
    let showsPulse: Bool

    func body(content: Content) -> some View {
        content
            .anchorPreference(key: TutorialHighlightPreferenceKey.self, value: .bounds) { anchor in
                [TutorialHighlightTarget(
                    id: id,
                    message: message,
                    arrowEdge: arrowEdge,
                    shape: shape,
                    padding: padding,
                    showsPulse: showsPulse,
                    anchor: anchor
                )]
            }
    }
}

extension View {
    /// Marks a view as the target of the tutorial highlight overlay.
    func tutorialHighlight(id: String,
                           message: String,
                           arrowEdge: Edge = .top,
                           shape: TutorialHighlightShape = .rounded(cornerRadius: 12),
                           padding: CGFloat = 8,
                           showsPulse: Bool = false) -> some View {
        modifier(
            TutorialHighlightModifier(
                id: id,
                message: message,
                arrowEdge: arrowEdge,
                shape: shape,
                padding: padding,
                showsPulse: showsPulse
            )
        )
    }
}

/// Materialised highlight item containing an absolute frame.
struct TutorialHighlightItem: Identifiable, Equatable {
    let id: String
    let frame: CGRect
    let message: String
    let arrowEdge: Edge
    let shape: TutorialHighlightShape
    let showsPulse: Bool
}

/// Overlay that renders focus rings and callouts for tutorial highlights.
struct TutorialHighlightOverlay: View {
    static let coordinateSpaceName = "TutorialHighlightSpace"

    let items: [TutorialHighlightItem]

    @Environment(\.colorScheme) private var colorScheme
    @State private var cachedIDs: Set<String> = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !items.isEmpty {
                Color.black.opacity(0.35)
                    .transition(.opacity)

                ForEach(items) { item in
                    HighlightShapeView(item: item, colorScheme: colorScheme)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if !items.isEmpty {
                triggerHaptic()
                cachedIDs = Set(items.map(\.id))
            }
        }
        .onChange(of: items) { newValue in
            let newIDs = Set(newValue.map(\.id))
            guard newIDs != cachedIDs else { return }
            cachedIDs = newIDs
            if !newValue.isEmpty {
                triggerHaptic()
            }
        }
    }

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private struct HighlightShapeView: View {
        let item: TutorialHighlightItem
        let colorScheme: ColorScheme

        @State private var animatePulse = false

        var body: some View {
            GeometryReader { proxy in
                let size = proxy.size
                let calloutSize = computeCalloutSize(for: item.message, maxWidth: size.width - 24)
                let calloutOrigin = calloutPosition(for: item, calloutSize: calloutSize, containerSize: size)

                ZStack(alignment: .topLeading) {
                    focusShape
                        .stroke(borderColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .background(focusShape.fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18)))
                        .frame(width: item.frame.width, height: item.frame.height)
                        .position(x: item.frame.midX, y: item.frame.midY)

                    if item.showsPulse {
                        focusShape
                            .stroke(borderColor.opacity(0.35), lineWidth: 2)
                            .frame(width: item.frame.width + 12, height: item.frame.height + 12)
                            .position(x: item.frame.midX, y: item.frame.midY)
                            .scaleEffect(animatePulse ? 1.12 : 0.9)
                            .opacity(animatePulse ? 0 : 0.8)
                            .onAppear {
                                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                                    animatePulse = true
                                }
                            }
                    }

                    TutorialCalloutBubble(text: item.message)
                        .frame(width: calloutSize.width, height: calloutSize.height)
                        .position(x: calloutOrigin.x, y: calloutOrigin.y)
                }
                .frame(width: size.width, height: size.height)
            }
        }

        private var focusShape: some Shape {
            switch item.shape {
            case let .rounded(cornerRadius):
                return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            case .capsule:
                return AnyShape(Capsule())
            case .circle:
                return AnyShape(Circle())
            }
        }

        private var borderColor: Color {
            Color.accentColor
        }

        private func computeCalloutSize(for message: String, maxWidth: CGFloat) -> CGSize {
            let constrainedWidth = min(maxWidth, 260)
            let text = NSString(string: message)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .subheadline)
            ]
            let bounds = text.boundingRect(
                with: CGSize(width: constrainedWidth - 24, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let width = max(bounds.width + 24, 160)
            let height = bounds.height + 20
            return CGSize(width: min(width, constrainedWidth), height: height)
        }

        private func calloutPosition(for item: TutorialHighlightItem,
                                     calloutSize: CGSize,
                                     containerSize: CGSize) -> CGPoint {
            let horizontalClamp: (CGFloat) -> CGFloat = { value in
                let minValue: CGFloat = 16
                let maxValue = max(containerSize.width - calloutSize.width - 16, minValue)
                return min(max(value, minValue), maxValue)
            }
            let verticalClamp: (CGFloat) -> CGFloat = { value in
                let minValue: CGFloat = 16
                let maxValue = max(containerSize.height - calloutSize.height - 16, minValue)
                return min(max(value, minValue), maxValue)
            }

            switch item.arrowEdge {
            case .top:
                let x = horizontalClamp(item.frame.midX - calloutSize.width / 2)
                let y = verticalClamp(item.frame.minY - calloutSize.height - 12)
                return CGPoint(x: x + calloutSize.width / 2, y: y + calloutSize.height / 2)
            case .bottom:
                let x = horizontalClamp(item.frame.midX - calloutSize.width / 2)
                let y = verticalClamp(item.frame.maxY + 12)
                return CGPoint(x: x + calloutSize.width / 2, y: y + calloutSize.height / 2)
            case .leading:
                let x = horizontalClamp(item.frame.minX - calloutSize.width - 12)
                let y = verticalClamp(item.frame.midY - calloutSize.height / 2)
                return CGPoint(x: x + calloutSize.width / 2, y: y + calloutSize.height / 2)
            case .trailing:
                let x = horizontalClamp(item.frame.maxX + 12)
                let y = verticalClamp(item.frame.midY - calloutSize.height / 2)
                return CGPoint(x: x + calloutSize.width / 2, y: y + calloutSize.height / 2)
            @unknown default:
                let x = horizontalClamp(item.frame.midX - calloutSize.width / 2)
                let y = verticalClamp(item.frame.minY - calloutSize.height - 12)
                return CGPoint(x: x + calloutSize.width / 2, y: y + calloutSize.height / 2)
            }
        }
    }

    private struct TutorialCalloutBubble: View {
        let text: String
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: colorScheme == .dark ? .systemGray6 : .systemBackground))
                        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 12)
                )
        }
    }
}

private struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ wrapped: S) {
        pathBuilder = { rect in
            Path(wrapped.path(in: rect))
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}
