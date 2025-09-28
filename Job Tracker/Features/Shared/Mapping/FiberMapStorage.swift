import Foundation
import CoreLocation

struct MapCameraState: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var zoom: Double?
}

struct FiberMapSnapshot: Codable, Equatable {
    var poles: [Pole]
    var splices: [SpliceEnclosure]
    var lines: [FiberLine]
    var mapCamera: MapCameraState?
}

final class FiberMapStorage {
    static let shared = FiberMapStorage()

    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directoryURL: URL? = nil,
        fileName: String = "FiberMapData.json",
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder

        if let directoryURL {
            self.directoryURL = directoryURL
        } else if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.directoryURL = documents
        } else {
            self.directoryURL = fileManager.temporaryDirectory
        }

        self.fileURL = self.directoryURL.appendingPathComponent(fileName)

        if !fileManager.fileExists(atPath: self.directoryURL.path) {
            try? fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
        }
    }

    func load() throws -> FiberMapSnapshot? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(FiberMapSnapshot.self, from: data)
    }

    func save(_ snapshot: FiberMapSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func save(poles: [Pole], splices: [SpliceEnclosure], lines: [FiberLine], mapCamera: MapCameraState) throws {
        try save(FiberMapSnapshot(poles: poles, splices: splices, lines: lines, mapCamera: mapCamera))
    }
}
