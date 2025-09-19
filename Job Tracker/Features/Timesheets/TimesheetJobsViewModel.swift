//
//  TimesheetJobsViewModel.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/9/25.
//


import SwiftUI
import FirebaseFirestore
import Combine

class TimesheetJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    
    private var listenerRegistration: ListenerRegistration?
    private let db = Firestore.firestore()
    
    init() {
        // Optionally, you can call fetchJobsForWeek() here for an initial load.
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    /// Fetch jobs within the specified date range.
    func fetchJobs(startDate: Date, endDate: Date) {
        listenerRegistration?.remove()
        
        let query = db.collection("jobs")
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
        
        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching timesheet jobs: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            self?.jobs = documents.compactMap { document in
                var job = try? document.data(as: Job.self)
                job?.id = document.documentID
                return job
            }
        }
    }
    
    /// Fetch jobs for the week containing `selectedDate` (using Sunday as the first day).
    func fetchJobsForWeek(selectedDate: Date) {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
            // Adjust end to include jobs until just before midnight on Saturday.
            let adjustedEnd = weekInterval.end.addingTimeInterval(-1)
            fetchJobs(startDate: weekInterval.start, endDate: adjustedEnd)
        }
    }
}