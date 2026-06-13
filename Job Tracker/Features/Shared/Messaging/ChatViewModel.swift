//
//  ChatViewModel.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 5/2/25.
//

//
//  ChatViewModel.swift
//  Job Tracker
//
//  Real‑time Firestore listener + sender for a single room.
//

import SwiftUI
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {
    
    // Published data
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    
    // Room / user context
    let roomID: String
    let currentUID: String
    
    // Firestore glue
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init(roomID: String, currentUID: String) {
        self.roomID     = roomID
        self.currentUID = currentUID
        listen()                                // start realtime feed
    }
    
    deinit { listener?.remove() }
    
    // MARK: – Firestore listener
    private func listen() {
        listener = db.collection("conversations")
            .document(roomID)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                self?.messages = docs.compactMap {
                    try? $0.data(as: ChatMessage.self)
                }
                
                // Clear my unread counter for this peer
                let peerID = (self?.roomID.components(separatedBy: "_").filter { $0 != self?.currentUID }.first) ?? ""
                if !peerID.isEmpty {
                    self?.db.collection("userUnread").document(self!.currentUID).updateData([
                        peerID: 0
                    ])
                }
            }
    }
    
    // MARK: – Send a new message
    func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        
        let msg = ChatMessage(
            text: trimmed,
            senderID: currentUID,
            timestamp: Date()
        )
        do {
            try db.collection("conversations")
                .document(roomID)
                .collection("messages")
                .addDocument(from: msg)
            
            let receiverID = (roomID.components(separatedBy: "_").filter { $0 != currentUID }.first) ?? ""
            if !receiverID.isEmpty {
                let unreadRef = db.collection("userUnread").document(receiverID)
                db.runTransaction({ (transaction, _) -> Any? in
                    var counts: [String:Int] = [:]
                    if let existing = try? transaction.getDocument(unreadRef).data() as? [String:Int] {
                        counts = existing
                    }
                    counts[self.currentUID, default: 0] += 1
                    transaction.setData(counts, forDocument: unreadRef)
                    return nil
                }) { _, error in
                    if let error = error {
                        print("Unread increment failed:", error)
                    }
                }
            }
        } catch {
            print("Send failed:", error)
        }
    }
}
