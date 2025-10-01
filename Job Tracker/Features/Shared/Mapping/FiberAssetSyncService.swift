import Foundation
import CoreLocation
import FirebaseFirestore

protocol FiberAssetSyncService: AnyObject {
    func beginListening(onChange: @escaping (Result<FiberMapSnapshot?, Error>) -> Void)
    func stopListening()
    func save(snapshot: FiberMapSnapshot) async throws
}

final class FirestoreFiberAssetSyncService: FiberAssetSyncService {
    private let document: DocumentReference
    private var listener: ListenerRegistration?

    init(routeID: String = "defaultRoute") {
        self.document = Firestore.firestore()
            .collection("routes")
            .document(routeID)
    }

    func beginListening(onChange: @escaping (Result<FiberMapSnapshot?, Error>) -> Void) {
        listener?.remove()
        listener = document.addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }

            guard let data = snapshot?.data(), let snapshot = FiberMapSnapshot(firestoreData: data) else {
                onChange(.success(nil))
                return
            }

            onChange(.success(snapshot))
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func save(snapshot: FiberMapSnapshot) async throws {
        let data = snapshot.firestoreData()
        try await withCheckedThrowingContinuation { continuation in
            document.setData(data, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension FiberMapSnapshot {
    init?(firestoreData: [String: Any]) {
        let polesData = firestoreData["poles"] as? [[String: Any]] ?? []
        let splicesData = firestoreData["splices"] as? [[String: Any]] ?? []
        let linesData = firestoreData["lines"] as? [[String: Any]] ?? []

        let poles = polesData.compactMap(Pole.init(firestoreData:))
        let splices = splicesData.compactMap(SpliceEnclosure.init(firestoreData:))
        let lines = linesData.compactMap(FiberLine.init(firestoreData:))

        let cameraData = firestoreData["mapCamera"] as? [String: Any]
        let camera = cameraData.flatMap(MapCameraState.init(firestoreData:))

        self.init(poles: poles, splices: splices, lines: lines, mapCamera: camera)
    }

    func firestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "poles": poles.map { $0.firestoreData() },
            "splices": splices.map { $0.firestoreData() },
            "lines": lines.map { $0.firestoreData() }
        ]

        if let camera = mapCamera {
            dict["mapCamera"] = camera.firestoreData()
        }

        return dict
    }
}

extension MapCameraState {
    init?(firestoreData: [String: Any]) {
        guard let latitude = firestoreData["latitude"] as? CLLocationDegrees,
              let longitude = firestoreData["longitude"] as? CLLocationDegrees else {
            return nil
        }

        let zoom = firestoreData["zoom"] as? Double
        self.init(latitude: latitude, longitude: longitude, zoom: zoom)
    }

    func firestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        if let zoom {
            dict["zoom"] = zoom
        }

        return dict
    }
}

extension Pole {
    init?(firestoreData: [String: Any]) {
        guard let idString = firestoreData["id"] as? String,
              let latitude = firestoreData["lat"] as? CLLocationDegrees,
              let longitude = firestoreData["lon"] as? CLLocationDegrees else {
            return nil
        }

        let id = UUID(uuidString: idString) ?? UUID()
        let name = firestoreData["name"] as? String ?? "Pole"
        let statusRaw = firestoreData["status"] as? String
        let status = statusRaw.flatMap(AssetStatus.init(rawValue:)) ?? .good

        let installDate: Date?
        if let timestamp = firestoreData["installDate"] as? Timestamp {
            installDate = timestamp.dateValue()
        } else if let date = firestoreData["installDate"] as? Date {
            installDate = date
        } else {
            installDate = nil
        }

        let lastInspection: Date?
        if let timestamp = firestoreData["lastInspection"] as? Timestamp {
            lastInspection = timestamp.dateValue()
        } else if let date = firestoreData["lastInspection"] as? Date {
            lastInspection = date
        } else {
            lastInspection = nil
        }

        let material = firestoreData["material"] as? String ?? "Unknown"
        let notes = firestoreData["notes"] as? String ?? ""
        let imageUrl = firestoreData["imageUrl"] as? String

        self.init(
            id: id,
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            status: status,
            installDate: installDate,
            lastInspection: lastInspection,
            material: material,
            notes: notes,
            imageUrl: imageUrl
        )
    }

    func firestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "lat": coordinate.latitude,
            "lon": coordinate.longitude,
            "status": status.rawValue,
            "material": material,
            "notes": notes
        ]

        if let installDate {
            dict["installDate"] = Timestamp(date: installDate)
        }

        if let lastInspection {
            dict["lastInspection"] = Timestamp(date: lastInspection)
        }

        if let imageUrl {
            dict["imageUrl"] = imageUrl
        }

        return dict
    }
}

extension SpliceEnclosure {
    init?(firestoreData: [String: Any]) {
        guard let idString = firestoreData["id"] as? String,
              let latitude = firestoreData["lat"] as? CLLocationDegrees,
              let longitude = firestoreData["lon"] as? CLLocationDegrees else {
            return nil
        }

        let id = UUID(uuidString: idString) ?? UUID()
        let name = firestoreData["name"] as? String ?? "Splice"
        let statusRaw = firestoreData["status"] as? String
        let status = statusRaw.flatMap(AssetStatus.init(rawValue:)) ?? .good
        let capacity = firestoreData["capacity"] as? Int ?? 0
        let notes = firestoreData["notes"] as? String ?? ""
        let imageUrl = firestoreData["imageUrl"] as? String

        self.init(
            id: id,
            name: name,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            status: status,
            capacity: capacity,
            notes: notes,
            imageUrl: imageUrl
        )
    }

    func firestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "lat": coordinate.latitude,
            "lon": coordinate.longitude,
            "status": status.rawValue,
            "capacity": capacity,
            "notes": notes
        ]

        if let imageUrl {
            dict["imageUrl"] = imageUrl
        }

        return dict
    }
}

extension FiberLine {
    init?(firestoreData: [String: Any]) {
        guard let idString = firestoreData["id"] as? String,
              let startID = firestoreData["startPoleId"] as? String,
              let endID = firestoreData["endPoleId"] as? String else {
            return nil
        }

        let id = UUID(uuidString: idString) ?? UUID()
        let startPoleId = UUID(uuidString: startID) ?? UUID()
        let endPoleId = UUID(uuidString: endID) ?? UUID()
        let statusRaw = firestoreData["status"] as? String
        let status = statusRaw.flatMap(AssetStatus.init(rawValue:)) ?? .good
        let fiberCount = firestoreData["fiberCount"] as? Int ?? 0
        let notes = firestoreData["notes"] as? String ?? ""

        self.init(
            id: id,
            startPoleId: startPoleId,
            endPoleId: endPoleId,
            status: status,
            fiberCount: fiberCount,
            notes: notes
        )
    }

    func firestoreData() -> [String: Any] {
        [
            "id": id.uuidString,
            "startPoleId": startPoleId.uuidString,
            "endPoleId": endPoleId.uuidString,
            "status": status.rawValue,
            "fiberCount": fiberCount,
            "notes": notes
        ]
    }
}
