//
//  Timesheet.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//

import Foundation
import FirebaseFirestore

struct Timesheet: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var userId: String
    var partnerId: String?
    var weekStart: Date
    var supervisor: String
    var name1: String
    var name2: String
    var gibsonHours: String
    var cableSouthHours: String
    var totalHours: String
    var dailyTotalHours: [String: String]  // keys formatted as "yyyy-MM-dd"
    var pdfURL: String?                    // PDF download URL (if available)
}
