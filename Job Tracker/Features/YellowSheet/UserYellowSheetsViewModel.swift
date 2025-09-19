import SwiftUI
import FirebaseFirestore


class UserYellowSheetsViewModel: ObservableObject {
    @Published var yellowSheets: [YellowSheet] = []
    
    private var listenerRegistration: ListenerRegistration?
    private let db = Firestore.firestore()
    
    deinit {
        listenerRegistration?.remove()
    }
    
    func fetchYellowSheets(for userId: String) {
        listenerRegistration?.remove()

        FirebaseService.shared.fetchPartnerId(for: userId) { [weak self] partner in
            guard let self = self else { return }
            let ownerId: String
            if let p = partner, !p.isEmpty {
                ownerId = [userId, p].sorted().first ?? userId
            } else {
                ownerId = userId
            }

            self.listenerRegistration = self.db.collection("yellowSheets")
                .whereField("userId", isEqualTo: ownerId)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error = error {
                        print("Error fetching yellow sheets: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    self?.yellowSheets = documents.compactMap { document in
                        var sheet = try? document.data(as: YellowSheet.self)
                        sheet?.id = document.documentID
                        return sheet
                    }
                }
        }
    }
    
    func saveYellowSheet(_ sheet: YellowSheet, completion: @escaping (Bool) -> Void) {
        do {
            let docID = sheet.id ?? UUID().uuidString
            let docRef = db.collection("yellowSheets").document(docID)
            try docRef.setData(from: sheet) { error in
                if let error = error {
                    print("Error saving yellow sheet: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        } catch {
            print("Error encoding yellow sheet: \(error)")
            completion(false)
        }
    }
    
    func deleteYellowSheet(documentID: String, completion: @escaping (Bool) -> Void = { _ in }) {
        db.collection("yellowSheets").document(documentID).delete { error in
            if let error = error {
                print("Error deleting yellow sheet: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
