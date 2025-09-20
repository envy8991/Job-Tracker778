import SwiftUI
import Combine

@MainActor
final class JobSearchViewModel: ObservableObject {
    struct Result: Identifiable, Hashable, Equatable {
        struct Address: Hashable, Equatable {
            let primary: String
            let secondary: String?
        }

        struct Creator: Hashable, Equatable {
            let id: String
            let name: String
            let role: String?
        }

        struct DetailSnippet: Hashable, Equatable {
            let title: String
            let value: String
        }

        let id: String
        let address: Address
        let jobNumber: String?
        let status: String
        let date: Date
        let creator: Creator?
        let snippet: DetailSnippet?
        let isOwnedByCurrentUser: Bool
    }

    struct QuickFilter: Identifiable, Hashable, Equatable {
        enum Kind: Hashable {
            case status
            case creator
        }

        let kind: Kind
        let value: String
        let count: Int

        var id: String {
            "\(kind)-\(value.lowercased())"
        }

        var iconSystemName: String {
            switch kind {
            case .status: return "tag"
            case .creator: return "person.2"
            }
        }

        var title: String { value }

        var subtitle: String {
            "\(count) job\(count == 1 ? "" : "s")"
        }

        var suggestedQuery: String { value }
    }

    enum ViewState: Equatable {
        case idle(recents: [Result])
        case empty(query: String)
        case results(query: String, items: [Result])
    }

    @Published var query: String = ""
    @Published private(set) var viewState: ViewState = .idle(recents: [])
    @Published private(set) var resultsCount: Int = 0
    @Published private(set) var quickFilters: [QuickFilter] = []

    private let jobsViewModel: JobsViewModel
    private let usersViewModel: UsersViewModel

    private var cancellables: Set<AnyCancellable> = []
    private var jobLookup: [String: Job] = [:]
    private var resultLookup: [String: Result] = [:]
    private var searchTask: Task<Void, Never>? = nil

    init(jobsViewModel: JobsViewModel, usersViewModel: UsersViewModel) {
        self.jobsViewModel = jobsViewModel
        self.usersViewModel = usersViewModel

        configureSubscriptions()
        rebuildResults()
    }

    func job(for id: String) -> Job? {
        if let cached = jobLookup[id] {
            return cached
        }

        if let job = jobsViewModel.jobs.first(where: { $0.id == id }) {
            jobLookup[id] = job
            return job
        }

        if let entry = jobsViewModel.searchJobs.first(where: { $0.id == id }) {
            let partial = entry.makePartialJob()
            jobLookup[id] = partial
            return partial
        }

        return nil
    }

    func result(for id: String) -> Result? {
        resultLookup[id]
    }

    private func configureSubscriptions() {
        $query
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.rebuildResults()
            }
            .store(in: &cancellables)

        jobsViewModel.$searchJobs
            .sink { [weak self] _ in
                self?.rebuildResults()
            }
            .store(in: &cancellables)

        jobsViewModel.$jobs
            .sink { [weak self] _ in
                self?.rebuildResults()
            }
            .store(in: &cancellables)

        usersViewModel.$usersDict
            .sink { [weak self] _ in
                self?.rebuildResults()
            }
            .store(in: &cancellables)
    }

    private func rebuildResults() {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = Self.normalizedTokens(from: trimmedQuery)
        let users = usersViewModel.usersDict
        let ownedJobs = jobsViewModel.jobs
        let searchEntries = jobsViewModel.searchJobs

        let indexEntries: [JobSearchIndexEntry]
        if searchEntries.isEmpty {
            indexEntries = ownedJobs.map(JobSearchIndexEntry.init(job:))
        } else {
            indexEntries = searchEntries
        }

        quickFilters = Self.buildQuickFilters(from: indexEntries, users: users)

        let ownedIDs = Set(ownedJobs.map { $0.id })
        let baseLookup = Dictionary(uniqueKeysWithValues: ownedJobs.map { ($0.id, $0) })

        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            if Task.isCancelled { return }

            let searchOutcome = Self.performSearch(
                tokens: tokens,
                trimmedQuery: trimmedQuery,
                indexEntries: indexEntries,
                users: users,
                ownedIDs: ownedIDs,
                baseLookup: baseLookup
            )

            if Task.isCancelled { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.jobLookup = searchOutcome.lookup
                self.resultLookup = searchOutcome.resultLookup
                self.viewState = searchOutcome.state
                self.resultsCount = searchOutcome.count
            }
        }
    }

    private static func performSearch(
        tokens: [String],
        trimmedQuery: String,
        indexEntries: [JobSearchIndexEntry],
        users: [String: AppUser],
        ownedIDs: Set<String>,
        baseLookup: [String: Job]
    ) -> (results: [Result], resultLookup: [String: Result], lookup: [String: Job], state: ViewState, count: Int) {
        var lookup = baseLookup

        if tokens.isEmpty {
            let sortedEntries = indexEntries.sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.address.localizedCaseInsensitiveCompare(rhs.address) == .orderedAscending
            }

            let limitedEntries = Array(sortedEntries.prefix(12))
            let results = buildResults(from: limitedEntries, users: users, ownedIDs: ownedIDs, tokens: tokens)
            for entry in limitedEntries where lookup[entry.id] == nil {
                lookup[entry.id] = entry.makePartialJob()
            }
            let lookupResults = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
            return (results, lookupResults, lookup, .idle(recents: results), 0)
        }

        let filteredEntries = indexEntries.filter { entry in
            let creator = entry.createdBy.flatMap { users[$0] }
            return matches(job: entry, tokens: tokens, creator: creator)
        }

        let orderedEntries = filteredEntries.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            return lhs.address.localizedCaseInsensitiveCompare(rhs.address) == .orderedAscending
        }

        let results = buildResults(from: orderedEntries, users: users, ownedIDs: ownedIDs, tokens: tokens)
        for entry in orderedEntries where lookup[entry.id] == nil {
            lookup[entry.id] = entry.makePartialJob()
        }
        let lookupResults = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })

        if results.isEmpty {
            return (results, lookupResults, lookup, .empty(query: trimmedQuery), 0)
        }

        return (results, lookupResults, lookup, .results(query: trimmedQuery, items: results), results.count)
    }

    private static func buildResults(
        from entries: [JobSearchIndexEntry],
        users: [String: AppUser],
        ownedIDs: Set<String>,
        tokens: [String]
    ) -> [Result] {
        entries.map { entry in
            let creatorUser = entry.createdBy.flatMap { users[$0] }
            return buildResult(entry: entry, creator: creatorUser, ownedIDs: ownedIDs, tokens: tokens)
        }
    }

    private static func buildResult(
        entry: JobSearchIndexEntry,
        creator: AppUser?,
        ownedIDs: Set<String>,
        tokens: [String]
    ) -> Result {
        let addressComponents = entry.address
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let primaryAddress = addressComponents.first ?? entry.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondaryAddress = addressComponents.dropFirst().joined(separator: ", ")

        let creatorModel: Result.Creator?
        if let creator {
            let name = displayName(for: creator)
            let role = displayValue(creator.normalizedPosition)
            creatorModel = Result.Creator(id: creator.id, name: name, role: role)
        } else {
            creatorModel = nil
        }

        let snippet = snippet(for: entry, tokens: tokens)

        return Result(
            id: entry.id,
            address: .init(
                primary: primaryAddress.isEmpty ? entry.address : primaryAddress,
                secondary: secondaryAddress.isEmpty ? nil : secondaryAddress
            ),
            jobNumber: displayValue(entry.jobNumber),
            status: entry.status.trimmingCharacters(in: .whitespacesAndNewlines),
            date: entry.date,
            creator: creatorModel,
            snippet: snippet,
            isOwnedByCurrentUser: ownedIDs.contains(entry.id)
        )
    }

    private static func snippet(for entry: JobSearchIndexEntry, tokens: [String]) -> Result.DetailSnippet? {
        let candidates: [(String, String?)] = [
            ("Notes", entry.notes),
            ("Materials", entry.materialsUsed),
            ("Assignments", entry.assignments),
            ("NID Footage", entry.nidFootage),
            ("CAN Footage", entry.canFootage)
        ]

        for (title, rawValue) in candidates {
            guard let displayText = displayValue(rawValue) else { continue }
            if tokens.isEmpty {
                return Result.DetailSnippet(title: title, value: displayText)
            }

            let normalized = displayText.lowercased()
            if tokens.contains(where: { normalized.contains($0) }) {
                return Result.DetailSnippet(title: title, value: displayText)
            }
        }

        return nil
    }

    private static func matches(job: JobSearchMatchable, tokens: [String], creator: AppUser?) -> Bool {
        guard !tokens.isEmpty else { return true }

        var haystackParts: [String] = []

        if let normalized = normalizedNonEmpty(job.address) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.jobNumber) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.status) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.notes) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.assignments) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.materialsUsed) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.nidFootage) {
            haystackParts.append(normalized)
        }
        if let normalized = normalizedNonEmpty(job.canFootage) {
            haystackParts.append(normalized)
        }

        let dateString = DateFormatter.localizedString(from: job.date, dateStyle: .short, timeStyle: .none)
        if let normalized = normalizedNonEmpty(dateString) {
            haystackParts.append(normalized)
        }

        if let creator {
            let name = displayName(for: creator).lowercased()
            if !name.isEmpty {
                haystackParts.append(name)
            }
            if let role = normalizedNonEmpty(creator.normalizedPosition) {
                haystackParts.append(role)
            }
        }

        let haystack = haystackParts.joined(separator: " ")
        return tokens.allSatisfy { haystack.contains($0) }
    }

    private static func buildQuickFilters(from entries: [JobSearchIndexEntry], users: [String: AppUser]) -> [QuickFilter] {
        guard !entries.isEmpty else { return [] }

        var statusCounts: [String: (display: String, count: Int)] = [:]
        var creatorCounts: [String: (display: String, count: Int)] = [:]

        for entry in entries {
            let status = entry.status.trimmingCharacters(in: .whitespacesAndNewlines)
            if !status.isEmpty {
                let key = status.lowercased()
                if var existing = statusCounts[key] {
                    existing.count += 1
                    statusCounts[key] = existing
                } else {
                    statusCounts[key] = (status, 1)
                }
            }

            if let creatorID = entry.createdBy, let user = users[creatorID] {
                let name = displayName(for: user)
                guard !name.isEmpty else { continue }
                let key = name.lowercased()
                if var existing = creatorCounts[key] {
                    existing.count += 1
                    creatorCounts[key] = existing
                } else {
                    creatorCounts[key] = (name, 1)
                }
            }
        }

        let topStatuses = statusCounts.values
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.display.localizedCaseInsensitiveCompare(rhs.display) == .orderedAscending
            }
            .prefix(4)
            .map { QuickFilter(kind: .status, value: $0.display, count: $0.count) }

        let topCreators = creatorCounts.values
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.display.localizedCaseInsensitiveCompare(rhs.display) == .orderedAscending
            }
            .prefix(4)
            .map { QuickFilter(kind: .creator, value: $0.display, count: $0.count) }

        let combined = topStatuses + topCreators
        return Array(combined.prefix(8))
    }

    private static func normalizedTokens(from query: String) -> [String] {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased() }
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func displayValue(_ value: String?) -> String? {
        guard let value = value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func displayName(for user: AppUser) -> String {
        "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
