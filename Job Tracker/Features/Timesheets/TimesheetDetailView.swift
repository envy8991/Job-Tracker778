import SwiftUI
import PDFKit

struct TimesheetDetailView: View {
    let timesheet: Timesheet
    @State private var showPDFViewer = false
    
    var body: some View {
        ZStack {
            // Background gradient.
            JTGradients.background(stops: 4)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Week Starting: \(formattedDate(timesheet.weekStart))")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Supervisor: \(timesheet.supervisor)")
                        .foregroundColor(.white)
                    Text("Name: \(timesheet.name1) \(timesheet.name2)")
                        .foregroundColor(.white)
                    Text("Gibson Hours: \(timesheet.gibsonHours)")
                        .foregroundColor(.white)
                    Text("Cable South Hours: \(timesheet.cableSouthHours)")
                        .foregroundColor(.white)
                    Text("Total Hours: \(timesheet.totalHours)")
                        .foregroundColor(.white)
                    
                    Divider()
                        .background(Color.white)
                    
                    Text("Daily Totals:")
                        .font(.headline)
                        .foregroundColor(.white)
                    ForEach(timesheet.dailyTotalHours.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text("\(key): \(value)")
                            .foregroundColor(.white)
                    }
                    
                    if let pdfURL = timesheet.pdfURL, let url = URL(string: pdfURL) {
                        Button("View PDF") {
                            showPDFViewer = true
                        }
                        .padding()
                        .background(JTColors.accent)
                        .foregroundColor(JTColors.onAccent)
                        .cornerRadius(8)
                        .sheet(isPresented: $showPDFViewer) {
                            PDFViewer(url: url)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Timesheet Details")
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
