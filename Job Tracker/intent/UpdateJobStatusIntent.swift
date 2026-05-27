//
//  UpdateJobStatusIntent.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//

// UpdateJobStatusIntent.swift
import AppIntents
import Foundation
import CoreLocation

@available(iOS 16.0, *)
enum JobStatusIntentEnum: String, AppEnum {
    case pending = "Pending"
    case needsAriel = "Needs Ariel"
    case needsUnderground = "Needs Underground"
    case needsNid = "Needs Nid"
    case needsCan = "Needs Can"
    case done = "Done"
    case talkToRick = "Talk to Rick"
    case custom = "Custom"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Job Status"

    static var caseDisplayRepresentations: [JobStatusIntentEnum: DisplayRepresentation] = [
        .pending: "Pending",
        .needsAriel: "Needs Ariel",
        .needsUnderground: "Needs Underground",
        .needsNid: "Needs Nid",
        .needsCan: "Needs Can",
        .done: "Done",
        .talkToRick: "Talk to Rick",
        .custom: "Custom"
    ]
}

@available(iOS 16.0, *)
struct UpdateJobStatusIntent: AppIntent {
    static var openAppWhenRun: Bool = false

    static var title: LocalizedStringResource = "Update Job Status"
    static var description = IntentDescription("Updates a job's status by address or job number.")

    @Parameter(title: "Address or Job #", requestValueDialog: "Which job?")
    var jobQuery: String

    @Parameter(title: "New Status")
    var status: JobStatusIntentEnum

    @Parameter(title: "Custom Status (if chosen)", requestValueDialog: "What custom status?")
    var customStatus: String?

    static var parameterSummary: some ParameterSummary {
        When(\UpdateJobStatusIntent.$status, .equalTo, .custom) {
            Summary("Set \(\UpdateJobStatusIntent.$jobQuery) to \(\UpdateJobStatusIntent.$customStatus)")
        } otherwise: {
            Summary("Set \(\UpdateJobStatusIntent.$jobQuery) to \(\UpdateJobStatusIntent.$status)")
        }
    }

    func perform() async throws -> some ProvidesDialog {
        let jobs = try await FirebaseService.shared.fetchJobsAsync(for: Date())

        // Normalize helpers
        func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let q = norm(jobQuery)

        // Only consider jobs for TODAY (already fetched). Require a match; no arbitrary fallback.
        // 1) Exact job # or exact address
        let exactMatches = jobs.filter { norm($0.jobNumber) == q || norm($0.address) == q }
        // 2) If no exact, allow contains on job # or address
        let containsMatches = jobs.filter { !q.isEmpty && (norm($0.jobNumber).contains(q) || norm($0.address).contains(q)) }

        let target = (exactMatches.sorted { $0.date < $1.date }.first)
                  ?? (containsMatches.sorted { $0.date < $1.date }.first)

        guard let target = target else {
            return .result(dialog: IntentDialog("I couldn't find a job today matching ‘\(jobQuery)’."))
        }

        // Resolve final status value
        let finalStatus: String
        if status == .custom {
            let trimmed = (customStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .result(dialog: IntentDialog("Please provide a custom status."))
            }
            finalStatus = trimmed
        } else {
            finalStatus = status.rawValue
        }

        do {
            try await FirebaseService.shared.updateJobStatusAsync(jobId: target.id, newStatus: finalStatus)
            return .result(dialog: IntentDialog("Updated \(shortAddress(target.address)) to \(finalStatus)."))
        } catch {
            return .result(dialog: IntentDialog("Couldn't update: \(error.localizedDescription)"))
        }
    }

    private func shortAddress(_ full: String) -> String {
        if let comma = full.firstIndex(of: ",") { return String(full[..<comma]) }
        return full
    }
}
