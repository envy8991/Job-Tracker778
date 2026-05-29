import SwiftUI

struct YellowSheetDetailView: View {
    let yellowSheet: YellowSheet

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: JTSpacing.lg) {
                    GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
                        VStack(alignment: .leading, spacing: JTSpacing.md) {
                            Text("Yellow Sheet Detail")
                                .font(JTTypography.title3)
                                .foregroundStyle(JTColors.textPrimary)

                            detailRow(icon: "calendar", title: "Week Starting", value: formattedDate(yellowSheet.weekStart))
                            detailRow(icon: "briefcase", title: "Total Jobs", value: "\(yellowSheet.totalJobs)")
                        }
                        .padding(JTSpacing.lg)
                    }

                    if let pdfURLString = yellowSheet.pdfURL,
                       let url = URL(string: pdfURLString),
                       !pdfURLString.isEmpty {
                        NavigationLink(destination: PDFViewer(url: url)) {
                            Label("View PDF", systemImage: "doc.richtext")
                                .font(JTTypography.button)
                                .foregroundStyle(JTColors.onAccent)
                                .padding(.vertical, JTSpacing.md)
                                .frame(maxWidth: .infinity)
                                .background(JTColors.accent, in: JTShapes.roundedRectangle(cornerRadius: JTShapes.buttonCornerRadius))
                        }
                    } else {
                        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
                            Label("No PDF Available", systemImage: "exclamationmark.triangle")
                                .font(JTTypography.subheadline)
                                .foregroundStyle(JTColors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(JTSpacing.lg)
                        }
                    }
                }
                .padding(JTSpacing.lg)
            }
        }
        .navigationTitle("Yellow Sheet Detail")
        .navigationBarTitleDisplayMode(.inline)
        .jtNavigationBarStyle()
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: JTSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(JTColors.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
                Text(value)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textPrimary)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
