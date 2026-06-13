//
//  WatchJobsViewModel.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//


// Watch App target → WatchJobsViewModel.swift

import Foundation
import Combine

final class WatchJobsViewModel: ObservableObject {
    @Published var todaysJobs: [WatchJob] = []

    private var cancellables = Set<AnyCancellable>()

    func bind(to bridge: WatchBridge) {
        bridge.activate()
        bridge.$latestSnapshot
            .map { jobs in
                let cal = Calendar.current
                return jobs.filter { job in
                    // Status must be Pending
                    let statusOK: Bool = {
                        guard let s = job.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
                        return s == "pending"
                    }()
                    // Date must be today (local calendar)
                    let dateOK = cal.isDateInToday(job.date)
                    return statusOK && dateOK
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.todaysJobs, on: self)
            .store(in: &cancellables)
    }

    func updateStatus(job: WatchJob, to newStatus: String, via bridge: WatchBridge) {
        bridge.sendStatusUpdate(jobId: job.id, status: newStatus)
        // Optimistic local update for UI responsiveness
        if let idx = todaysJobs.firstIndex(where: { $0.id == job.id }) {
            todaysJobs[idx].status = newStatus
        }
    }
}
