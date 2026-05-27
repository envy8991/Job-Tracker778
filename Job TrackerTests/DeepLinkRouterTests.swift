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

    func testRejectsUnknownRoute() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://help?token=ABC123"))
        XCTAssertNil(DeepLinkRouter.handle(url))
    }

    func testRejectsMissingToken() throws {
        let url = try XCTUnwrap(URL(string: "jobtracker://importJob"))
        XCTAssertNil(DeepLinkRouter.handle(url))
    }
}
