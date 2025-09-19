//
//  DeepLinkRouter.swift
//  Job Tracker
//

import Foundation
import SwiftUI

enum DeepLinkRouter {
    static func handle(_ url: URL) {
        #if DEBUG
        print("[DeepLink] Received URL: \(url.absoluteString)")
        #endif

        guard url.scheme?.lowercased() == "jobtracker" else {
            #if DEBUG
            print("[DeepLink] Ignored non-jobtracker scheme: \(url.scheme ?? "nil")")
            #endif
            return
        }

        // Accept both forms:
        // jobtracker://importJob?token=XYZ  (host = "importJob")
        // jobtracker:/importJob?token=XYZ   (host = nil, path = "/importJob")
        let host = url.host?.lowercased()
        let path = url.path.lowercased()
        let isImport = (host == "importjob") || path.hasSuffix("/importjob")

        guard isImport else {
            #if DEBUG
            print("[DeepLink] Unknown route. host=\(host ?? "nil"), path=\(path)")
            #endif
            return
        }

        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "token" })?
            .value

        guard let token, !token.isEmpty else {
            #if DEBUG
            print("[DeepLink] Missing token query param")
            #endif
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .jobImportFailed,
                    object: NSError(
                        domain: "DeepLink",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Missing token"]
                    )
                )
            }
            return
        }

        Task {
            do {
                #if DEBUG
                print("[DeepLink] Importing token: \(token)")
                #endif
                _ = try await SharedJobService.shared.importJob(using: token)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .jobImportSucceeded, object: nil)
                }
            } catch {
                #if DEBUG
                print("[DeepLink] Import failed: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .jobImportFailed, object: error)
                }
            }
        }
    }
}

extension Notification.Name {
    static let jobImportSucceeded = Notification.Name("jobImportSucceeded")
    static let jobImportFailed = Notification.Name("jobImportFailed")
}
