import XCTest
@testable import Job_Tracker

final class PackageUpdateServiceTests: XCTestCase {
    func testRetentionPolicyPrunesOldAndOversizePackages() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = PackageUpdateService(
            fileManager: .default,
            cacheDirectory: tempDir,
            networkStateProvider: { PackageNetworkState(isReachable: true, isExpensive: false, isConstrained: false) }
        )

        let packages: [(String, Int)] = [("v1", 48), ("v2", 64), ("v3", 96)]
        for (index, pkg) in packages.enumerated() {
            let url = tempDir.appendingPathComponent("\(pkg.0).pkg")
            let data = Data(repeating: UInt8(index), count: pkg.1)
            FileManager.default.createFile(atPath: url.path, contents: data)
            let createdDate = Date().addingTimeInterval(-Double(index + 1) * 60)
            try FileManager.default.setAttributes([.creationDate: createdDate], ofItemAtPath: url.path)
        }

        try service.enforceRetentionPolicy(
            PackageRetentionPolicy(
                maxPackageVersions: 2,
                maxTotalBytes: 140,
                minimumFreeBytes: nil
            )
        )

        let remaining = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains(where: { $0.lastPathComponent.contains("v1") }))

        let totalSize = remaining.reduce(0) { partial, url in
            let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            return partial + size
        }
        XCTAssertLessThanOrEqual(totalSize, 140)
    }

    func testApplyGatesCheckBatteryNetworkAndIdleState() {
        let restrictiveConditions = PackageUpdateConditions(
            requiresNetwork: true,
            requiresUnmetered: true,
            requiresCharging: true,
            minimumBatteryLevel: 0.5,
            allowLowPowerMode: false,
            idleOnly: true
        )

        let blockedService = PackageUpdateService(
            cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            idleStateProvider: { false },
            batteryLevelProvider: { 0.2 },
            isChargingProvider: { false },
            lowPowerModeProvider: { true },
            networkStateProvider: { PackageNetworkState(isReachable: false, isExpensive: true, isConstrained: true) }
        )

        XCTAssertFalse(blockedService.canApplyUpdate(conditions: restrictiveConditions))

        let allowedService = PackageUpdateService(
            cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            idleStateProvider: { true },
            batteryLevelProvider: { 0.9 },
            isChargingProvider: { true },
            lowPowerModeProvider: { false },
            networkStateProvider: { PackageNetworkState(isReachable: true, isExpensive: false, isConstrained: false) }
        )

        XCTAssertTrue(allowedService.canApplyUpdate(conditions: restrictiveConditions))
    }

    func testWaitForSafeApplyWindowPollsUntilReady() async {
        var idle = false
        let readyService = PackageUpdateService(
            cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            idleStateProvider: { idle },
            batteryLevelProvider: { 0.8 },
            isChargingProvider: { true },
            lowPowerModeProvider: { false },
            networkStateProvider: { PackageNetworkState(isReachable: true, isExpensive: false, isConstrained: false) }
        )

        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            idle = true
        }

        let isReady = await readyService.waitForSafeApplyWindow(
            conditions: PackageUpdateConditions(idleOnly: true),
            pollInterval: 0.05,
            maxPolls: 5
        )

        XCTAssertTrue(isReady)
    }
}
