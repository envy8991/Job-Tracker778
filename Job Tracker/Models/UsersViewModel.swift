//
//  UsersViewModel.swift
//  Job Tracking Cable South
//
//  Created by Quinton  Thompson  on 1/30/25.
//


import SwiftUI
import FirebaseFirestore


class UsersViewModel: ObservableObject {
    @Published var usersDict: [String: AppUser] = [:]
    
    /// Alphabetical array of all users (handy for lists)
    var allUsers: [AppUser] {
        Array(usersDict.values)
            .sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
    }
    
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        listenToAllUsers()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    private func listenToAllUsers() {
        let db = Firestore.firestore()
        // Listen to /users collection
        listenerRegistration = db.collection("users")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to users: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                
                var temp: [String: AppUser] = [:]
                
                for doc in documents {
                    do {
                        let appUser = try doc.data(as: AppUser.self)
                        temp[appUser.id] = appUser
                    } catch {
                        print("Error decoding user doc: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.usersDict = temp
                }
            }
    }
    
    /// Quick lookup
    func user(id: String) -> AppUser? { usersDict[id] }
}
