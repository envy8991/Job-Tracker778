//
//  PhoneWatchSyncManager.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//

import Foundation
import WatchConnectivity
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// iOS-only: pushes *today's* dashboard jobs (Pending & mine) to the watch whenever they change.
final class PhoneWatchSyncManager: NSObject {
    static let shared = PhoneWatchSyncManager()

    private weak var jobsVM: JobsViewModel?
    private var cancellables = Set<AnyCancellable>()
    private let iso = ISO8601DateFormatter()

    // Who am I? (pull from your existing FirebaseService helper)
    private func currentUserId() -> String? {
        FirebaseService.shared.currentUserID()
    }

    // MARK: Public API
    func configure(jobsViewModel: JobsViewModel) {
        self.jobsVM = jobsViewModel
        startSession()

        // Push once on launch
        pushSnapshotToWatch()

        // 1) React to model changes via Combine (main-thread guaranteed)
        jobsViewModel.$jobs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.pushSnapshotToWatch() }
            .store(in: &cancellables)

        // 2) Also listen for explicit broadcast (kept for compatibility)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jobsDidChange),
            name: .jobsDidChange,
            object: nil
        )

        // 3) Refresh when app returns to foreground (iOS only)
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pushSnapshotToWatch()
        }
        #endif
    }

    /// Manually trigger a push (e.g., from a debug button)
    func pushSnapshotToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let items = buildSnapshotItems()
        var context: [String: Any] = [
            "type": "jobsSnapshot",
            "items": items,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let me = currentUserId() {
            context["currentUserId"] = me
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            // Fallback if context can’t be updated right now
            session.transferUserInfo(context)
        }
    }

    /// Builds a compact payload of today's jobs with fields the watch expects.
    /// Filters to: (createdBy == me || assignedTo == me) AND status == "Pending" AND date == today
    private func buildSnapshotItems() -> [[String: Any]] {
        guard let source = jobsVM?.jobs else { return [] }
        guard let me = currentUserId() else { return [] }

        let today = Date()
        let cal = Calendar.current

        let todaysMinePending = source.filter { job in
            let mine = (job.createdBy == me) || (job.assignedTo == me)
            guard mine else { return false }
            let statusOK = job.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "pending"
            guard statusOK else { return false }
            return cal.isDate(job.date, inSameDayAs: today)
        }

        return todaysMinePending.prefix(50).map { job in
            var out: [String: Any] = [
                "id": job.id,
                "address": job.address,
                "jobNumber": job.jobNumber ?? "",
                "isMine": true,
                "status": job.status,
                "date": iso.string(from: job.date)
            ]
            if let owner = job.createdBy { out["ownerId"] = owner }
            if let assignee = job.assignedTo { out["assigneeIds"] = [assignee] }
            return out
        }
    }
}

// MARK: - Internals
extension PhoneWatchSyncManager: WCSessionDelegate {
    fileprivate func startSession() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    @objc fileprivate func jobsDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.pushSnapshotToWatch()
        }
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if error == nil {
            pushSnapshotToWatch()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { pushSnapshotToWatch() }
    }

    // Required on iOS for full conformance when a new watch is paired, etc.
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    // Handle watch messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Watch asking for a fresh snapshot with filters
        if let type = message["type"] as? String, type == "requestSnapshot" {
            DispatchQueue.main.async { [weak self] in
                self?.pushSnapshotToWatch()
            }
            return
        }
        // Example: ["type":"updateStatus","id":"…","status":"…"]
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("watchRequestedStatusUpdate"),
                object: nil,
                userInfo: message
            )
        }
    }
}


extension Notification.Name {
    static let watchRequestedStatusUpdate = Notification.Name("watchRequestedStatusUpdate")
}
