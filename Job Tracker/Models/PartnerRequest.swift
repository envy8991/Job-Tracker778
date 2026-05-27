//
//  PartnerRequest.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//


import Foundation

/// A request from one user to another to form a two-person partnership.
/// Documents live in the `partnerRequests` collection.
struct PartnerRequest: Identifiable, Hashable {
    var id: String?            // Firestore document ID
    let fromUid: String
    let toUid: String
    var status: String         // "pending", "accepted", "declined", or "cancelled"
    let createdAt: Date
}