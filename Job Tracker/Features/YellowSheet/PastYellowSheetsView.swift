import SwiftUI

struct PastYellowSheetsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var yellowSheetsVM = UserYellowSheetsViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient.
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.17254902, green: 0.24313726, blue: 0.3137255),
                        Color(red: 0.29803923, green: 0.6313726, blue: 0.6862745)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                List {
                    ForEach(yellowSheetsVM.yellowSheets) { sheet in
                        NavigationLink(destination: YellowSheetDetailView(yellowSheet: sheet)) {
                            VStack(alignment: .leading) {
                                Text("Week Starting: \(formattedDate(sheet.weekStart))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Total Jobs: \(sheet.totalJobs)")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                if let pdfURL = sheet.pdfURL, !pdfURL.isEmpty {
                                    Text("PDF Created")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("No PDF Available")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSheet)
                }
                .listStyle(GroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Past Yellow Sheets")
            .onAppear {
                if let user = authViewModel.currentUser {
                    yellowSheetsVM.fetchYellowSheets(for: user.id)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
