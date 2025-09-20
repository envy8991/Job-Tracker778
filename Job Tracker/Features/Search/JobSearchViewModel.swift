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
        if let job = jobsViewModel.searchJobs.first(where: { $0.id == id }) {
            return job
        }
        return jobsViewModel.jobs.first(where: { $0.id == id })
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
            resultsState = .init(content: .prompt)
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

        if aggregates.isEmpty {
            resultsState = .init(content: .empty(query: trimmedQuery))
        } else {
            resultsState = .init(content: .aggregates(aggregates))
        }
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
