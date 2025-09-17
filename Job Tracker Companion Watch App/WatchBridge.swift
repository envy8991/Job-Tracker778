//
//  WatchBridge.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//


// Watch App target → WatchBridge.swift

import Foundation
import WatchConnectivity
import Combine

final class WatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    // Latest snapshot of today’s jobs pushed from iPhone
    @Published private(set) var latestSnapshot: [WatchJob] = []

    private let isoInternet: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private let isoWithFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoDay: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private var currentUserId: String?

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    private func requestSnapshot() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        let todayISO = isoDay.string(from: Date())
        let payload: [String: Any] = [
            "type": "requestSnapshot",
            "scope": "mine",
            "statuses": ["Pending"],
            "day": todayISO,
            "ts": Date().timeIntervalSince1970
        ]
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            s.transferUserInfo(payload)
        }
    }

    // MARK: - Sending (watch → iPhone)

    func sendStatusUpdate(jobId: String, status: String) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        let payload: [String: Any] = [
            "type": "updateStatus",
            "id": jobId,
            "status": status,
            "ts": Date().timeIntervalSince1970
        ]
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            s.transferUserInfo(payload)
        }
    }

    // MARK: - Receiving (iPhone → watch)

    /// Called when the session becomes active.
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // Pull any last-known context pushed from iPhone
        let ctx = session.receivedApplicationContext
        handleApplicationContext(ctx)
        // Ask iPhone for a fresh, filtered snapshot
        requestSnapshot()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable && self.latestSnapshot.isEmpty {
            requestSnapshot()
        }
    }

    /// iPhone calls `updateApplicationContext`; we receive it here.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleApplicationContext(applicationContext)
    }

    /// iPhone can also send userInfo as a fallback.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleApplicationContext(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String, type == "jobsSnapshot" {
            handleApplicationContext(message)
        }
    }

    private func parseDate(from raw: [String: Any]) -> Date {
        if let s = raw["date"] as? String {
            if let d = isoWithFrac.date(from: s) { return d }
            if let d = isoInternet.date(from: s) { return d }
        }
        if let s = raw["dateISO"] as? String {
            if let d = isoWithFrac.date(from: s) { return d }
            if let d = isoInternet.date(from: s) { return d }
        }
        if let ts = raw["date"] as? TimeInterval { return Date(timeIntervalSince1970: ts) }
        if let ts = raw["timestamp"] as? TimeInterval { return Date(timeIntervalSince1970: ts) }
        return Date()
    }

    private func handleApplicationContext(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String, type == "jobsSnapshot",
              let items = dict["items"] as? [[String: Any]] else { return }

        // Optional: phone may include the current user id so we can filter locally
        if let me = dict["currentUserId"] as? String { self.currentUserId = me }

        let mineFiltered: [[String: Any]] = items.filter { raw in
            // Prefer explicit booleans if present
            if let mine = raw["isMine"] as? Bool { return mine }
            if let assigned = raw["assignedToMe"] as? Bool { return assigned }
            // Fall back to id matching if the phone provided ids
            if let me = self.currentUserId {
                if let owner = raw["ownerId"] as? String, owner == me { return true }
                if let assignees = raw["assigneeIds"] as? [String], assignees.contains(me) { return true }
                return false
            }
            // If we don't know the user, accept (the watch VM will still filter status/date)
            return true
        }

        let jobs: [WatchJob] = mineFiltered.compactMap { raw in
            guard let id = raw["id"] as? String,
                  let address = raw["address"] as? String else { return nil }
            let date = parseDate(from: raw)
            let jobNumber = raw["jobNumber"] as? String
            let status = raw["status"] as? String
            return WatchJob(id: id, address: address, date: date, jobNumber: jobNumber, status: status)
        }

        DispatchQueue.main.async { [jobs] in
            self.latestSnapshot = jobs
        }
    }
}
