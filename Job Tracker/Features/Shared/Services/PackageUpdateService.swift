import Foundation
import Network
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct PackageRetentionPolicy {
    let maxPackageVersions: Int
    let maxTotalBytes: Int64?
    let minimumFreeBytes: Int64?

    init(maxPackageVersions: Int = 3, maxTotalBytes: Int64? = nil, minimumFreeBytes: Int64? = nil) {
        self.maxPackageVersions = maxPackageVersions
        self.maxTotalBytes = maxTotalBytes
        self.minimumFreeBytes = minimumFreeBytes
    }
}

struct PackageUpdateConditions {
    let requiresNetwork: Bool
    let requiresUnmetered: Bool
    let requiresCharging: Bool
    let minimumBatteryLevel: Float
    let allowLowPowerMode: Bool
    let idleOnly: Bool

    init(
        requiresNetwork: Bool = true,
        requiresUnmetered: Bool = false,
        requiresCharging: Bool = false,
        minimumBatteryLevel: Float = 0.25,
        allowLowPowerMode: Bool = true,
        idleOnly: Bool = true
    ) {
        self.requiresNetwork = requiresNetwork
        self.requiresUnmetered = requiresUnmetered
        self.requiresCharging = requiresCharging
        self.minimumBatteryLevel = minimumBatteryLevel
        self.allowLowPowerMode = allowLowPowerMode
        self.idleOnly = idleOnly
    }
}

struct PackageDownloadProgress: Equatable {
    let bytesReceived: Int64
    let totalBytesExpected: Int64?
    let fractionComplete: Double?
    let lastChunkChecksum: String?
}

struct PackageDownloadResult: Equatable {
    let fileURL: URL
    let totalBytes: Int64
    let checksumChunks: [String]
}

struct PackageNetworkState: Equatable {
    let isReachable: Bool
    let isExpensive: Bool
    let isConstrained: Bool
}

final class PackageUpdateService {
    private let fileManager: FileManager
    private let session: URLSession
    private let cacheDirectory: URL
    private let idleStateProvider: () -> Bool
    private let batteryLevelProvider: () -> Float
    private let isChargingProvider: () -> Bool
    private let lowPowerModeProvider: () -> Bool
    private let networkStateProvider: () -> PackageNetworkState
    private var pathMonitor: NWPathMonitor?
    private let chunkSize: Int

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        cacheDirectory: URL? = nil,
        idleStateProvider: @escaping () -> Bool = { true },
        batteryLevelProvider: @escaping () -> Float = { PackageUpdateService.defaultBatteryLevel() },
        isChargingProvider: @escaping () -> Bool = { PackageUpdateService.defaultIsCharging() },
        lowPowerModeProvider: @escaping () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled },
        networkStateProvider: (() -> PackageNetworkState)? = nil,
        chunkSize: Int = 2_097_152 // 2 MB
    ) {
        self.fileManager = fileManager
        self.session = session
        self.idleStateProvider = idleStateProvider
        self.batteryLevelProvider = batteryLevelProvider
        self.isChargingProvider = isChargingProvider
        self.lowPowerModeProvider = lowPowerModeProvider
        self.chunkSize = chunkSize

        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.cacheDirectory = base.appendingPathComponent("PackageCache", isDirectory: true)
        }

        if let networkStateProvider {
            self.networkStateProvider = networkStateProvider
        } else {
            let monitor = NWPathMonitor()
            var latestState = PackageNetworkState(isReachable: false, isExpensive: false, isConstrained: false)
            monitor.pathUpdateHandler = { path in
                latestState = PackageNetworkState(
                    isReachable: path.status == .satisfied,
                    isExpensive: path.isExpensive,
                    isConstrained: path.isConstrained
                )
            }
            monitor.start(queue: DispatchQueue(label: "PackageUpdateService.Network"))
            self.pathMonitor = monitor
            self.networkStateProvider = { latestState }
        }

        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    deinit {
        pathMonitor?.cancel()
    }

    // MARK: - Public API

    func downloadPackage(
        version: String,
        from url: URL,
        expectedTotalBytes: Int64? = nil,
        progress: ((PackageDownloadProgress) -> Void)? = nil
    ) async throws -> PackageDownloadResult {
        let partialURL = cacheDirectory.appendingPathComponent("\(version).partial")
        let finalURL = cacheDirectory.appendingPathComponent("\(version).pkg")

        var existingSize: Int64 = 0
        if let attrs = try? fileManager.attributesOfItem(atPath: partialURL.path),
           let size = attrs[.size] as? NSNumber {
            existingSize = size.int64Value
        }

        var request = URLRequest(url: url)
        if existingSize > 0 {
            request.setValue("bytes=\(existingSize)-", forHTTPHeaderField: "Range")
        }

        let (bytes, response) = try await session.bytes(for: request)
        let expectedLength = Self.expectedTotalBytes(from: response, existingSize: existingSize) ?? expectedTotalBytes

        if !fileManager.fileExists(atPath: partialURL.path) {
            fileManager.createFile(atPath: partialURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: partialURL)
        try handle.seekToEnd()

        var received = existingSize
        var pending = Data()
        var chunkChecksums: [String] = []

        for try await dataChunk in bytes {
            pending.append(dataChunk)
            try consumeAndWritePending(
                pending: &pending,
                handle: handle,
                chunkChecksums: &chunkChecksums,
                expectedLength: expectedLength,
                progress: progress,
                bytesReceived: &received
            )
        }

        if !pending.isEmpty {
            try handle.write(contentsOf: pending)
            let checksum = Self.checksum(for: pending)
            chunkChecksums.append(checksum)
            received += Int64(pending.count)
            let fraction = Self.fractionComplete(received: received, expected: expectedLength)
            progress?(PackageDownloadProgress(
                bytesReceived: received,
                totalBytesExpected: expectedLength,
                fractionComplete: fraction,
                lastChunkChecksum: checksum
            ))
        }

        try handle.close()

        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        try fileManager.moveItem(at: partialURL, to: finalURL)

        return PackageDownloadResult(fileURL: finalURL, totalBytes: received, checksumChunks: chunkChecksums)
    }

    func enforceRetentionPolicy(_ policy: PackageRetentionPolicy) throws {
        let files = try packageFiles()
        guard !files.isEmpty else { return }

        var sortedFiles = files.sorted { lhs, rhs in
            if lhs.created == rhs.created { return lhs.url.lastPathComponent > rhs.url.lastPathComponent }
            return lhs.created > rhs.created
        }

        // Enforce version count
        if policy.maxPackageVersions > 0, sortedFiles.count > policy.maxPackageVersions {
            let overflow = sortedFiles.suffix(from: policy.maxPackageVersions)
            try overflow.forEach { try fileManager.removeItem(at: $0.url) }
            sortedFiles.removeLast(overflow.count)
        }

        // Enforce max total bytes
        if let maxBytes = policy.maxTotalBytes {
            var total = sortedFiles.reduce(Int64(0)) { $0 + $1.size }
            while total > maxBytes, let last = sortedFiles.popLast() {
                try fileManager.removeItem(at: last.url)
                total -= last.size
            }
        }

        // Enforce free space threshold
        if let minimumFreeBytes = policy.minimumFreeBytes {
            var freeBytes = try availableCapacity()
            var mutableFiles = sortedFiles
            while freeBytes < minimumFreeBytes, let last = mutableFiles.popLast() {
                try fileManager.removeItem(at: last.url)
                freeBytes += last.size
            }
        }
    }

    func canApplyUpdate(conditions: PackageUpdateConditions) -> Bool {
        if conditions.idleOnly && !idleStateProvider() { return false }
        if !conditions.allowLowPowerMode && lowPowerModeProvider() { return false }

        let batteryLevel = batteryLevelProvider()
        if batteryLevel >= 0, batteryLevel < conditions.minimumBatteryLevel { return false }
        if conditions.requiresCharging && !isChargingProvider() { return false }

        if conditions.requiresNetwork {
            let network = networkStateProvider()
            if !network.isReachable { return false }
            if conditions.requiresUnmetered && (network.isExpensive || network.isConstrained) { return false }
        }

        return true
    }

    @discardableResult
    func waitForSafeApplyWindow(
        conditions: PackageUpdateConditions,
        pollInterval: TimeInterval = 2.0,
        maxPolls: Int = 15
    ) async -> Bool {
        var attempts = 0
        while !canApplyUpdate(conditions: conditions) && attempts < maxPolls {
            attempts += 1
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return canApplyUpdate(conditions: conditions)
    }

    // MARK: - Helpers

    private func consumeAndWritePending(
        pending: inout Data,
        handle: FileHandle,
        chunkChecksums: inout [String],
        expectedLength: Int64?,
        progress: ((PackageDownloadProgress) -> Void)?,
        bytesReceived: inout Int64
    ) throws {
        while pending.count >= chunkSize {
            let chunk = pending.prefix(chunkSize)
            try handle.write(contentsOf: chunk)
            pending.removeFirst(chunk.count)

            bytesReceived += Int64(chunk.count)

            let checksum = Self.checksum(for: chunk)
            chunkChecksums.append(checksum)
            let fraction = Self.fractionComplete(received: bytesReceived, expected: expectedLength)
            progress?(PackageDownloadProgress(
                bytesReceived: bytesReceived,
                totalBytesExpected: expectedLength,
                fractionComplete: fraction,
                lastChunkChecksum: checksum
            ))
        }
    }

    private func packageFiles() throws -> [(url: URL, created: Date, size: Int64)] {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
        return contents.compactMap { url in
            guard url.pathExtension == "pkg" else { return nil }
            let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let created = attrs?.creationDate ?? Date.distantPast
            let size = Int64(attrs?.fileSize ?? 0)
            return (url: url, created: created, size: size)
        }
    }

    private func availableCapacity() throws -> Int64 {
        let values = try cacheDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    private static func expectedTotalBytes(from response: URLResponse, existingSize: Int64) -> Int64? {
        if let http = response as? HTTPURLResponse,
           let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
           let totalString = contentRange.split(separator: "/").last,
           let total = Int64(totalString) {
            return total
        }

        let expected = response.expectedContentLength
        if expected == NSURLSessionTransferSizeUnknown { return nil }
        return expected + existingSize
    }

    private static func checksum(for data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return String(format: "%02x", data.hashValue)
        #endif
    }

    private static func fractionComplete(received: Int64, expected: Int64?) -> Double? {
        guard let expected, expected > 0 else { return nil }
        return min(1.0, Double(received) / Double(expected))
    }

    private static func defaultBatteryLevel() -> Float {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 1 : level
        #else
        return 1
        #endif
    }

    private static func defaultIsCharging() -> Bool {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        #else
        return true
        #endif
    }
}
