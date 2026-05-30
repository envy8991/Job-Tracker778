import SwiftUI
import FirebaseFirestore


class UserTimesheetsViewModel: ObservableObject {
    @Published var timesheets: [Timesheet] = []
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func fetchTimesheets(for userId: String) {
        listenerRegistration?.remove()

        FirebaseService.shared.fetchPartnerId(for: userId) { [weak self] partnerId in
            guard let self = self else { return }
            var query: Query
            if let pid = partnerId {
                query = self.db.collection("timesheets")
                    .whereField("userId", in: [userId, pid])
                    .order(by: "weekStart", descending: true)
            } else {
                query = self.db.collection("timesheets")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "weekStart", descending: true)
            }

            self.listenerRegistration = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching timesheets: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }

                let fetchedTimesheets = documents.compactMap { doc -> Timesheet? in
                    try? doc.data(as: Timesheet.self)
                }

                DispatchQueue.main.async {
                    self.timesheets = fetchedTimesheets
                }
            }
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    func saveTimesheet(_ timesheet: Timesheet, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        var sharedTimesheet = timesheet
        sharedTimesheet.userId = Timesheet.canonicalOwnerID(userId: timesheet.userId, partnerId: timesheet.partnerId)
        sharedTimesheet.partnerId = Timesheet.canonicalPartnerID(userId: timesheet.userId, partnerId: timesheet.partnerId)
        let docId = Timesheet.documentID(userId: timesheet.userId, partnerId: timesheet.partnerId, weekStart: timesheet.weekStart)
        do {
            try db.collection("timesheets").document(docId).setData(from: sharedTimesheet) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    func deleteTimesheet(documentID: String, completion: @escaping (Bool) -> Void = { _ in }) {
        db.collection("timesheets").document(documentID).delete { error in
            if let error = error {
                print("Error deleting timesheet: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
