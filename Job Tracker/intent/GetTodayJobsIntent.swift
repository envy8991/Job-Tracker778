//
//  GetTodayJobsIntent.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//


// GetTodayJobsIntent.swift
import AppIntents
import Foundation

@available(iOS 16.0, *)
struct GetTodayJobsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Jobs"
    static var description = IntentDescription("Speaks a quick list of today's jobs.")

    func perform() async throws -> some ProvidesDialog {
        let today = Date()
        let jobs = try await FirebaseService.shared.fetchJobsAsync(for: today)

        let visible = jobs.filter { $0.status.lowercased() != "pending" }
        guard !visible.isEmpty else {
            return .result(dialog: IntentDialog("You have no non-pending jobs today."))
        }

        // Keep dialog short for Siri
        let firstFew = visible.prefix(5).map { job in
            let addr = job.address.components(separatedBy: ",").first ?? job.address
            return "\(addr) – \(job.status)"
        }.joined(separator: "; ")

        return .result(dialog: IntentDialog("Jobs today: \(firstFew)."))
    }
}
