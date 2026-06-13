import SwiftUI

struct PastYellowSheetsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var yellowSheetsVM = UserYellowSheetsViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                JTGradients.background(stops: 4)
                    .ignoresSafeArea()

                List {
                    ForEach(yellowSheetsVM.yellowSheets) { sheet in
                        NavigationLink(destination: YellowSheetDetailView(yellowSheet: sheet)) {
                            PastYellowSheetRow(sheet: sheet)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteSheet)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Past Yellow Sheets")
            .navigationBarTitleDisplayMode(.inline)
            .jtNavigationBarStyle()
            .onAppear {
                if let user = authViewModel.currentUser {
                    yellowSheetsVM.fetchYellowSheets(for: user.id)
                }
            }
        }
    }

    private func deleteSheet(at offsets: IndexSet) {
        offsets.forEach { index in
            let sheet = yellowSheetsVM.yellowSheets[index]
            if let id = sheet.id {
                yellowSheetsVM.deleteYellowSheet(documentID: id)
            }
        }
        yellowSheetsVM.yellowSheets.remove(atOffsets: offsets)
    }
}

private struct PastYellowSheetRow: View {
    let sheet: YellowSheet

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week Starting: \(formattedDate(sheet.weekStart))")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JTColors.textMuted)
            }

            Text("Total Jobs: \(sheet.totalJobs)")
                .font(JTTypography.subheadline)
                .foregroundStyle(JTColors.textSecondary)

            Label(sheet.pdfURL?.isEmpty == false ? "PDF Created" : "No PDF Available",
                  systemImage: sheet.pdfURL?.isEmpty == false ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(JTTypography.caption)
                .foregroundStyle(sheet.pdfURL?.isEmpty == false ? JTColors.success : JTColors.error)
        }
        .padding(.vertical, JTSpacing.sm)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
