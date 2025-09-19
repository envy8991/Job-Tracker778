import SwiftUI

struct DashboardDatePickerSheet: View {
    @Binding var selectedDate: Date
    let onSelection: (Date) -> Void

    var body: some View {
        VStack {
            DatePicker(
                "Select a date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .padding()
        .onChange(of: selectedDate) { newValue in
            onSelection(newValue)
        }
    }
}

struct DashboardDailyShareSheet: View {
    let items: [Any]
    let subject: String

    var body: some View {
        ActivityView(activityItems: items, subject: subject)
    }
}

struct DashboardJobShareSheet: View {
    let url: URL
    let subject: String

    var body: some View {
        ActivityView(activityItems: [url], subject: subject)
    }
}

private struct DashboardDatePickerSheetPreviewContainer: View {
    @State private var date = Date()

    var body: some View {
        DashboardDatePickerSheet(selectedDate: $date) { _ in }
            .presentationDetents([.medium])
    }
}

#Preview("Date Picker Sheet") {
    DashboardDatePickerSheetPreviewContainer()
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}

#Preview("Daily Share Sheet") {
    DashboardDailyShareSheet(items: [NSString(string: "Jobs for May 1, 2025" )], subject: "Jobs for May 1, 2025")
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (4th generation)"))
}

#Preview("Job Share Sheet") {
    DashboardJobShareSheet(url: URL(string: "https://example.com/job")!, subject: "Job link for May 1, 2025")
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
}
