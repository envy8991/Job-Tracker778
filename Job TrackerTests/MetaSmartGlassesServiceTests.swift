import XCTest
@testable import Job_Tracker

@MainActor
final class MetaSmartGlassesServiceTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: MetaSmartGlassesSettings.enabledKey)
        UserDefaults.standard.removeObject(forKey: MetaSmartGlassesSettings.requireReviewKey)
        UserDefaults.standard.removeObject(forKey: MetaSmartGlassesSettings.useNearestJobKey)
        super.tearDown()
    }

    func testDefaultSettingsKeepAssistantDisabledButReviewEnabled() {
        XCTAssertFalse(MetaSmartGlassesSettings.isEnabled)
        XCTAssertTrue(MetaSmartGlassesSettings.requiresReviewBeforeUpload)
        XCTAssertTrue(MetaSmartGlassesSettings.usesNearestJob)
    }

    func testServiceReportsSDKNeededWhenEnabledWithoutAdapter() {
        UserDefaults.standard.set(true, forKey: MetaSmartGlassesSettings.enabledKey)
        let service = MetaSmartGlassesService(adapter: MetaSmartGlassesSDKAdapter())
        XCTAssertEqual(service.connectionState, .unavailable)
    }

    func testPhotoSlotDisplayTitlesAreFieldFriendly() {
        XCTAssertEqual(JobPhotoSlot.house.displayTitle, "House Photo")
        XCTAssertEqual(JobPhotoSlot.nid.displayTitle, "NID Photo")
        XCTAssertEqual(JobPhotoSlot.can.displayTitle, "CAN Photo")
    }
}
