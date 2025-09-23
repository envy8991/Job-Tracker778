import XCTest
@testable import Job_Tracker

final class RecentCrewJobDetailSheetTests: XCTestCase {
    private func makeJob(
        createdBy: String? = nil,
        assignedTo: String? = nil,
        crewLead: String? = nil
    ) -> RecentCrewJob {
        RecentCrewJob(
            id: "job-1",
            jobNumber: "JT-1001",
            address: "123 Main Street",
            status: "Pending",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            notes: nil,
            createdBy: createdBy,
            assignedTo: assignedTo,
            hours: nil,
            materialsUsed: nil,
            canFootage: nil,
            nidFootage: nil,
            photos: nil,
            participants: nil,
            crewLead: crewLead,
            crewName: nil,
            crewRoleRaw: "Aerial",
            crewRaw: nil,
            roleRaw: nil,
            extraRoleValues: []
        )
    }

    func testDetailItemsUseDisplayNameWhenProfileFound() {
        let user = AppUser(
            id: "user-123",
            firstName: "Jordan",
            lastName: "Taylor",
            email: "jordan@example.com",
            position: "Technician"
        )
        let usersViewModel = UsersViewModel(shouldListen: false, seedUsers: [user.id: user])
        let job = makeJob(createdBy: user.id, crewLead: user.id)

        let items = RecentCrewJobDetailSheet.makeDetailItems(for: job, usersViewModel: usersViewModel)

        XCTAssertEqual(
            items.first(where: { $0.title == "Created By" })?.value,
            "Jordan Taylor"
        )
        XCTAssertEqual(
            items.first(where: { $0.title == "Crew Lead" })?.value,
            "Jordan Taylor"
        )
    }

    func testDetailItemsFallbackToUIDWhenProfileMissing() {
        let usersViewModel = UsersViewModel(shouldListen: false)
        let job = makeJob(assignedTo: "unknown-user")

        let items = RecentCrewJobDetailSheet.makeDetailItems(for: job, usersViewModel: usersViewModel)

        XCTAssertEqual(
            items.first(where: { $0.title == "Assigned To" })?.value,
            "unknown-user"
        )
    }
}
