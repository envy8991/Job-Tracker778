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

// MARK: - Search index support

protocol JobSearchMatchable {
    var id: String { get }
    var address: String { get }
    var jobNumber: String? { get }
    var status: String { get }
    var createdBy: String? { get }
    var date: Date { get }
    var notes: String? { get }
    var assignments: String? { get }
    var materialsUsed: String? { get }
    var nidFootage: String? { get }
    var canFootage: String? { get }
}

extension Job: JobSearchMatchable {}

struct JobSearchIndexEntry: Identifiable, Codable, Hashable, Sendable, JobSearchMatchable {
    var id: String
    var address: String
    var jobNumber: String?
    var status: String
    var createdBy: String?
    var date: Date
    var notes: String?
    var assignments: String?
    var materialsUsed: String?
    var nidFootage: String?
    var canFootage: String?

    init(
        id: String,
        address: String,
        jobNumber: String? = nil,
        status: String,
        createdBy: String? = nil,
        date: Date,
        notes: String? = nil,
        assignments: String? = nil,
        materialsUsed: String? = nil,
        nidFootage: String? = nil,
        canFootage: String? = nil
    ) {
        self.id = id
        self.address = address
        self.jobNumber = jobNumber
        self.status = status
        self.createdBy = createdBy
        self.date = date
        self.notes = notes
        self.assignments = assignments
        self.materialsUsed = materialsUsed
        self.nidFootage = nidFootage
        self.canFootage = canFootage
    }

    init(job: Job) {
        self.init(
            id: job.id,
            address: job.address,
            jobNumber: job.jobNumber,
            status: job.status,
            createdBy: job.createdBy,
            date: job.date,
            notes: job.notes,
            assignments: job.assignments,
            materialsUsed: job.materialsUsed,
            nidFootage: job.nidFootage,
            canFootage: job.canFootage
        )
    }

    func makePartialJob() -> Job {
        var job = Job(
            id: id,
            address: address,
            date: date,
            status: status,
            createdBy: createdBy,
            notes: notes ?? "",
            jobNumber: jobNumber,
            assignments: assignments,
            materialsUsed: materialsUsed,
            photos: [],
            participants: nil,
            hours: 0.0,
            nidFootage: nidFootage,
            canFootage: canFootage
        )
        job.notes = notes
        job.assignments = assignments
        job.materialsUsed = materialsUsed
        job.nidFootage = nidFootage
        job.canFootage = canFootage
        job.jobNumber = jobNumber
        job.createdBy = createdBy
        return job
    }
}
