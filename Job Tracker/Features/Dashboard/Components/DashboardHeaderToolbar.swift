import SwiftUI

struct DashboardHeaderToolbar: View {
    let title: String
    let subtitle: String
    let isPreparingShare: Bool
    let shareAccessibilityLabel: String
    let onCalendarTap: () -> Void
    let onShareTap: () -> Void

    var body: some View {
        HStack(spacing: JTSpacing.md) {
            Button(action: onCalendarTap) {
                Image(systemName: "calendar")
                    .font(.headline)
                    .frame(width: 28, height: 28)
                    .padding(JTSpacing.xs)
                    .jtGlassBackground(shape: Circle(), strokeColor: JTColors.glassStroke.opacity(0.6))
            }
            .buttonStyle(.plain)

            VStack(spacing: JTSpacing.xs / 2) {
                Text(title)
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                Text(subtitle)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Button(action: onShareTap) {
                ZStack {
                    if isPreparingShare {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                    }
                }
                .frame(width: 28, height: 28)
                .padding(JTSpacing.xs)
                .jtGlassBackground(shape: Circle(), strokeColor: JTColors.glassStroke.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shareAccessibilityLabel)
            .accessibilityHint("Creates a summary for the selected day")
            .disabled(isPreparingShare)
        }
        .padding(.horizontal, JTSpacing.lg)
        .padding(.vertical, JTSpacing.md)
        .jtGlassBackground(cornerRadius: JTShapes.largeCardCornerRadius)
    }
}

private struct DashboardHeaderToolbarPreviewContainer: View {
    let isPreparingShare: Bool

    var body: some View {
        DashboardHeaderToolbar(
            title: "Jobs",
            subtitle: "April 29, 2025",
            isPreparingShare: isPreparingShare,
            shareAccessibilityLabel: "Share Jobs for April 29, 2025",
            onCalendarTap: {},
            onShareTap: {}
        )
        .padding()
        .background(JTGradients.background.ignoresSafeArea())
    }
}

#Preview("Header – iPhone 15 Pro") {
    DashboardHeaderToolbarPreviewContainer(isPreparingShare: false)
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}

#Preview("Header – iPad Pro 11") {
    DashboardHeaderToolbarPreviewContainer(isPreparingShare: true)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (4th generation)"))
        .frame(maxWidth: 600)
}
