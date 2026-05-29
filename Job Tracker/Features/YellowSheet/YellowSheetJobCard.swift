import SwiftUI

struct YellowSheetJobCard: View {
    let job: Job

    var body: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack(alignment: .top, spacing: JTSpacing.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(job.shortAddress.isEmpty ? job.address : job.shortAddress)
                            .font(JTTypography.headline)
                            .foregroundStyle(JTColors.textPrimary)
                            .lineLimit(2)

                        Text(job.address)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: JTSpacing.sm)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JTColors.textMuted)
                }

                HStack(spacing: JTSpacing.xs) {
                    if let jobNumber = job.jobNumber, !jobNumber.isEmpty {
                        YellowSheetChip(text: "#\(jobNumber)", tint: JTColors.accent)
                    } else {
                        YellowSheetChip(text: "No Job #", tint: JTColors.textMuted)
                    }
                    YellowSheetChip(text: job.displayStatus, tint: universalStatusColor(job.status))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: JTSpacing.sm) {
                    if let nid = job.nidFootage, !nid.isEmpty {
                        metric("NID", value: nid, icon: "ruler")
                    }
                    if let can = job.canFootage, !can.isEmpty {
                        metric("CAN", value: can, icon: "ruler")
                    }
                    if job.hours > 0 {
                        metric("Hours", value: String(format: "%.1f", job.hours), icon: "clock")
                    }
                }

                if let materials = job.materialsUsed, !materials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(materials, systemImage: "shippingbox")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: JTSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(JTColors.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
                Text(value)
                    .font(JTTypography.captionEmphasized)
                    .foregroundStyle(JTColors.textPrimary)
            }
        }
    }
}

private struct YellowSheetChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(JTTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.vertical, 5)
            .padding(.horizontal, JTSpacing.sm)
            .background(tint.opacity(0.16), in: Capsule())
    }
}
