import SwiftUI
import PDFKit
import Foundation   // for CharacterSet

// MARK: - Address Helper
/// Returns house number + street name (up to the first street-type word or comma).
private func houseNumberAndStreet(from fullAddress: String) -> String {
    // 1. If there is a comma, everything before it is already just street.
    if let comma = fullAddress.firstIndex(of: ",") {
        return String(fullAddress[..<comma]).trimmingCharacters(in: .whitespaces)
    }
    
    // 2. Otherwise, keep tokens until we hit a known street suffix or run out.
    let suffixes: Set<String> = [
        "st", "street", "rd", "road", "ave", "avenue",
        "blvd", "circle", "cir", "ln", "lane", "dr", "drive",
        "ct", "court", "pkwy", "pl", "place", "ter", "terrace"
    ]
    
    var resultTokens: [Substring] = []
    for token in fullAddress.split(separator: " ") {
        resultTokens.append(token)
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",.")).lowercased()
        if suffixes.contains(cleaned) {
            break   // stop once we've captured the full street name
        }
    }
    return resultTokens.joined(separator: " ")
}

// MARK: - PDFKitView
struct PDFKitView: UIViewRepresentable {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let url: URL
    @Binding private var loadingState: LoadingState

    init(url: URL, loadingState: Binding<LoadingState> = .constant(.idle)) {
        self.url = url
        self._loadingState = loadingState
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        let coordinator = context.coordinator

        if coordinator.activeURL == url {
            if coordinator.downloadTask != nil || coordinator.isFinished {
                return
            }
        }

        coordinator.prepareForNewLoad(with: url)
        loadingState = .loading
        uiView.document = nil

        if url.isFileURL {
            loadLocalPDF(into: uiView, coordinator: coordinator)
        } else {
            loadRemotePDF(into: uiView, coordinator: coordinator)
        }
    }

    private func loadLocalPDF(into pdfView: PDFView, coordinator: Coordinator) {
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            pdfView.autoScales = true
            loadingState = .loaded
        } else {
            loadingState = .failed("Unable to open PDF file.")
        }
        coordinator.isFinished = true
    }

    private func loadRemotePDF(into pdfView: PDFView, coordinator: Coordinator) {
        coordinator.downloadTask = URLSession.shared.downloadTask(with: url) { [weak pdfViewRef = pdfView] tempURL, _, error in
            guard let pdfView = pdfViewRef else { return }

            if let error = error {
                DispatchQueue.main.async {
                    if coordinator.activeURL == url {
                        coordinator.isFinished = true
                        coordinator.downloadTask = nil
                        pdfView.document = nil
                        loadingState = .failed(error.localizedDescription)
                    }
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    if coordinator.activeURL == url {
                        coordinator.isFinished = true
                        coordinator.downloadTask = nil
                        pdfView.document = nil
                        loadingState = .failed("No PDF data received.")
                    }
                }
                return
            }

            do {
                let data = try Data(contentsOf: tempURL)
                guard let document = PDFDocument(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }

                DispatchQueue.main.async {
                    if coordinator.activeURL == url {
                        coordinator.isFinished = true
                        coordinator.downloadTask = nil
                        pdfView.document = document
                        pdfView.autoScales = true
                        loadingState = .loaded
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if coordinator.activeURL == url {
                        coordinator.isFinished = true
                        coordinator.downloadTask = nil
                        pdfView.document = nil
                        loadingState = .failed(error.localizedDescription)
                    }
                }
            }
        }

        coordinator.downloadTask?.resume()
    }

    // MARK: Coordinator
    final class Coordinator {
        var activeURL: URL?
        var downloadTask: URLSessionDownloadTask?
        var isFinished = false

        func prepareForNewLoad(with url: URL) {
            if activeURL != url {
                cancelOngoingLoad()
            }

            activeURL = url
            isFinished = false
        }

        func cancelOngoingLoad() {
            downloadTask?.cancel()
            downloadTask = nil
        }
    }
}

// MARK: - PDFViewer (wrapper for navigation)
struct PDFViewer: View {
    let url: URL
    
    @State private var loadingState: PDFKitView.LoadingState = .loading

    var body: some View {
        ZStack {
            PDFKitView(url: url, loadingState: $loadingState)
            overlayView
        }
        .navigationTitle("PDF Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: url) { _ in
            loadingState = .loading
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch loadingState {
        case .idle, .loaded:
            EmptyView()
        case .loading:
            ProgressView("Loading PDF…")
                .padding(16)
                .background(overlayBackground)
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                Text("Unable to load PDF")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding(16)
            .background(overlayBackground)
            .padding()
        }
    }

    private var overlayBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.systemBackground).opacity(0.9))
            .shadow(radius: 4)
    }
}
