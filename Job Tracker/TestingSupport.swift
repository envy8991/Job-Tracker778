import Foundation

extension ProcessInfo {
    var isJobTrackerUITesting: Bool {
        environment["JT_UI_TESTING"] == "1"
    }

    var shouldSeedJobTrackerUITestData: Bool {
        environment["JT_UI_TESTING_SEED_DATA"] == "1"
    }

    var shouldUseAdminJobTrackerUITestUser: Bool {
        environment["JT_UI_TESTING_ADMIN"] == "1"
    }
}
