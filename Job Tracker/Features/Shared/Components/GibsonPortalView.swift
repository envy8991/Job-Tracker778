import SafariServices
import SwiftUI

struct GibsonPortalPage: Identifiable {
    let url: URL

    var id: String { url.absoluteString }

    static let login = GibsonPortalPage(url: Job.gibsonPortalLoginURL)
}

struct GibsonPortalView: View {
    let url: URL

    var body: some View {
        SafariView(url: url)
            .ignoresSafeArea()
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .done
        controller.preferredBarTintColor = UIColor.systemBackground
        controller.preferredControlTintColor = UIColor.systemBlue
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}
