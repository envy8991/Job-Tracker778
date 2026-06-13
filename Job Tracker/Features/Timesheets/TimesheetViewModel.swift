//
//  TimesheetViewModel.swift
//  Job Tracker
//
//  Created by Quinton  Thompson  on 2/8/25.
//


import Foundation
import FirebaseFirestore

class TimesheetViewModel: ObservableObject {
    @Published var timesheet: Timesheet?
    
    private var db = Firestore.firestore()
    
    /// Fetch the timesheet for the given week and user.
    func fetchTimesheet(for weekStart: Date, userId: String, partnerId: String? = nil) {
        let docId = Timesheet.documentID(userId: userId, partnerId: partnerId, weekStart: weekStart)
        db.collection("timesheets").document(docId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching timesheet: \(error)")
                return
            }
            if let snapshot = snapshot, snapshot.exists {
                do {
                    let ts = try snapshot.data(as: Timesheet.self)
                    DispatchQueue.main.async {
                        self.timesheet = ts
                    }
                } catch {
                    print("Error decoding timesheet: \(error)")
                }
            } else {
                DispatchQueue.main.async {
                    self.timesheet = nil
                }
            }
        }
    }
    
    /// Save (or update) the timesheet.
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
                        self.timesheet = sharedTimesheet
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
}
