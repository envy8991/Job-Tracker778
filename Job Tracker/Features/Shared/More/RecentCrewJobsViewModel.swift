import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class RecentCrewJobsViewModel: ObservableObject {
    enum CrewRoleFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case underground = "Underground"
        case aerial = "Aerial"
        case can = "CAN"
        case nid = "NID"

        var id: String { rawValue }
    }

    @Published private(set) var jobs: [RecentCrewJob] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    deinit {
        listener?.remove()
    }

    func startListening() {
        guard listener == nil else { return }

        isLoading = true
        errorMessage = nil

        let calendar = Calendar.current
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        let query = db.collection("jobs")
            .whereField("date", isGreaterThanOrEqualTo: fourteenDaysAgo)
            .order(by: "date", descending: true)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                return
            }

            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self.jobs = []
                    self.isLoading = false
                }
                return
            }

            let decoded: [RecentCrewJob] = documents.compactMap { doc in
                do {
                    var job = try doc.data(as: RecentCrewJob.self)
                    job.id = doc.documentID
                    return job
                } catch {
                    #if DEBUG
                    print("[RecentCrewJobs] Failed to decode job: \(error)")
                    #endif
                    return nil
                }
            }
            .filter { $0.status.lowercased() != "pending" }

            DispatchQueue.main.async {
                self.jobs = decoded.sorted { $0.date > $1.date }
                self.isLoading = false
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func groups(for filter: CrewRoleFilter) -> [RecentCrewJobGroup] {
        let filtered: [RecentCrewJob]
        switch filter {
        case .all:
            filtered = jobs
        case .underground, .aerial, .can, .nid:
            filtered = jobs.filter { $0.matches(filter) }
        }

        guard !filtered.isEmpty else { return [] }

        let grouped = Dictionary(grouping: filtered) { $0.groupingKey }

        let mapped: [RecentCrewJobGroup] = grouped.compactMap { key, value in
            let sortedEntries = value.sorted { $0.date > $1.date }
            guard let representative = sortedEntries.first else { return nil }
            return RecentCrewJobGroup(
                id: key,
                title: representative.displayTitle,
                subtitle: representative.subtitleText,
                jobs: sortedEntries
            )
        }

        return mapped.sorted { $0.latestDate > $1.latestDate }
    }
}

struct RecentCrewJobGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let jobs: [RecentCrewJob]

    var latestDate: Date {
        jobs.map(\.date).max() ?? .distantPast
    }

    var primaryRole: String? {
        jobs.first?.displayCrewRole
    }

    var latestStatus: String {
        jobs.first?.status ?? ""
    }

    var latestFormattedDate: String? {
        jobs.first?.formattedDate
    }

    var isMultiEntry: Bool { jobs.count > 1 }

    var entryCount: Int { jobs.count }
}

struct RecentCrewJob: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    let jobNumber: String?
    let address: String
    let status: String
    let date: Date
    let notes: String?
    let createdBy: String?
    let assignedTo: String?
    let hours: Double?
    let materialsUsed: String?
    let canFootage: String?
    let nidFootage: String?
    let photos: [String]?
    let participants: [String]?
    let crewLead: String?
    let crewName: String?

    private let crewRoleRaw: String?
    private let crewRaw: String?
    private let roleRaw: String?
    private let extraRoleValues: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case jobNumber
        case address
        case status
        case date
        case notes
        case createdBy
        case assignedTo
        case hours
        case materialsUsed
        case canFootage
        case nidFootage
        case photos
        case participants
        case crewLead
        case crewName
        case crewRole
        case crew
        case role
        case crewRoleNormalized
        case primaryRole
        case position
        case crewType
        case teamRole
    }

    init(
        id: String = UUID().uuidString,
        jobNumber: String?,
        address: String,
        status: String,
        date: Date,
        notes: String?,
        createdBy: String?,
        assignedTo: String?,
        hours: Double?,
        materialsUsed: String?,
        canFootage: String?,
        nidFootage: String?,
        photos: [String]?,
        participants: [String]?,
        crewLead: String?,
        crewName: String?,
        crewRoleRaw: String?,
        crewRaw: String?,
        roleRaw: String?,
        extraRoleValues: [String]
    ) {
        self.id = id
        self.jobNumber = jobNumber
        self.address = address
        self.status = status
        self.date = date
        self.notes = notes
        self.createdBy = createdBy
        self.assignedTo = assignedTo
        self.hours = hours
        self.materialsUsed = materialsUsed
        self.canFootage = canFootage
        self.nidFootage = nidFootage
        self.photos = photos
        self.participants = participants
        self.crewLead = crewLead
        self.crewName = crewName
        self.crewRoleRaw = crewRoleRaw
        self.crewRaw = crewRaw
        self.roleRaw = roleRaw
        self.extraRoleValues = extraRoleValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.jobNumber = try container.decodeIfPresent(String.self, forKey: .jobNumber)
        self.address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        self.assignedTo = try container.decodeIfPresent(String.self, forKey: .assignedTo)
        self.hours = try container.decodeIfPresent(Double.self, forKey: .hours)
        self.materialsUsed = try container.decodeIfPresent(String.self, forKey: .materialsUsed)
        self.canFootage = try container.decodeIfPresent(String.self, forKey: .canFootage)
        self.nidFootage = try container.decodeIfPresent(String.self, forKey: .nidFootage)
        self.photos = try container.decodeIfPresent([String].self, forKey: .photos)
        self.participants = try container.decodeIfPresent([String].self, forKey: .participants)
        self.crewLead = try container.decodeIfPresent(String.self, forKey: .crewLead)
        self.crewName = try container.decodeIfPresent(String.self, forKey: .crewName)

        self.crewRoleRaw = try container.decodeIfPresent(String.self, forKey: .crewRole)
        self.crewRaw = try container.decodeIfPresent(String.self, forKey: .crew)
        self.roleRaw = try container.decodeIfPresent(String.self, forKey: .role)

        let normalized = try container.decodeIfPresent(String.self, forKey: .crewRoleNormalized)
        let primaryRole = try container.decodeIfPresent(String.self, forKey: .primaryRole)
        let position = try container.decodeIfPresent(String.self, forKey: .position)
        let crewType = try container.decodeIfPresent(String.self, forKey: .crewType)
        let teamRole = try container.decodeIfPresent(String.self, forKey: .teamRole)
        self.extraRoleValues = [normalized, primaryRole, position, crewType, teamRole].compactMap { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(jobNumber, forKey: .jobNumber)
        try container.encode(address, forKey: .address)
        try container.encode(status, forKey: .status)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(assignedTo, forKey: .assignedTo)
        try container.encodeIfPresent(hours, forKey: .hours)
        try container.encodeIfPresent(materialsUsed, forKey: .materialsUsed)
        try container.encodeIfPresent(canFootage, forKey: .canFootage)
        try container.encodeIfPresent(nidFootage, forKey: .nidFootage)
        try container.encodeIfPresent(photos, forKey: .photos)
        try container.encodeIfPresent(participants, forKey: .participants)
        try container.encodeIfPresent(crewLead, forKey: .crewLead)
        try container.encodeIfPresent(crewName, forKey: .crewName)
        try container.encodeIfPresent(crewRoleRaw, forKey: .crewRole)
        try container.encodeIfPresent(crewRaw, forKey: .crew)
        try container.encodeIfPresent(roleRaw, forKey: .role)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecentCrewJob, rhs: RecentCrewJob) -> Bool {
        lhs.id == rhs.id
    }
}

extension RecentCrewJob {
    private var rawRoleCandidates: [String] {
        var values: [String] = []
        for candidate in [crewRoleRaw, crewRaw, roleRaw] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                values.append(trimmed)
            }
        }
        values.append(contentsOf: extraRoleValues)
        return values
    }

    var normalizedCrewRole: String? {
        for candidate in rawRoleCandidates {
            if let normalized = RecentCrewJob.normalizeRole(candidate) {
                return normalized
            }
        }
        return nil
    }

    var displayCrewRole: String? {
        normalizedCrewRole ?? rawRoleCandidates.first
    }

    private static func normalizeRole(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.contains("underground") || lower == "ug" || lower.contains("ug crew") || lower.contains("u/g") {
            return RecentCrewJobsViewModel.CrewRoleFilter.underground.rawValue
        }
        if lower.contains("aerial") || lower.contains("ariel") {
            return RecentCrewJobsViewModel.CrewRoleFilter.aerial.rawValue
        }
        if lower.contains("can") {
            return RecentCrewJobsViewModel.CrewRoleFilter.can.rawValue
        }
        if lower.contains("nid") {
            return RecentCrewJobsViewModel.CrewRoleFilter.nid.rawValue
        }
        return nil
    }

    func matches(_ filter: RecentCrewJobsViewModel.CrewRoleFilter) -> Bool {
        guard filter != .all else { return true }
        guard let normalized = normalizedCrewRole else { return false }
        return normalized.caseInsensitiveCompare(filter.rawValue) == .orderedSame
    }

    var trimmedJobNumber: String? {
        guard let jobNumber = jobNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !jobNumber.isEmpty else { return nil }
        return jobNumber
    }

    var shortAddress: String {
        if let line = address.split(whereSeparator: { $0 == "\n" || $0 == "," }).first {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return address
    }

    var displayTitle: String {
        trimmedJobNumber ?? shortAddress
    }

    var subtitleText: String {
        if trimmedJobNumber != nil {
            return shortAddress
        }
        return CrewJobDateFormatter.shared.string(from: date)
    }

    private var normalizedAddressKey: String {
        address.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    var groupingKey: String {
        if let number = trimmedJobNumber?.uppercased() {
            return "job-number::\(number)"
        }
        return "address::\(normalizedAddressKey)"
    }

    var formattedDate: String {
        CrewJobDateFormatter.shared.string(from: date)
    }
}

private final class CrewJobDateFormatter {
    static let shared = CrewJobDateFormatter()
    private let formatter: DateFormatter

    private init() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .current
        self.formatter = formatter
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
