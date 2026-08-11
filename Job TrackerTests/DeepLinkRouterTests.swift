import XCTest
@testable import Job_Tracker

final class DeepLinkRouterTests: XCTestCase {
    func testHandlesStandardImportURL() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://importJob?token=ABC123"))
        XCTAssertEqual(DeepLinkRouter.handle(url), .importJob(token: "ABC123"))
    }

    func testHandlesSingleSlashImportURL() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker:/importJob?token=XYZ789"))
        XCTAssertEqual(DeepLinkRouter.handle(url), .importJob(token: "XYZ789"))
    }

    func testHandlesSchemeWithoutSlashes() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker:importJob?token=SINGLE"))
        XCTAssertEqual(DeepLinkRouter.handle(url), .importJob(token: "SINGLE"))
    }

    func testHandlesDashboardURL() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://dashboard"))
        XCTAssertEqual(DeepLinkRouter.handle(url), .dashboard)
    }

    func testHandlesJobURL() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://job?id=job-123"))
        XCTAssertEqual(DeepLinkRouter.handle(url), .job(id: "job-123"))
    }

    func testHandlesSingleSlashJobURL() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker:/job?id=job-456"))
        XCTAssertEqual(DeepLinkRouter.handle(url), .job(id: "job-456"))
    }

    func testTrimsRouteValues() throws {
        let jobURL = try XCTUnwrap(URL(string: "jobtracker://job?id=%20job-456%20"))
        let importURL = try XCTUnwrap(URL(string: "jobtracker://importJob?token=%20ABC123%20"))

        XCTAssertEqual(DeepLinkRouter.handle(jobURL), .job(id: "job-456"))
        XCTAssertEqual(DeepLinkRouter.handle(importURL), .importJob(token: "ABC123"))
    }

    func testRejectsBlankRouteValues() throws {
        let jobURL = try XCTUnwrap(URL(string: "jobtracker://job?id=%20%20"))
        let importURL = try XCTUnwrap(URL(string: "jobtracker://importJob?token=%0A%20"))

        XCTAssertNil(DeepLinkRouter.handle(jobURL))
        XCTAssertNil(DeepLinkRouter.handle(importURL))
    }

    func testRejectsUnknownRoute() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://help?token=ABC123"))
        XCTAssertNil(DeepLinkRouter.handle(url))
    }

    func testRejectsMissingToken() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://importJob"))
        XCTAssertNil(DeepLinkRouter.handle(url))
    }
}
