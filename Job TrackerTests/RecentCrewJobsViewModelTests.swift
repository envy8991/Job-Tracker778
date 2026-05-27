import XCTest
@testable import Job_Tracker

final class RecentCrewJobsViewModelTests: XCTestCase {
    func testCrewRoleFiltersFallbackToSubmitterPosition() {
        let users: [String: AppUser] = [
            "ug-user": AppUser(id: "ug-user", firstName: "Una", lastName: "Ground", email: "ug@example.com", position: "Underground"),
            "aerial-user": AppUser(id: "aerial-user", firstName: "Al", lastName: "Aerial", email: "aerial@example.com", position: "Ariel"),
            "can-user": AppUser(id: "can-user", firstName: "Cam", lastName: "North", email: "can@example.com", position: "CAN"),
            "nid-user": AppUser(id: "nid-user", firstName: "Nia", lastName: "Down", email: "nid@example.com", position: "nid")
        ]

        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        let jobs: [RecentCrewJob] = [
            RecentCrewJob(
                id: "job-underground",
                jobNumber: "UG-1",
                address: "101 Underground Way",
                status: "Completed",
                date: baseDate,
                notes: nil,
                createdBy: "ug-user",
                assignedTo: nil,
                hours: nil,
                materialsUsed: nil,
                canFootage: nil,
                nidFootage: nil,
                photos: nil,
                participants: nil,
                crewLead: nil,
                crewName: nil,
                crewRoleRaw: nil,
                crewRaw: nil,
                roleRaw: nil,
                extraRoleValues: []
            ),
            RecentCrewJob(
                id: "job-aerial",
                jobNumber: "AR-1",
                address: "202 Aerial Ave",
                status: "Completed",
                date: baseDate.addingTimeInterval(60),
                notes: nil,
                createdBy: "aerial-user",
                assignedTo: nil,
                hours: nil,
                materialsUsed: nil,
                canFootage: nil,
                nidFootage: nil,
                photos: nil,
                participants: nil,
                crewLead: nil,
                crewName: nil,
                crewRoleRaw: nil,
                crewRaw: nil,
                roleRaw: nil,
                extraRoleValues: []
            ),
            RecentCrewJob(
                id: "job-can",
                jobNumber: "CA-1",
                address: "303 Can Rd",
                status: "Completed",
                date: baseDate.addingTimeInterval(120),
                notes: nil,
                createdBy: "can-user",
                assignedTo: nil,
                hours: nil,
                materialsUsed: nil,
                canFootage: nil,
                nidFootage: nil,
                photos: nil,
                participants: nil,
                crewLead: nil,
                crewName: nil,
                crewRoleRaw: nil,
                crewRaw: nil,
                roleRaw: nil,
                extraRoleValues: []
            ),
            RecentCrewJob(
                id: "job-nid",
                jobNumber: "NI-1",
                address: "404 Nid Blvd",
                status: "Completed",
                date: baseDate.addingTimeInterval(180),
                notes: nil,
                createdBy: "nid-user",
                assignedTo: nil,
                hours: nil,
                materialsUsed: nil,
                canFootage: nil,
                nidFootage: nil,
                photos: nil,
                participants: nil,
                crewLead: nil,
                crewName: nil,
                crewRoleRaw: nil,
                crewRaw: nil,
                roleRaw: nil,
                extraRoleValues: []
            )
        ]

        let viewModel = RecentCrewJobsViewModel(userLookup: { users }, initialJobs: jobs)

        XCTAssertEqual(viewModel.groups(for: .all).flatMap { $0.jobs }.map(\.id).sorted(), ["job-aerial", "job-can", "job-nid", "job-underground"].sorted())

        XCTAssertEqual(viewModel.groups(for: .underground).flatMap { $0.jobs }.map(\.id), ["job-underground"])
        XCTAssertEqual(viewModel.groups(for: .aerial).flatMap { $0.jobs }.map(\.id), ["job-aerial"])
        XCTAssertEqual(viewModel.groups(for: .can).flatMap { $0.jobs }.map(\.id), ["job-can"])
        XCTAssertEqual(viewModel.groups(for: .nid).flatMap { $0.jobs }.map(\.id), ["job-nid"])
    }
}
