//
//  MessagesViewController.swift
//  imessage cs
//
//  Created by Quinton Thompson on 9/6/25.
//

import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController {
    private let appGroupID = "group.com.quinton.JobTracker"
    private let jobsKey = "completedJobsToday"
    private let imagePathsKey = "completedJobImagePaths"
  
    override func viewDidLoad() {
        super.viewDidLoad()
    }
  
    // MARK: - Conversation Handling
  
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        insertTodaysCompletedJobs(into: conversation)
    }
  
    // No-op overrides kept for completeness
    override func didResignActive(with conversation: MSConversation) {}
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {}
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
  
    // MARK: - Helpers
  
    private func insertTodaysCompletedJobs(into conversation: MSConversation) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let lines = defaults?.stringArray(forKey: jobsKey) ?? []
        let summaryText: String = {
            if lines.isEmpty {
                return "No completed jobs today."
            } else {
                return lines.joined(separator: "\n")
            }
        }()
  
        // Insert a templated message card first
        let layout = MSMessageTemplateLayout()
        layout.caption = "Completed Jobs"
        layout.subcaption = summaryText
        let message = MSMessage()
        message.layout = layout
        conversation.insert(message, completionHandler: nil)
  
        // Then, if any image paths are present in the app group container, attach them
        if let paths = defaults?.stringArray(forKey: imagePathsKey) {
            let fileManager = FileManager.default
            for path in paths {
                let url = URL(fileURLWithPath: path)
                // Ensure the file exists and the extension sandbox can access it (App Group container)
                if fileManager.fileExists(atPath: url.path) {
                    conversation.insertAttachment(url, withAlternateFilename: url.lastPathComponent, completionHandler: nil)
                }
            }
        }
    }
}
