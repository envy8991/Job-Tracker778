import Foundation

struct Job: Identifiable, Codable {
    var id: String                  // Firestore doc ID or UUID
    var address: String             // Full physical job address
    var date: Date                  // Date for scheduling/tracking
    var status: String              // e.g. "Pending", "Needs Ariel", "Done", etc.
    var assignedTo: String?         // userID of whoever currently owns the job (nil = unclaimed)
    var createdBy: String?          // userID of whoever created the job
    var notes: String?              // Additional text notes
    var jobNumber: String?          // A job number for timesheet or reference
    var assignments: String?        // e.g. "12.3.2" or "123.2.4" – free-form dotted assignment code
    var materialsUsed: String?      // e.g. "Preforms, Weatherhead, Rams Head, 1 Nid Box and 1 Jumper", etc.
    var photos: [String]            // Array of image URLs
    var participants: [String]?     // userIDs who can see this job (visibility list)
    // Geographic coordinates (optional; filled when geocoded or user-entered)
    var latitude: Double?
    var longitude: Double?
    var hours: Double               // Hours spent on this job
    
    // New optional properties for footages:
    var nidFootage: String?
    var canFootage: String?
    
    // Default initializer updated to include new fields.
    init(
        id: String = UUID().uuidString,
        address: String,
        date: Date,
        status: String,
        assignedTo: String? = nil,
        createdBy: String? = nil,
        notes: String = "",
        jobNumber: String? = nil,
        assignments: String? = nil,
        materialsUsed: String? = nil,
        photos: [String] = [],
        participants: [String]? = nil,
        hours: Double = 0.0,
        nidFootage: String? = nil,
        canFootage: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.address = address
        self.date = date
        self.status = status
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.notes = notes
        self.jobNumber = jobNumber
        self.assignments = assignments
        self.materialsUsed = materialsUsed
        self.photos = photos
        self.participants = participants
        self.hours = hours
        self.nidFootage = nidFootage
        self.canFootage = canFootage
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension Job: Hashable {
    static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Job {
    /// Returns the first component of the address (before any commas) as a "short address."
    var shortAddress: String {
        let components = address.split(separator: ",")
        guard let firstComponent = components.first else { return address }
        return firstComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import CoreLocation
extension Job {
    /// Convenience CLLocation for distance calculations (returns nil if coords missing)
    var clLocation: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
}
