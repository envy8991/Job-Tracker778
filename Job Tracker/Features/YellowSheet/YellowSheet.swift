//
//  YellowSheet.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//


import Foundation
import FirebaseFirestore

struct YellowSheet: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var userId: String
    var partnerId: String?
    var weekStart: Date           // The week's start date (Sunday)
    var totalJobs: Int            // Number of jobs in that week
    var pdfURL: String?           // PDF download URL (if available)
    // Add additional fields as needed.
}
