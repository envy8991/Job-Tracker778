
//
//  ActivityView.swift
//  Job Tracker
//
//  A robust SwiftUI wrapper around UIActivityViewController that avoids the
//  “blank sheet on first open” race by presenting on the next runloop and,
//  if needed, retrying once with a short delay. It also inserts a safe
//  UIActivityItemSource first so the controller always has at least one
//  stable item while it inspects the rest.
//
//  Created by ChatGPT on 9/6/2025.
//

import SwiftUI
import UIKit

// MARK: - Safe item source
fileprivate final class SafeActivityItemSource: NSObject, UIActivityItemSource {
    private let items: [Any]
    private let subject: String?

    init(items: [Any], subject: String?) {
        self.items = items
        self.subject = subject
        super.init()
    }

    // A quick placeholder so the system can size the sheet immediately.
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return " "
    }

    // Provide the first real item when asked for a specific activity.
    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return items.first
    }

    // Provide an optional subject (used by Mail).
    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return subject ?? ""
    }
}

// MARK: - UIKit container that owns presentation timing
final class ShareContainerViewController: UIViewController {
    private func sanitizedItems(_ items: [Any]) -> [Any] {
        var out: [Any] = []
        for it in items {
            switch it {
            case let s as String:
                if !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(s) }
            case let url as URL:
                out.append(url)
            case let img as UIImage:
                out.append(img)
            case let data as Data:
                if let img = UIImage(data: data) { out.append(img) }
            case let src as UIActivityItemSource:
                out.append(src)
            default:
                break
            }
        }
        return out
    }
    var items: [Any] = []
    var excluded: [UIActivity.ActivityType]? = nil
    var subject: String? = nil
    var onComplete: ((Bool) -> Void)? = nil

    private var hasAttemptedPresentation = false
    private weak var presentedActivityVC: UIActivityViewController?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentIfNeeded()
    }

    private func presentIfNeeded() {
        guard !hasAttemptedPresentation, presentedViewController == nil else { return }
        hasAttemptedPresentation = true

        // Sanitize the items before sharing.
        let cleaned = sanitizedItems(self.items)
        // Build a safe items array: start with a SafeActivityItemSource then append user items.
        let safeSource = SafeActivityItemSource(items: cleaned.isEmpty ? [""] : cleaned, subject: subject)
        var activityItems: [Any] = [safeSource]
        activityItems.append(contentsOf: cleaned)

        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = excluded
        if let subject = subject {
            // Private key used by Mail to set the subject
            controller.setValue(subject, forKey: "subject")
        }
        controller.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            self?.onComplete?(completed)
            self?.dismiss(animated: true)
        }

        // iPad popover anchoring: use our own view center
        if let pop = controller.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }

        // Present on the next runloop to avoid SwiftUI state-change races.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.presentedViewController == nil else { return }
            self.present(controller, animated: true)

            // After a short delay, verify it's actually visible; if the system invalidated it,
            // retry once with a slightly longer delay.
            self.verifyAndRetryIfNeeded(controller: controller, attempt: 1)
        }
        presentedActivityVC = controller
    }

    private func verifyAndRetryIfNeeded(controller: UIActivityViewController, attempt: Int) {
        let delay: TimeInterval = attempt == 1 ? 0.30 : 0.60
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let visible = (self.presentedViewController as? UIActivityViewController) != nil
            if !visible {
                if attempt < 2 {
                    self.hasAttemptedPresentation = false
                    self.presentedActivityVC?.dismiss(animated: false)
                    self.dismiss(animated: false) { [weak self] in
                        self?.presentIfNeeded()
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI wrapper
struct ActivityView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ShareContainerViewController
    /// Items to share. Supports typical types: String, URL, UIImage, Data (image),
    /// and custom UIActivityItemSource objects.
    var activityItems: [Any]

    /// Optionally exclude certain activities.
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    /// Optional subject (used by Mail).
    var subject: String? = nil

    /// Optional completion callback (completed == true if the user finished an activity).
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> ShareContainerViewController {
        let vc = ShareContainerViewController()
        vc.view.backgroundColor = .clear
        vc.items = activityItems
        vc.excluded = excludedActivityTypes
        vc.subject = subject
        vc.onComplete = onComplete
        return vc
    }

    func updateUIViewController(_ uiViewController: ShareContainerViewController, context: Context) {
        // If SwiftUI reuses the container while the sheet is not yet presented,
        // keep the latest data ready for presentation.
        uiViewController.items = activityItems
        uiViewController.excluded = excludedActivityTypes
        uiViewController.subject = subject
        uiViewController.onComplete = onComplete
    }
}
