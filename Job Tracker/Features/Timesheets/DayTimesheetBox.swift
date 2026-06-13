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
        VStack(alignment: .leading, spacing: JTSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateLabel)
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                Spacer()
                Text("\(jobs.count) job\(jobs.count == 1 ? "" : "s")")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }

            if jobs.isEmpty {
                emptyState
            } else {
                VStack(spacing: JTSpacing.sm) {
                    ForEach(jobs, id: \.id) { job in
                        jobRow(job)
                    }
                }
            }

            totalHoursView
        }
        .padding(JTSpacing.lg)
        .frame(minHeight: 130)
    }

    // MARK: - Subviews

    private var emptyState: some View {
        HStack(spacing: JTSpacing.sm) {
            Image(systemName: "tray")
            Text("No jobs")
        }
        .font(JTTypography.subheadline)
        .foregroundStyle(JTColors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, JTSpacing.md)
    }

    private func jobRow(_ job: Job) -> some View {
        Button {
            onJobTap?(job)
        } label: {
            HStack(spacing: JTSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: JTSpacing.xs) {
                        if let jobNumber = job.jobNumber, !jobNumber.isEmpty {
                            Text("#\(jobNumber)")
                                .font(JTTypography.captionEmphasized)
                                .foregroundStyle(JTColors.textPrimary)
                        }

                        Text(job.displayStatus)
                            .font(JTTypography.caption)
                            .foregroundStyle(universalStatusColor(job.status))
                            .padding(.horizontal, JTSpacing.sm)
                            .padding(.vertical, 2)
                            .background(universalStatusColor(job.status).opacity(0.16), in: Capsule())
                    }

                    Text(houseNumberAndStreet(from: job.shortAddress))
                        .font(JTTypography.subheadline)
                        .foregroundStyle(JTColors.textPrimary)
                        .lineLimit(2)
                }

                Spacer(minLength: JTSpacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", job.hours))
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)
                    Text("hrs")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JTColors.textMuted)
            }
            .padding(JTSpacing.md)
            .jtGlassBackground(cornerRadius: JTShapes.smallCardCornerRadius, strokeColor: JTColors.glassSoftStroke)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the full job details")
    }

    private var totalHoursView: some View {
        HStack(spacing: JTSpacing.sm) {
            Label("Total Hours", systemImage: "clock")
                .font(JTTypography.captionEmphasized)
                .foregroundStyle(JTColors.textSecondary)
            Spacer()
            TextField("0.0", text: $totalHoursEditable)
                .font(JTTypography.captionEmphasized)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .padding(.vertical, JTSpacing.xs)
                .padding(.horizontal, JTSpacing.sm)
                .frame(maxWidth: 84)
                .jtGlassBackground(cornerRadius: JTShapes.chipCornerRadius, strokeColor: JTColors.glassSoftStroke)
                .foregroundStyle(JTColors.textPrimary)
        }
        .padding(.top, JTSpacing.xs)
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
