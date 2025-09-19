import SwiftUI

struct DashboardSummaryCard: View {
    let date: Date
    let total: Int
    let pending: Int
    let completed: Int

    private var metrics: [(title: String, value: Int)] {
        [
            ("Total", total),
            ("Pending", pending),
            ("Done", completed)
        ]
    }

    var body: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius) {
            HStack(alignment: .center, spacing: JTSpacing.lg) {
                VStack(alignment: .leading, spacing: JTSpacing.xs) {
                    Text("Today")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                    Text(formatted(date))
                        .font(JTTypography.title3)
                        .foregroundStyle(JTColors.textPrimary)
                }

                Spacer(minLength: JTSpacing.md)

                ForEach(metrics, id: \.title) { metric in
                    DashboardMetricPill(title: metric.title, value: metric.value)
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

private struct DashboardMetricPill: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: JTSpacing.xs) {
            Text(title)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)
            Text("\(value)")
                .font(JTTypography.headline)
                .foregroundStyle(JTColors.textPrimary)
        }
        .padding(.vertical, JTSpacing.sm)
        .padding(.horizontal, JTSpacing.md)
        .background(
            Capsule(style: .continuous)
                .fill(JTColors.glassHighlight)
        )
    }
}

private struct DashboardSummaryCardPreviewContainer: View {
    var body: some View {
        DashboardSummaryCard(
            date: Date(timeIntervalSince1970: 1_715_000_000),
            total: 12,
            pending: 5,
            completed: 7
        )
        .padding()
        .background(JTGradients.background.ignoresSafeArea())
    }
}

#Preview("Summary – iPhone 15 Pro") {
    DashboardSummaryCardPreviewContainer()
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}

#Preview("Summary – iPad Pro 11") {
    DashboardSummaryCardPreviewContainer()
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (4th generation)"))
        .frame(maxWidth: 700)
}
