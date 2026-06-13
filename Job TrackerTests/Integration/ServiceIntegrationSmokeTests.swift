import XCTest
import PDFKit
@testable import Job_Tracker

final class ServiceIntegrationSmokeTests: XCTestCase {
    func testJobPhotoSlotsMapToFirestoreFields() {
        XCTAssertEqual(JobPhotoSlot.house.firestoreField, "housePhotoURL")
        XCTAssertEqual(JobPhotoSlot.nid.firestoreField, "nidPhotoURL")
        XCTAssertEqual(JobPhotoSlot.can.firestoreField, "canPhotoURL")
    }

    func testWeeklyTimesheetPDFGeneratorWritesReadablePDF() throws {
        let job = makeJob(id: "timesheet-job", address: "100 Safety Net Lane")
        let generator = WeeklyTimesheetPDFGenerator(
            startOfWeek: job.date,
            endOfWeek: job.date.addingTimeInterval(6 * 24 * 60 * 60),
            jobs: [job],
            currentUserID: "user-1",
            partnerUserID: nil,
            supervisor: "Safety Supervisor",
            name1: "Crew Tester",
            name2: "",
            gibsonHours: "8",
            cableSouthHours: "0",
            totalHours: "8",
            gibsonHours2: "",
            cableSouthHours2: "",
            totalHours2: "",
            dailyTotalHours: [Calendar.current.startOfDay(for: job.date): "8"]
        )

        let url = try XCTUnwrap(generator.generatePDF())
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 0)
    }

    func testYellowSheetPDFGeneratorWritesReadablePDF() throws {
        let user = AppUser(id: "user-1", firstName: "Crew", lastName: "Tester", email: "crew@example.com", position: "Technician")
        let job = makeJob(id: "yellow-job", address: "200 Yellow Sheet Road")
        let generator = YellowSheetPDFGenerator(weekStart: job.date, jobs: [job], user: user)

        let url = try XCTUnwrap(generator.generatePDF())
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        let document = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(document.pageCount, 0)
    }

    @MainActor
    func testArrivalAlertManagerStartsInactiveWhenDailyToggleIsOff() {
        let defaults = UserDefaults(suiteName: "ArrivalAlertManagerTests-\(UUID().uuidString)")!
        defaults.set(false, forKey: "arrivalAlertsEnabledToday")
        let manager = ArrivalAlertManager(locationService: LocationService(), userDefaults: defaults)

        if manager.status.message.localizedCaseInsensitiveContains("support") {
            XCTAssertEqual(manager.status.kind, .error)
        } else {
            XCTAssertEqual(manager.status.kind, .inactive)
            XCTAssertTrue(manager.status.message.localizedCaseInsensitiveContains("off"))
        }
    }

    func testPhoneWatchSyncPayloadIncludesOnlyTodaysPendingUserJobs() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = today.addingTimeInterval(-24 * 60 * 60)
        let manager = PhoneWatchSyncManager.shared
        let payload = manager.makeSnapshotItems(
            jobs: [
                makeJob(id: "mine", address: "100 Safety Net Lane", date: today, status: "Pending", createdBy: "user-1"),
                makeJob(id: "done", address: "200 Done Road", date: today, status: "Done", createdBy: "user-1"),
                makeJob(id: "old", address: "300 Old Road", date: yesterday, status: "Pending", createdBy: "user-1"),
                makeJob(id: "other", address: "400 Other Road", date: today, status: "Pending", createdBy: "user-2")
            ],
            currentUserID: "user-1",
            today: today
        )

        XCTAssertEqual(payload.count, 1)
        XCTAssertEqual(payload.first?["id"] as? String, "mine")
        XCTAssertEqual(payload.first?["address"] as? String, "100 Safety Net Lane")
    }

    private func makeJob(
        id: String,
        address: String,
        date: Date = Date(),
        status: String = "Pending",
        createdBy: String = "user-1"
    ) -> Job {
        Job(
            id: id,
            address: address,
            date: date,
            status: status,
            assignedTo: createdBy,
            createdBy: createdBy,
            notes: "Integration smoke test job",
            jobNumber: id.uppercased(),
            participants: [createdBy],
            latitude: 36.0,
            longitude: -88.0
        )
    }
}
