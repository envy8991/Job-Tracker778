//
//  DeepLinkRouter.swift
//  Job Tracker
//

import Foundation

enum DeepLinkRoute: Equatable {
    case dashboard
    case job(id: String)
    case importJob(token: String)
}

enum DeepLinkRouter {
    static func handle(_ url: URL) -> DeepLinkRoute? {
        #if DEBUG
        print("[DeepLink] Received URL: \(url.absoluteString)")
        #endif

        guard url.scheme?.lowercased() == "jobtracker" else {
            #if DEBUG
            print("[DeepLink] Ignored non-jobtracker scheme: \(url.scheme ?? "nil")")
            #endif
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            #if DEBUG
            print("[DeepLink] Failed to parse URL components")
            #endif
            return nil
        }

        // Accept variations such as:
        // jobtracker://importJob?token=XYZ  (host = "importJob")
        // jobtracker:/importJob?token=XYZ   (no host, path = "/importJob")
        // jobtracker:importJob?token=XYZ    (no host, path = "importJob")
        let host = (components.host ?? url.host)?.lowercased()
        let pathSegments = components.path
            .split(separator: "/")
            .map { $0.lowercased() }
        let lastSegment = pathSegments.last
        let isDashboard = (host == "dashboard") || (lastSegment == "dashboard")
        if isDashboard { return .dashboard }

        let isJob = (host == "job") || (lastSegment == "job")
        if isJob,
           let id = components.queryItems?.first(where: { $0.name.lowercased() == "id" })?.value,
           !id.isEmpty {
            return .job(id: id)
        }

        let isImport = (host == "importjob") || (lastSegment == "importjob")

        guard isImport else {
            #if DEBUG
            print("[DeepLink] Unknown route. host=\(host ?? "nil"), path=\(url.path)")
            #endif
            return nil
        }

        let token = components
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
            return nil
        }

        return .importJob(token: token)
    }
}

extension Notification.Name {
    static let jobImportSucceeded = Notification.Name("jobImportSucceeded")
    static let jobImportFailed = Notification.Name("jobImportFailed")
}
