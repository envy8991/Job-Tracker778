//
//  AuthViewModel.swift
//  Job Tracking Cable South
//
//  Created by Quinton  Thompson  on 1/30/25.
//


import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
@Published var currentUser: AppUser? = nil
@Published var isSignedIn: Bool = false
    @Published var isAdminFlag: Bool = false
    @Published var isSupervisorFlag: Bool = false

private var cancellables = Set<AnyCancellable>()

init() {
    checkAuthState()
}

    private func applyUser(_ user: AppUser?) {
        self.currentUser = user
        self.isSignedIn = (user != nil)
        self.isAdminFlag = (user?.isAdmin == true)
        self.isSupervisorFlag = (user?.isSupervisor == true)
    }

func checkAuthState() {
    if let _ = FirebaseService.shared.currentUserID() {
        FirebaseService.shared.fetchCurrentUser { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.applyUser(user)
                case .failure:
                    self?.applyUser(nil)
                }
            }
        }
    } else {
        DispatchQueue.main.async { self.applyUser(nil) }
    }
}

func signUp(firstName: String, lastName: String, position: String, email: String, password: String, completion: @escaping (Error?) -> Void) {
    FirebaseService.shared.signUpUser(firstName: firstName, lastName: lastName, position: position, email: email, password: password) { [weak self] result in
        switch result {
        case .success(let user):
            DispatchQueue.main.async { self?.applyUser(user) }
            completion(nil)
        case .failure(let error):
            completion(error)
        }
    }
}

func signIn(email: String, password: String, completion: @escaping (Error?) -> Void) {
    FirebaseService.shared.signInUser(email: email, password: password) { [weak self] result in
        switch result {
        case .success(_):
            FirebaseService.shared.fetchCurrentUser { userResult in
                switch userResult {
                case .success(let user):
                    DispatchQueue.main.async {
                        self?.applyUser(user)
                        completion(nil)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        case .failure(let error):
            completion(error)
        }
    }
}

func refreshCurrentUser(completion: ((Error?) -> Void)? = nil) {
    FirebaseService.shared.fetchCurrentUser { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let user):
                self?.applyUser(user)
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }
}

    /// Deletes only the user's account (Auth and, optionally, their `/users/{uid}` profile),
    /// while preserving all job documents. This keeps historical job records intact.
    ///
    /// Your FirebaseService implementation should:
    /// - delete the Firebase Auth user
    /// - optionally delete `/users/{uid}` profile doc
    /// - NOT delete any job docs
    func deleteAccount(preserveJobs: Bool = true, completion: @escaping (Result<Void, Error>) -> Void) {
        FirebaseService.shared.deleteCurrentAuthUser(preserveJobs: preserveJobs) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.applyUser(nil)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

func signOut() {
    do {
        try FirebaseService.shared.signOutUser()
        applyUser(nil)
    } catch {
        print("Sign-out error: \(error)")
    }
}

    var isAdmin: Bool { isAdminFlag }
    var isSupervisor: Bool { isSupervisorFlag }
}
