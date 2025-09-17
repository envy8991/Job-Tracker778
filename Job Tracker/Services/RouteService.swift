//
//  RouteService.swift
//  Job Tracker
//
//  Legacy: global route sync service (kept for compatibility).
//  The new Route Mapper uses private, invite‑only sessions in MapsView.
//  This file has been updated to the current Pole model so it compiles cleanly.
//

import Foundation
import FirebaseFirestore

import CoreLocation

/// Real‑time bridge between a Firestore `routes/<routeID>` document and
/// the in‑memory poles array used by the Route Mapper UI.
final class RouteService: ObservableObject {
    
    // MARK: – Public published state
    @Published var poles: [Pole] = []
    @Published var activeUsers: [String] = []      // simple presence list
    
    // MARK: – Private Firestore handles
    private let docRef: DocumentReference
    private var poleListener: ListenerRegistration?
    private var presenceListener: ListenerRegistration?
    private var heartbeatTimer: Timer?
    
    // MARK: – Init
    init(routeID: String = "defaultRoute") {
        self.docRef = Firestore.firestore()
            .collection("routes")
            .document(routeID)
    }
    
    // MARK: – Presence sub‑collection reference
    private var presenceRef: CollectionReference {
        docRef.collection("presence")
    }
    
    // MARK: – Lifecycle
    /// Begin listening for pole changes and start presence heartbeat.
    func start(currentUserID uid: String = UIDevice.current.identifierForVendor?.uuidString ?? "anon") {
        stop()  // cancel any existing listeners
        
        // ---- Pole array listener ----
        poleListener = docRef.addSnapshotListener { [weak self] snap, _ in
            guard
                let data = snap?.data(),
                let arr  = data["poles"] as? [[String: Any]]
            else { return }
            DispatchQueue.main.async {
                self?.poles = arr.compactMap { Pole.fromDict($0) }
            }
        }
        
        // ---- Presence list listener ----
        presenceListener = presenceRef.addSnapshotListener { [weak self] snap, _ in
            let ids = snap?.documents.map(\.documentID) ?? []
            DispatchQueue.main.async { self?.activeUsers = ids }
        }
        
        // ---- Heartbeat ----
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10,
                                              repeats: true) { [weak self] _ in
            self?.presenceRef.document(uid).setData([
                "ts": Timestamp(date: Date())
            ])
        }
    }
    
    /// Stop all listeners & timers.
    func stop() {
        poleListener?.remove();      poleListener = nil
        presenceListener?.remove();  presenceListener = nil
        heartbeatTimer?.invalidate(); heartbeatTimer = nil
    }
    
    // MARK: – Mutations
    /// Push a fresh copy of `poles` to Firestore (overwrites existing).
    func push(_ poles: [Pole]) {
        let arr = poles.map { $0.toDict() }
        docRef.setData(["poles": arr], merge: true)
    }
}

// MARK: – Pole ⇄ Dictionary helpers
extension Pole {
    
    func toDict() -> [String: Any] {
        [
            "id": id.uuidString,
            "lat": coordinate.latitude,
            "lon": coordinate.longitude,
            "assignment": assignment,
            "canAtLocation": canAtLocation,
            "notes": notes
            // NOTE: Photos could be stored as URLs here in the future.
        ]
    }
    
    static func fromDict(_ dict: [String: Any]) -> Pole? {
        guard
            let idStr = dict["id"] as? String,
            let lat   = dict["lat"] as? CLLocationDegrees,
            let lon   = dict["lon"] as? CLLocationDegrees
        else { return nil }
        
        var pole = Pole(id: UUID(uuidString: idStr) ?? UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: lat,
                                                            longitude: lon))
        pole.assignment     = dict["assignment"]     as? String ?? ""
        pole.canAtLocation  = dict["canAtLocation"]  as? Bool   ?? false
        pole.notes          = dict["notes"]          as? String ?? ""
        return pole
    }
}
