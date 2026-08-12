//
//  MessagesViewController.swift
//  imessage cs
//
//  Created by Quinton Thompson on 9/6/25.
//

import UIKit
import Messages

final class MessagesViewController: MSMessagesAppViewController {
    private let appGroupID = "group.com.quinton.JobTracker"
    private let jobsKey = "completedJobsToday"
    private let imagePathsKey = "completedJobImagePaths"
    private let lastSharedKey = "completedJobsLastShared"

    private lazy var titleLabel = makeLabel(font: .preferredFont(forTextStyle: .headline), color: .label)
    private lazy var statusLabel = makeLabel(font: .preferredFont(forTextStyle: .subheadline), color: .secondaryLabel)
    private lazy var jobsTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        return textView
    }()
    private lazy var sendSummaryButton = makeButton(title: "Send Summary", imageName: "paperplane.fill", action: #selector(sendSummaryTapped))
    private lazy var sendPhotosButton = makeButton(title: "Attach Photos", imageName: "photo.on.rectangle.angled", action: #selector(sendPhotosTapped))
    private lazy var refreshButton = makeButton(title: "Refresh", imageName: "arrow.clockwise", action: #selector(refreshTapped))

    private var activeConversation: MSConversation?
    private var currentSnapshot = CompletedJobsSnapshot.empty

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        refreshSnapshot()
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        activeConversation = conversation
        refreshSnapshot()
    }

    override func didResignActive(with conversation: MSConversation) {
        if activeConversation === conversation {
            activeConversation = nil
        }
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {}
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}

    // MARK: - UI

    private func configureView() {
        view.backgroundColor = .systemBackground
        view.subviews.forEach { $0.removeFromSuperview() }

        titleLabel.text = "Job Tracker"
        titleLabel.textAlignment = .center

        let buttonStack = UIStackView(arrangedSubviews: [sendSummaryButton, sendPhotosButton, refreshButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, jobsTextView, buttonStack])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            jobsTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }

    private func makeLabel(font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makeButton(title: String, imageName: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: imageName)
        configuration.imagePadding = 8
        configuration.cornerStyle = .medium

        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func refreshSnapshot() {
        currentSnapshot = CompletedJobsSnapshot.load(appGroupID: appGroupID, jobsKey: jobsKey, imagePathsKey: imagePathsKey)
        titleLabel.text = currentSnapshot.title
        statusLabel.text = currentSnapshot.statusText
        jobsTextView.text = currentSnapshot.bodyText
        sendPhotosButton.isEnabled = !currentSnapshot.imageURLs.isEmpty
    }

    // MARK: - Actions

    @objc private func sendSummaryTapped() {
        guard let conversation = activeConversation else {
            updateStatus("Open this extension inside an active conversation to share.")
            return
        }

        let layout = MSMessageTemplateLayout()
        layout.caption = currentSnapshot.title
        layout.subcaption = currentSnapshot.cardSubtitle
        layout.trailingCaption = currentSnapshot.imageCountText

        let message = MSMessage()
        message.layout = layout
        message.summaryText = currentSnapshot.summaryText

        conversation.insert(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.updateStatus("Could not insert summary: \(error.localizedDescription)")
                } else {
                    self?.rememberShare()
                    self?.updateStatus("Summary inserted. Tap send when you're ready.")
                }
            }
        }
    }

    @objc private func sendPhotosTapped() {
        guard let conversation = activeConversation else {
            updateStatus("Open this extension inside an active conversation to attach photos.")
            return
        }

        let urls = currentSnapshot.imageURLs
        guard !urls.isEmpty else {
            updateStatus("No completed-job photos are available to attach.")
            return
        }

        attachImages(urls, to: conversation, insertedCount: 0)
    }

    @objc private func refreshTapped() {
        refreshSnapshot()
        updateStatus("Updated from Job Tracker.")
    }

    private func attachImages(_ urls: [URL], to conversation: MSConversation, insertedCount: Int) {
        guard let url = urls.first else {
            rememberShare()
            updateStatus("Attached \(insertedCount) photo\(insertedCount == 1 ? "" : "s"). Tap send when you're ready.")
            return
        }

        conversation.insertAttachment(url, withAlternateFilename: url.lastPathComponent) { [weak self] error in
            DispatchQueue.main.async {
                let remaining = Array(urls.dropFirst())
                if let error {
                    self?.updateStatus("Skipped \(url.lastPathComponent): \(error.localizedDescription)")
                }
                self?.attachImages(remaining, to: conversation, insertedCount: insertedCount + (error == nil ? 1 : 0))
            }
        }
    }

    private func rememberShare() {
        UserDefaults(suiteName: appGroupID)?.set(Date(), forKey: lastSharedKey)
    }

    private func updateStatus(_ text: String) {
        statusLabel.text = text
    }
}

private struct CompletedJobsSnapshot {
    let lines: [String]
    let imageURLs: [URL]

    static let empty = CompletedJobsSnapshot(lines: [], imageURLs: [])

    var title: String {
        lines.isEmpty ? "No Completed Jobs" : "Completed Jobs (\(lines.count))"
    }

    var bodyText: String {
        lines.isEmpty ? "Finish jobs in Job Tracker, then refresh here to share today's progress." : lines.joined(separator: "\n")
    }

    var statusText: String {
        if imageURLs.isEmpty {
            return "Ready to share a summary. No photos found."
        }
        return "Ready to share a summary and \(imageCountText.lowercased())."
    }

    var cardSubtitle: String {
        lines.isEmpty ? "No completed jobs today." : lines.prefix(4).joined(separator: " • ")
    }

    var summaryText: String {
        lines.isEmpty ? "No completed jobs today." : "Completed jobs: \(lines.joined(separator: "; "))"
    }

    var imageCountText: String {
        "\(imageURLs.count) photo\(imageURLs.count == 1 ? "" : "s")"
    }

    static func load(appGroupID: String, jobsKey: String, imagePathsKey: String) -> CompletedJobsSnapshot {
        let defaults = UserDefaults(suiteName: appGroupID)
        let lines = defaults?.stringArray(forKey: jobsKey)?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
        let paths = defaults?.stringArray(forKey: imagePathsKey) ?? []
        let fileManager = FileManager.default
        let imageURLs = paths.map { URL(fileURLWithPath: $0) }.filter { fileManager.fileExists(atPath: $0.path) }
        return CompletedJobsSnapshot(lines: lines, imageURLs: imageURLs)
    }
}
