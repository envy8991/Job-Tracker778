import SwiftUI

struct JobEditView: View {
    @Binding var job: Job
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @Environment(\.dismiss) var dismiss

    // Local state for editing.
    @State private var jobNumber: String = ""
    @State private var address: String = ""
    @State private var hours: String = ""

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
                
                Form {
                    Section(header: Text("Job Details")) {
                        TextField("Job Number", text: $jobNumber)
                        TextField("Address", text: $address)
                        TextField("Hours", text: $hours)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Edit Job")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        job.jobNumber = jobNumber.isEmpty ? nil : jobNumber
                        job.address = address
                        job.hours = Double(hours) ?? 0.0
                        jobsViewModel.updateJob(job)
                        dismiss()
                    }
                }
            }
            .onAppear {
                self.jobNumber = job.jobNumber ?? ""
                self.address = job.address
                self.hours = String(format: "%.1f", job.hours)
            }
        }
    }
}
