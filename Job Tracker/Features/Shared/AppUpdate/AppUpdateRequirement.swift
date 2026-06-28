import Foundation

struct AppUpdateRequirement: Equatable {
    let latestVersion: String
    let minimumRequiredVersion: String?
    let latestBuild: String?
    let minimumRequiredBuild: String?
    let updateURL: URL?
    let releaseNotes: String?
    let isEnabled: Bool

    init(
        latestVersion: String,
        minimumRequiredVersion: String? = nil,
        latestBuild: String? = nil,
        minimumRequiredBuild: String? = nil,
        updateURL: URL? = nil,
        releaseNotes: String? = nil,
        isEnabled: Bool = true
    ) {
        self.latestVersion = latestVersion
        self.minimumRequiredVersion = minimumRequiredVersion
        self.latestBuild = latestBuild
        self.minimumRequiredBuild = minimumRequiredBuild
        self.updateURL = updateURL
        self.releaseNotes = releaseNotes
        self.isEnabled = isEnabled
    }
}

enum AppUpdateDecision: Equatable {
    case upToDate
    case updateRequired(AppUpdateRequirement)
}

enum AppVersionComparator {
    static func decision(
        currentVersion: String,
        currentBuild: String?,
        requirement: AppUpdateRequirement?
    ) -> AppUpdateDecision {
        guard let requirement, requirement.isEnabled else { return .upToDate }

        if let minimumRequiredVersion = requirement.minimumRequiredVersion,
           compare(currentVersion, minimumRequiredVersion) == .orderedAscending {
            return .updateRequired(requirement)
        }

        if let minimumRequiredBuild = requirement.minimumRequiredBuild,
           let currentBuild,
           compare(currentVersion, requirement.minimumRequiredVersion ?? requirement.latestVersion) == .orderedSame,
           compareBuild(currentBuild, minimumRequiredBuild) == .orderedAscending {
            return .updateRequired(requirement)
        }

        if compare(currentVersion, requirement.latestVersion) == .orderedAscending {
            return .updateRequired(requirement)
        }

        if let latestBuild = requirement.latestBuild,
           let currentBuild,
           compareBuild(currentBuild, latestBuild) == .orderedAscending,
           compare(currentVersion, requirement.latestVersion) == .orderedSame {
            return .updateRequired(requirement)
        }

        return .upToDate
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = normalizedVersionParts(lhs)
        let right = normalizedVersionParts(rhs)
        let maxCount = max(left.count, right.count)

        for index in 0..<maxCount {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }

        return .orderedSame
    }

    static func compareBuild(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if let left = Int(lhs), let right = Int(rhs) {
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
            return .orderedSame
        }

        return lhs.localizedStandardCompare(rhs)
    }

    private static func normalizedVersionParts(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let numericPrefix = part.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }
}

extension Bundle {
    var appShortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var appBuildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
