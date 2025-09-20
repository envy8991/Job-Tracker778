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

    enum RouteDestination {
        case aggregate(Aggregate)
        case job(Job)
    }

    @Published var query: String = ""
    @Published private(set) var aggregates: [Aggregate] = []
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

    func routeDestination(for route: Route) -> RouteDestination? {
        switch route {
        case .aggregate(let id):
            guard let aggregate = aggregateLookup[id] else { return nil }
            return .aggregate(aggregate)
        case .job(let id):
            guard let job = job(forID: id) else { return nil }
            return .job(job)
        }
    }

    func job(forID id: String) -> Job? {
        if let cached = jobLookup[id] {
            return cached
        }
        if let job = jobsViewModel.searchJobs.first(where: { $0.id == id }) {
            return job
        }
        return jobsViewModel.jobs.first(where: { $0.id == id })
    }

    private func configureSubscriptions() {
        $query
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

        guard !trimmedQuery.isEmpty else {
            aggregates = []
            aggregateLookup = [:]
            rebuildJobLookup(filteredJobs: [])
            return
        }

        let source = jobsViewModel.searchJobs.isEmpty ? jobsViewModel.jobs : jobsViewModel.searchJobs

        let filtered = source
            .filter { matches(job: $0, query: trimmedQuery, users: users) }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.address.localizedCaseInsensitiveCompare(rhs.address) == .orderedAscending
            }

        let aggregates = buildAggregates(from: filtered, users: users)
        self.aggregates = aggregates
        aggregateLookup = Dictionary(uniqueKeysWithValues: aggregates.map { ($0.id, $0) })
        rebuildJobLookup(filteredJobs: filtered)
    }

    private func rebuildJobLookup(filteredJobs: [Job]) {
        var lookup: [String: Job] = [:]
        for job in filteredJobs {
            lookup[job.id] = job
        }

        for job in jobsViewModel.searchJobs {
            lookup[job.id] = job
        }

        for job in jobsViewModel.jobs {
            lookup[job.id] = job
        }

        jobLookup = lookup
    }

    private func matches(job: Job, query: String, users: [String: AppUser]) -> Bool {
        let creator = job.createdBy.flatMap { users[$0] }
        return JobSearchMatcher.matches(job: job, query: query, creator: creator)
    }

    private func buildAggregates(from jobs: [Job], users: [String: AppUser]) -> [Aggregate] {
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
