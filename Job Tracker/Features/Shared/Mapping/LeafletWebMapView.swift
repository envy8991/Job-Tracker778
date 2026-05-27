import SwiftUI
import WebKit
import Combine
import CoreLocation

struct LeafletWebMapView: UIViewRepresentable {
    @ObservedObject var viewModel: FiberMapViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        configuration.userContentController.add(context.coordinator, name: Coordinator.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        context.coordinator.webView = webView

        let resourceURL = Bundle.main.url(forResource: "FiberMap", withExtension: "html", subdirectory: "WebMaps") ??
            Bundle.main.url(forResource: "FiberMap", withExtension: "html", subdirectory: "Resources/WebMaps")

        if let url = resourceURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            assertionFailure("Unable to locate FiberMap.html in bundle")
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.webView = uiView
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let messageHandlerName = "mapEvent"

        private let viewModel: FiberMapViewModel
        fileprivate weak var webView: WKWebView?
        private var cancellables: Set<AnyCancellable> = []
        private var isPageReady = false
        private let encoder: JSONEncoder

        init(viewModel: FiberMapViewModel) {
            self.viewModel = viewModel
            self.encoder = JSONEncoder()
            self.encoder.dateEncodingStrategy = .iso8601
            super.init()
            observeViewModel()
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        }

        private func observeViewModel() {
            viewModel.$poles
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sendSnapshotIfReady() }
                .store(in: &cancellables)

            viewModel.$splices
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sendSnapshotIfReady() }
                .store(in: &cancellables)

            viewModel.$lines
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sendSnapshotIfReady() }
                .store(in: &cancellables)

            viewModel.$visibleLayers
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sendVisibleLayers() }
                .store(in: &cancellables)

            viewModel.$isEditMode
                .combineLatest(viewModel.$activeTool, viewModel.$lineStartPole)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sendInteractionState() }
                .store(in: &cancellables)

            viewModel.$mapCamera
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sendInteractionState() }
                .store(in: &cancellables)

            viewModel.$pendingCenterCommand
                .receive(on: DispatchQueue.main)
                .sink { [weak self] command in
                    self?.sendCenterCommand(command)
                }
                .store(in: &cancellables)
        }

        func sendSnapshotIfReady() {
            guard isPageReady, let webView else { return }
            let snapshot = viewModel.makeWebSnapshot()
            guard let json = encode(snapshot) else { return }
            let js = "FiberBridge.handleCommand({type: 'snapshot', payload: \(json)});"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func sendInteractionState() {
            guard isPageReady, let webView else { return }
            let interaction = viewModel.makeWebInteractionState()
            guard let json = encode(interaction) else { return }
            let js = "FiberBridge.handleCommand({type: 'interaction', payload: \(json)});"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func sendVisibleLayers() {
            guard isPageReady, let webView else { return }
            let layers = viewModel.visibleLayers.map { $0.rawValue }
            guard let json = encode(layers) else { return }
            let js = "FiberBridge.handleCommand({type: 'layers', payload: \(json)});"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func sendCenterCommand(_ command: MapCenterCommand?) {
            guard isPageReady, let webView, let command else { return }
            guard let json = encode(command) else { return }
            let js = "FiberBridge.handleCommand({type: 'centerMap', payload: \(json)});"
            webView.evaluateJavaScript(js) { [weak self] _, _ in
                Task { await self?.viewModel.acknowledgeCenterCommand() }
            }
        }

        private func encode<T: Encodable>(_ value: T) -> String? {
            guard let data = try? encoder.encode(value) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            sendSnapshotIfReady()
            sendInteractionState()
        }

        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Coordinator.messageHandlerName else { return }
            guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }

            switch event {
            case "mapReady":
                isPageReady = true
                sendSnapshotIfReady()
                sendInteractionState()
                sendVisibleLayers()
                sendCenterCommand(viewModel.pendingCenterCommand)
            case "mapTapped":
                if let payload = body["payload"] as? [String: Any],
                   let lat = payload["latitude"] as? Double,
                   let lng = payload["longitude"] as? Double {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    viewModel.handleMapTap(coordinate: coordinate)
                }
            case "poleTapped":
                if let idString = (body["payload"] as? [String: Any])?["id"] as? String,
                   let uuid = UUID(uuidString: idString),
                   let pole = viewModel.poles.first(where: { $0.id == uuid }) {
                    viewModel.handlePoleTap(pole)
                }
            case "spliceTapped":
                if let idString = (body["payload"] as? [String: Any])?["id"] as? String,
                   let uuid = UUID(uuidString: idString),
                   let splice = viewModel.splices.first(where: { $0.id == uuid }) {
                    viewModel.handleSpliceTap(splice)
                }
            case "lineTapped":
                if let idString = (body["payload"] as? [String: Any])?["id"] as? String,
                   let uuid = UUID(uuidString: idString),
                   let line = viewModel.lines.first(where: { $0.id == uuid }) {
                    viewModel.handleLineTap(line)
                }
            default:
                break
            }
        }
    }
}

// MARK: - ViewModel bridging helpers
struct WebMapSnapshot: Codable {
    let poles: [WebPole]
    let splices: [WebSplice]
    let lines: [WebLine]
    let visibleLayers: [String]
}

struct WebPole: Codable {
    let id: UUID
    let name: String
    let lat: Double
    let lng: Double
    let status: String
    let installDate: Date?
    let lastInspection: Date?
    let material: String
    let notes: String
    let imageUrl: String?
}

struct WebSplice: Codable {
    let id: UUID
    let name: String
    let lat: Double
    let lng: Double
    let status: String
    let capacity: Int
    let notes: String
    let imageUrl: String?
}

struct WebLine: Codable {
    let id: UUID
    let name: String
    let startPoleId: UUID
    let endPoleId: UUID
    let status: String
    let fiberCount: Int
    let notes: String
}

struct WebInteractionState: Codable {
    struct Center: Codable {
        let latitude: Double
        let longitude: Double
        let zoom: Double?
    }

    let isEditMode: Bool
    let activeTool: String?
    let lineStartPoleId: UUID?
    let center: Center?
}

extension FiberMapViewModel {
    func makeWebSnapshot() -> WebMapSnapshot {
        WebMapSnapshot(
            poles: poles.map { pole in
                WebPole(
                    id: pole.id,
                    name: pole.name,
                    lat: pole.coordinate.latitude,
                    lng: pole.coordinate.longitude,
                    status: pole.status.rawValue,
                    installDate: pole.installDate,
                    lastInspection: pole.lastInspection,
                    material: pole.material,
                    notes: pole.notes,
                    imageUrl: pole.imageUrl
                )
            },
            splices: splices.map { splice in
                WebSplice(
                    id: splice.id,
                    name: splice.name,
                    lat: splice.coordinate.latitude,
                    lng: splice.coordinate.longitude,
                    status: splice.status.rawValue,
                    capacity: splice.capacity,
                    notes: splice.notes,
                    imageUrl: splice.imageUrl
                )
            },
            lines: lines.map { line in
                WebLine(
                    id: line.id,
                    name: "Line \(line.id.uuidString.prefix(6))",
                    startPoleId: line.startPoleId,
                    endPoleId: line.endPoleId,
                    status: line.status.rawValue,
                    fiberCount: line.fiberCount,
                    notes: line.notes
                )
            },
            visibleLayers: visibleLayers.map { $0.rawValue }
        )
    }

    func makeWebInteractionState() -> WebInteractionState {
        WebInteractionState(
            isEditMode: isEditMode,
            activeTool: activeTool?.rawValue,
            lineStartPoleId: lineStartPole?.id,
            center: WebInteractionState.Center(
                latitude: mapCamera.latitude,
                longitude: mapCamera.longitude,
                zoom: mapCamera.zoom
            )
        )
    }
}
