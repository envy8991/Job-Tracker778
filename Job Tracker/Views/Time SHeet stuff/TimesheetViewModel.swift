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
        let partnerComponent = partnerId ?? ""
        let docId = "\(userId)\(partnerComponent.isEmpty ? "" : "_\(partnerComponent)")_\(weekStartString(from: weekStart))"
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
    func saveTimesheet(_ timesheet: Timesheet) {
        let partnerComponent = timesheet.partnerId ?? ""
        let docId = "\(timesheet.userId)\(partnerComponent.isEmpty ? "" : "_\(partnerComponent)")_\(weekStartString(from: timesheet.weekStart))"
        do {
            try db.collection("timesheets").document(docId).setData(from: timesheet) { error in
                if let error = error {
                    print("Error saving timesheet: \(error)")
                } else {
                    print("Timesheet saved successfully.")
                }
            }
        } catch {
            print("Error encoding timesheet: \(error)")
        }
    }
    
    private func weekStartString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
