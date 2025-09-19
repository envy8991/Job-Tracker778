import SwiftUI

struct DayTimesheetBox: View {
    let date: Date
    let jobs: [Job]
    // Editable total hours value is provided via a binding.
    @Binding var totalHoursEditable: String
    // Optional callback when a job is tapped.
    var onJobTap: ((Job) -> Void)? = nil

    // MARK: - Custom Initializer
    init(date: Date, jobs: [Job], totalHoursEditable: Binding<String>, onJobTap: ((Job) -> Void)? = nil) {
        self.date = date
        self.jobs = jobs
        self._totalHoursEditable = totalHoursEditable
        self.onJobTap = onJobTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateLabel)
                .font(.headline)
            
            if jobs.isEmpty {
                Text("No jobs")
                    .foregroundColor(.gray)
            } else {
                headingView
                ForEach(jobs, id: \.id) { job in
                    jobRow(job)
                }
            }
            
            totalHoursView
        }
        .padding(8)
        .frame(minHeight: 130)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
    
    // MARK: - Subviews

    private var headingView: some View {
        HStack {
            Text("Job #")
                .frame(width: 60, alignment: .leading)
            Text("Hours")
                .frame(width: 50, alignment: .leading)
            Spacer()
        }
        .font(.subheadline)
        .foregroundColor(.blue)
    }
    
    private func jobRow(_ job: Job) -> some View {
        HStack {
            Text(job.jobNumber ?? "")
                .frame(width: 60, alignment: .leading)
            Text(String(format: "%.1f", job.hours))
                .frame(width: 50, alignment: .leading)
            // Display only the house number and street name.
            Text(houseNumberAndStreet(from: job.shortAddress))
            Spacer()
        }
        .font(.caption)
        .contentShape(Rectangle())
        .onTapGesture {
            onJobTap?(job)
        }
    }
    
    private var totalHoursView: some View {
        HStack {
            Text("Total Hours:")
                .font(.caption)
            TextField("Enter total hours", text: $totalHoursEditable)
                .font(.caption)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: 80)
        }
    }
    
    // MARK: - Helper

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMM d"
        return formatter.string(from: date)
    }
    // MARK: - Address Helper
    /// Returns house number + street name (up to the first street‑type word or comma).
    private func houseNumberAndStreet(from fullAddress: String) -> String {
        // 1. If there is a comma, everything before it is already just street.
        if let comma = fullAddress.firstIndex(of: ",") {
            return String(fullAddress[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        
        // 2. Otherwise, keep tokens until we hit a known street suffix or run out.
        let suffixes: Set<String> = [
            "st", "street", "rd", "road", "ave", "avenue",
            "blvd", "circle", "cir", "ln", "lane", "dr", "drive",
            "ct", "court", "pkwy", "pl", "place", "ter", "terrace"
        ]
        
        var resultTokens: [Substring] = []
        for token in fullAddress.split(separator: " ") {
            resultTokens.append(token)
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",.")).lowercased()
            if suffixes.contains(cleaned) {
                break   // stop once we've captured the full street name
            }
        }
        return resultTokens.joined(separator: " ")
    }
}
