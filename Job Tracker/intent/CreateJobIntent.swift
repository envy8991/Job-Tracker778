//
//  CreateJobIntent.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 3/22/25.
//


//
//  CreateJobIntent.swift
//  Job Tracking Cable South
//
//  Created by Quinton Thompson on 3/22/25.
//

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct CreateJobIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Job"
    static var description =
        IntentDescription("Creates a new job in the Job Tracking app .")
    static var openAppWhenRun: Bool = false
    
    // The user can fill these in by voice or typed prompt in Shortcuts:
    @Parameter(title: "Address", default: "123 Main St, Sample Town")
    var address: String
    
    @Parameter(title: "Status", default: "Pending")
    var status: String
    
    @Parameter(title: "Scheduled Date")
    var date: Date
    
    // The perform method is called when Siri or Shortcuts executes this intent.
    func perform() async throws -> some ProvidesDialog {
        let allowed = ["Pending","Needs Ariel","Needs Underground","Needs Nid","Needs Can","Done","Talk to Rick"]
        let chosen = status.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = allowed.first { $0.lowercased() == chosen.lowercased() } ?? chosen
        
        // Construct a basic Job model
        let newJob = Job(
            address: address,
            date: date,
            status: normalized
        )
        
        // Use the async createJob function in FirebaseService
        do {
            try await FirebaseService.shared.createJobAsync(newJob)
        } catch {
            // If there's an error, we can return a user-friendly message:
            return .result(dialog: IntentDialog("Failed to create job: \(error.localizedDescription)"))
        }
        
        // Provide a success message for Siri / Shortcuts
        return .result(dialog: IntentDialog("Job created successfully for \(address)."))
    }
}
