import SwiftUI

struct YellowSheetDetailView: View {
    let yellowSheet: YellowSheet
    
    var body: some View {
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
            
            VStack(spacing: 20) {
                Text("Yellow Sheet Detail")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top)
                
                Text("Week Starting: \(formattedDate(yellowSheet.weekStart))")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Total Jobs: \(yellowSheet.totalJobs)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                if let pdfURLString = yellowSheet.pdfURL,
                   let url = URL(string: pdfURLString),
                   !pdfURLString.isEmpty {
                    NavigationLink(destination: PDFViewer(url: url)) {
                        Text("View PDF")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                } else {
                    Text("No PDF Available")
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Yellow Sheet Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
