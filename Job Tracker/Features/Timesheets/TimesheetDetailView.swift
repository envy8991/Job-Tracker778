import SwiftUI
import PDFKit

struct TimesheetDetailView: View {
    let timesheet: Timesheet
    @State private var showPDFViewer = false

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: JTSpacing.lg) {
                    GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
                        VStack(alignment: .leading, spacing: JTSpacing.md) {
                            Text("Timesheet Summary")
                                .font(JTTypography.title3)
                                .foregroundStyle(JTColors.textPrimary)

                            detailRow(icon: "calendar", title: "Week Starting", value: formattedDate(timesheet.weekStart))
                            detailRow(icon: "person.crop.circle.badge.checkmark", title: "Supervisor", value: timesheet.supervisor)
                            detailRow(icon: "person.2", title: "Name", value: "\(timesheet.name1) \(timesheet.name2)".trimmingCharacters(in: .whitespacesAndNewlines))
                            detailRow(icon: "clock", title: "Gibson Hours", value: timesheet.gibsonHours)
                            detailRow(icon: "clock.badge", title: "Cable South Hours", value: timesheet.cableSouthHours)
                            detailRow(icon: "sum", title: "Total Hours", value: timesheet.totalHours)
                        }
                        .padding(JTSpacing.lg)
                    }

                    GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
                        VStack(alignment: .leading, spacing: JTSpacing.md) {
                            Text("Daily Totals")
                                .font(JTTypography.headline)
                                .foregroundStyle(JTColors.textPrimary)

                            ForEach(timesheet.dailyTotalHours.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                        .font(JTTypography.subheadline)
                                        .foregroundStyle(JTColors.textSecondary)
                                    Spacer()
                                    Text(value)
                                        .font(JTTypography.subheadline.weight(.semibold))
                                        .foregroundStyle(JTColors.textPrimary)
                                }
                                Divider().overlay(JTColors.glassSoftStroke.opacity(0.5))
                            }
                        }
                        .padding(JTSpacing.lg)
                    }

                    if let pdfURL = timesheet.pdfURL, let url = URL(string: pdfURL) {
                        Button {
                            showPDFViewer = true
                        } label: {
                            Label("View PDF", systemImage: "doc.richtext")
                                .font(JTTypography.button)
                                .foregroundStyle(JTColors.onAccent)
                                .padding(.vertical, JTSpacing.md)
                                .frame(maxWidth: .infinity)
                                .background(JTColors.accent, in: JTShapes.roundedRectangle(cornerRadius: JTShapes.buttonCornerRadius))
                        }
                        .sheet(isPresented: $showPDFViewer) {
                            PDFViewer(url: url)
                        }
                    }
                }
                .padding(JTSpacing.lg)
            }
        }
        .navigationTitle("Timesheet Details")
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
                Text(value.isEmpty ? "—" : value)
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
