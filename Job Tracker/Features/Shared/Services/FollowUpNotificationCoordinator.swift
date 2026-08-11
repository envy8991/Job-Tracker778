import Foundation
import UserNotifications

/// Reconciles local reminders from Firestore state. A stable job-based identifier makes
/// repeated snapshots and edits replace the existing request rather than duplicate it.
final class FollowUpNotificationCoordinator {
    static let shared = FollowUpNotificationCoordinator()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func synchronize(job: Job) {
        let identifier = "job-follow-up-\(job.id)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let followUp = job.followUp,
              !followUp.isCompleted,
              followUp.notificationPreference == .dueDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "Job follow-up due"
        content.body = "\(job.shortAddress): \(followUp.reason)"
        content.sound = .default
        content.userInfo = ["jobID": job.id, "followUpUpdatedAt": followUp.updatedAt.timeIntervalSince1970]
        let components = Calendar.current.dateComponents([.year, .month, .day], from: followUp.dueDate)
        center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }
}
