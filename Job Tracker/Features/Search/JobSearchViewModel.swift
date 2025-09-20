import SwiftUI
import Combine

@MainActor
final class JobSearchViewModel: ObservableObject {
    struct Aggregate: Identifiable, Hashable {
        struct Creator: Identifiable, Hashable {
            let id: String
            let firstName: String
            let lastName: String

            var displayName: String {
                "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            }
        }

        struct JobDigest: Identifiable, Hashable {
            let id: String
            let status: String
            let date: Date
            let createdBy: String?
        }

        let id: String
        let address: String
        let jobNumber: String
        let jobs: [JobDigest]
        let creators: [Creator]

        var mostRecentJob: JobDigest? { jobs.first }
    }

    enum Route: Hashable {
        case aggregate(id: String)
        case job(id: String)
    }

    struct JobDestination {
        let job: Job
        let binding: Binding<Job>?
    }

    enum RouteDestination {
        case aggregate(id: String)
        case job(JobDestination)
    }

    struct ResultsState {
        enum Content {
            case prompt
            case empty(query: String)
            case aggregates([Aggregate])
        }

        let content: Content
    }

    @Published var query: String = ""
    @Published private(set) var aggregates: [Aggregate] = []
    @Published private(set) var resultsState: ResultsState = .init(content: .prompt)
    @Published var navigationPath: [Route] = []

    private let jobsViewModel: JobsViewModel
    private let usersViewModel: UsersViewModel

    private var aggregateLookup: [String: Aggregate] = [:]
    private var jobLookup: [String: Job] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(jobsViewModel: JobsViewModel, usersViewModel: UsersViewModel) {
        self.jobsViewModel = jobsViewModel
        self.usersViewModel = usersViewModel

        configureSubscriptions()
        rebuildAggregates()
    }

    func aggregate(forID id: String) -> Aggregate? {
        aggregateLookup[id]
    }

    func destination(for route: Route) -> RouteDestination? {
        switch route {
        case .aggregate(let id):
            guard aggregateLookup[id] != nil else { return nil }
            return .aggregate(id: id)
        case .job(let id):
            guard let job = job(forID: id) else { return nil }
            return .job(JobDestination(job: job, binding: binding(for: job)))
        }
    }

    func job(forID id: String) -> Job? {
        if let cached = jobLookup[id] {
            return cached
        }
        if let job = jobsViewModel.jobs.first(where: { $0.id == id }) {
            return job
        }
        if let entry = jobsViewModel.searchJobs.first(where: { $0.id == id }) {
            return entry.makePartialJob()
        }
        return nil
    }

    private func binding(for job: Job) -> Binding<Job>? {
        guard jobsViewModel.jobs.contains(where: { $0.id == job.id }) else { return nil }
        return Binding(
            get: { [weak self] in
                guard let self else { return job }
                return self.jobsViewModel.jobs.first(where: { $0.id == job.id }) ?? job
            },
            set: { [weak self] newValue in
                guard let self else { return }
                if let index = self.jobsViewModel.jobs.firstIndex(where: { $0.id == job.id }) {
                    var copy = self.jobsViewModel.jobs
                    copy[index] = newValue
                    self.jobsViewModel.jobs = copy
                }
            }
        )
    }

    private func configureSubscriptions() {
        $query
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.rebuildAggregates()
            }
            .store(in: &cancellables)

        jobsViewModel.$jobs
            .sink { [weak self] _ in
                self?.rebuildAggregates()
            }
            .store(in: &cancellables)

        jobsViewModel.$searchJobs
            .sink { [weak self] _ in
                self?.rebuildAggregates()
            }
            .store(in: &cancellables)

        usersViewModel.$usersDict
            .sink { [weak self] _ in
                self?.rebuildAggregates()
            }
            .store(in: &cancellables)
    }

    private func rebuildAggregates() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let users = usersViewModel.usersDict
        let searchJobs = jobsViewModel.searchJobs
        let jobs = jobsViewModel.jobs

        guard !trimmedQuery.isEmpty else {
            var lookup: [String: Job] = [:]
            for job in jobs {
                lookup[job.id] = job
            }
            for entry in searchJobs {
                if lookup[entry.id] == nil {
                    lookup[entry.id] = entry.makePartialJob()
                }
            }

            aggregates = []
            aggregateLookup = [:]
            jobLookup = lookup
            resultsState = .init(content: .prompt)
            return
        }

        let source = searchJobs.isEmpty ? jobs.map(JobSearchIndexEntry.init(job:)) : searchJobs

        Task.detached(priority: .userInitiated) { [weak self] in
            let filtered = source
                .filter { job in
                    let creator = job.createdBy.flatMap { users[$0] }
                    return JobSearchMatcher.matches(job: job, query: trimmedQuery, creator: creator)
                }
                .sorted { lhs, rhs in
                    if lhs.date != rhs.date {
                        return lhs.date > rhs.date
                    }
                    return lhs.address.localizedCaseInsensitiveCompare(rhs.address) == .orderedAscending
                }

            let aggregates = Self.buildAggregates(from: filtered, users: users)
            let aggregateLookup = Dictionary(uniqueKeysWithValues: aggregates.map { ($0.id, $0) })

            var jobLookup: [String: Job] = [:]
            for job in jobs {
                jobLookup[job.id] = job
            }
            for entry in filtered {
                if jobLookup[entry.id] == nil {
                    jobLookup[entry.id] = entry.makePartialJob()
                }
            }
            for entry in searchJobs {
                if jobLookup[entry.id] == nil {
                    jobLookup[entry.id] = entry.makePartialJob()
                }
            }

            let resultsState: ResultsState
            if aggregates.isEmpty {
                resultsState = .init(content: .empty(query: trimmedQuery))
            } else {
                resultsState = .init(content: .aggregates(aggregates))
            }

            await MainActor.run {
                guard let self = self else { return }
                self.aggregates = aggregates
                self.aggregateLookup = aggregateLookup
                self.jobLookup = jobLookup
                self.resultsState = resultsState
            }
        }
    }

    private nonisolated static func buildAggregates<T: JobSearchMatchable>(from jobs: [T], users: [String: AppUser]) -> [Aggregate] {
        let grouped = Dictionary(grouping: jobs) { job -> String in
            let number = (job.jobNumber ?? "").trimmingCharacters(in: .whitespaces)
            return job.address.lowercased() + "|#" + number.lowercased()
        }

        let aggregates: [Aggregate] = grouped.map { key, jobs in
            let address = jobs.first?.address ?? ""
            let jobNumber = (jobs.first?.jobNumber ?? "").trimmingCharacters(in: .whitespaces)
            let ordered = jobs.sorted { $0.date > $1.date }

            var seenCreators: Set<String> = []
            let creators: [Aggregate.Creator] = ordered.compactMap { job in
                guard let id = job.createdBy, !seenCreators.contains(id), let user = users[id] else {
                    return nil
                }
                seenCreators.insert(id)
                return Aggregate.Creator(id: user.id, firstName: user.firstName, lastName: user.lastName)
            }

            let digests = ordered.map { job in
                Aggregate.JobDigest(id: job.id, status: job.status, date: job.date, createdBy: job.createdBy)
            }

            return Aggregate(id: key, address: address, jobNumber: jobNumber, jobs: digests, creators: creators)
        }

        return aggregates.sorted { lhs, rhs in
            guard let leftDate = lhs.jobs.first?.date, let rightDate = rhs.jobs.first?.date else {
                return lhs.address.localizedCaseInsensitiveCompare(rhs.address) == .orderedAscending
            }

            if leftDate != rightDate {
                return leftDate > rightDate
            }
            return lhs.address.localizedCaseInsensitiveCompare(rhs.address) == .orderedAscending
        }
    }
}
