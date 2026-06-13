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


extension Timesheet {
    /// Returns the stable owner for a timesheet. Partnered users share the same owner
    /// by sorting both UIDs, so either partner opens and saves the same weekly document.
    static func canonicalOwnerID(userId: String, partnerId: String?) -> String {
        let ids = canonicalPairIDs(userId: userId, partnerId: partnerId)
        return ids.first ?? userId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the stable partner component for a shared timesheet, or nil for solo timesheets.
    static func canonicalPartnerID(userId: String, partnerId: String?) -> String? {
        let ids = canonicalPairIDs(userId: userId, partnerId: partnerId)
        return ids.count > 1 ? ids[1] : nil
    }

    /// Builds the Firestore document ID for a user's weekly timesheet.
    ///
    /// The partner component is sorted before joining, which makes the document ID
    /// identical for both users in a partnership. Unpartnered users keep the legacy
    /// personal format: `<userId>_<yyyy-MM-dd>`.
    static func documentID(userId: String, partnerId: String?, weekStart: Date) -> String {
        let ids = canonicalPairIDs(userId: userId, partnerId: partnerId)
        let week = weekStartString(from: weekStart)

        guard ids.count > 1 else {
            return "\(ids[0])_\(week)"
        }

        let pairComponent = ids.joined(separator: "_")
        return "\(pairComponent)_\(week)"
    }

    private static func canonicalPairIDs(userId: String, partnerId: String?) -> [String] {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPartnerId = partnerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedPartnerId.isEmpty, trimmedPartnerId != trimmedUserId else { return [trimmedUserId] }
        return [trimmedUserId, trimmedPartnerId].sorted()
    }

    private static func weekStartString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
