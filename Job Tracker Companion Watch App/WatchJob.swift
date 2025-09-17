//
//  WatchJob.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//


// Watch App target → WatchJob.swift

import Foundation

struct WatchJob: Identifiable, Hashable {
    let id: String
    let address: String
    let date: Date
    var jobNumber: String?
    var status: String?
}
