//
//  ChatMessage.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 5/2/25.
//

//
//  ChatModels.swift
//  Job Tracker
//
//  Defines the Firestore‑mapped message object.
//



//
//  ChatMessage.swift
//  Job Tracker
//
//  Firestore‑mapped chat message model.
//

import Foundation
import FirebaseFirestore   // Provides the @DocumentID wrapper

/// Document stored at /conversations/{roomID}/messages/{messageID}
struct ChatMessage: Identifiable, Codable {
    @DocumentID var id: String?      // Firestore auto‑fills documentID
    var text: String                 // message body
    var senderID: String             // Firebase UID of author
    var timestamp: Date              // UTC timestamp
}
