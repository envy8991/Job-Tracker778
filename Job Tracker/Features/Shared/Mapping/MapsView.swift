//  MapsView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 4/30/25.
//  Updated: Rebuilt with native SwiftUI mapping controls and structured asset models.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - Shared Asset Types
enum AssetStatus: String, CaseIterable, Identifiable {
    case planned
    case active
    case maintenance
    case retired

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .active: return "Active"
        case .maintenance: return "Maintenance"
        case .retired: return "Retired"
        }
    }

    var tint: Color {
        switch self {
        case .planned: return .blue
        case .active: return .green
        case .maintenance: return .orange
        case .retired: return .gray
        }
    }

    var annotationTint: UIColor {
        switch self {
        case .planned: return .systemBlue
        case .active: return .systemGreen
        case .maintenance: return .systemOrange
        case .retired: return .systemGray
        }
    }
}

struct Pole: Identifiable, Hashable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var status: AssetStatus
    var capacity: Int
    var notes: String

    init(id: UUID = UUID(),
         name: String = "",
         coordinate: CLLocationCoordinate2D,
         status: AssetStatus = .planned,
         capacity: Int = 1,
         notes: String = "") {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.status = status
        self.capacity = capacity
        self.notes = notes
    }
}

extension Pole {
    static func == (lhs: Pole, rhs: Pole) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SpliceEnclosure: Identifiable, Hashable {
    let id: UUID
    var label: String
    var coordinate: CLLocationCoordinate2D
    var status: AssetStatus
    var capacity: Int
    var notes: String

    init(id: UUID = UUID(),
         label: String = "",
         coordinate: CLLocationCoordinate2D,
         status: AssetStatus = .planned,
         capacity: Int = 12,
         notes: String = "") {
        self.id = id
        self.label = label
        self.coordinate = coordinate
        self.status = status
        self.capacity = capacity
        self.notes = notes
    }
}

extension SpliceEnclosure {
    static func == (lhs: SpliceEnclosure, rhs: SpliceEnclosure) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum AssetReference: Hashable, Identifiable {
    case pole(Pole.ID)
    case splice(SpliceEnclosure.ID)

    var id: String {
        switch self {
        case .pole(let id):
            return "pole-\(id.uuidString)"
        case .splice(let id):
            return "splice-\(id.uuidString)"
        }
    }
}

struct FiberLine: Identifiable, Hashable {
    let id: UUID
    var name: String
    var status: AssetStatus
    var capacity: Int
    var path: [CLLocationCoordinate2D]
    var endpoints: [AssetReference]

    init(id: UUID = UUID(),
         name: String = "",
         status: AssetStatus = .planned,
         capacity: Int = 12,
         path: [CLLocationCoordinate2D],
         endpoints: [AssetReference] = []) {
        self.id = id
        self.name = name
        self.status = status
        self.capacity = capacity
        self.path = path
        self.endpoints = endpoints
    }
}

extension FiberLine {
    static func == (lhs: FiberLine, rhs: FiberLine) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - UI Helpers
enum SelectedAsset: Hashable, Identifiable {
    case pole(Pole.ID)
    case splice(SpliceEnclosure.ID)
    case fiber(FiberLine.ID)

    var id: String {
        switch self {
        case .pole(let id):
            return "selected-pole-\(id.uuidString)"
        case .splice(let id):
            return "selected-splice-\(id.uuidString)"
        case .fiber(let id):
            return "selected-fiber-\(id.uuidString)"
        }
    }
}

enum MapLayer: String, CaseIterable, Identifiable {
    case poles
    case splices
    case fiber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .poles: return "Poles"
        case .splices: return "Splice Enclosures"
        case .fiber: return "Fiber"
        }
    }
}

enum EditTool: String, CaseIterable, Identifiable {
    case addPole
    case addSplice
    case drawLine
    case delete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .addPole: return "Add Pole"
        case .addSplice: return "Add Splice"
        case .drawLine: return "Draw Line"
        case .delete: return "Delete"
        }
    }

    var systemImage: String {
        switch self {
        case .addPole: return "mappin.and.ellipse"
        case .addSplice: return "square.stack.3d.up"
        case .drawLine: return "pencil"
        case .delete: return "trash"
        }
    }
}

struct PoleDraft: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var name: String = ""
    var status: AssetStatus = .planned
    var capacity: Int = 1
    var notes: String = ""
}

struct SpliceDraft: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var label: String = ""
    var status: AssetStatus = .planned
    var capacity: Int = 12
    var notes: String = ""
}

struct LineDraft: Identifiable {
    let id = UUID()
    var points: [CLLocationCoordinate2D]
    var name: String = ""
    var status: AssetStatus = .planned
    var capacity: Int = 12
    var startEndpoint: AssetReference? = nil
    var endEndpoint: AssetReference? = nil
    var notes: String = ""
}

struct MapFocusRequest: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let span: MKCoordinateSpan
}

extension MapFocusRequest: Equatable {
    static func == (lhs: MapFocusRequest, rhs: MapFocusRequest) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}

private extension CLLocationCoordinate2D {
    static let defaultCenter = CLLocationCoordinate2D(latitude: 35.9800, longitude: -88.9400)
}

// MARK: - View Model
final class RouteMapperViewModel: ObservableObject {
    @Published var enabledLayers: Set<MapLayer> = Set(MapLayer.allCases)
    @Published var isEditMode = false {
        didSet {
            guard !isEditMode else { return }
            activeTool = nil
            pendingLinePoints.removeAll()
        }
    }
    @Published var activeTool: EditTool? = nil {
        didSet {
            if activeTool != .drawLine {
                pendingLinePoints.removeAll()
            }
        }
    }
    @Published var poles: [Pole] = []
    @Published var splices: [SpliceEnclosure] = []
    @Published var fiberLines: [FiberLine] = []
    @Published var selectedAsset: SelectedAsset? {
        didSet {
            guard let selection = selectedAsset, selection != oldValue else { return }
            focus(on: selection)
        }
    }
    @Published var pendingLinePoints: [CLLocationCoordinate2D] = []
    @Published var poleDraft: PoleDraft? = nil
    @Published var spliceDraft: SpliceDraft? = nil
    @Published var lineDraft: LineDraft? = nil
    @Published private(set) var focusRequest: MapFocusRequest? = nil

    private let focusSpan = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)

    var shouldCaptureMapTap: Bool {
        guard isEditMode, let tool = activeTool else { return false }
        switch tool {
        case .addPole, .addSplice, .drawLine, .delete:
            return true
        }
    }

    var toolInstruction: String? {
        guard isEditMode else { return nil }
        switch activeTool {
        case nil:
            return "Select a tool to start editing."
        case .addPole?:
            return "Tap anywhere on the map to drop a new pole."
        case .addSplice?:
            return "Tap anywhere on the map to place a splice enclosure."
        case .drawLine?:
            return pendingLinePoints.isEmpty ? "Tap the map to set the first point of the fiber line." : "Tap again to set the end of the fiber line."
        case .delete?:
            return "Tap an asset to remove it from the map."
        }
    }

    func toggle(layer: MapLayer, isEnabled: Bool) {
        if isEnabled {
            enabledLayers.insert(layer)
        } else {
            enabledLayers.remove(layer)
        }
    }

    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        guard isEditMode, let tool = activeTool else { return }
        switch tool {
        case .addPole:
            poleDraft = PoleDraft(coordinate: coordinate)
        case .addSplice:
            spliceDraft = SpliceDraft(coordinate: coordinate)
        case .drawLine:
            pendingLinePoints.append(coordinate)
            presentLineDraftIfNeeded()
        case .delete:
            deleteNearestAsset(to: coordinate)
        }
    }

    func beginLineDrawing(at coordinate: CLLocationCoordinate2D) {
        guard isEditMode, activeTool == .drawLine else { return }
        pendingLinePoints = [coordinate]
    }

    func finishLineDrawing(at coordinate: CLLocationCoordinate2D) {
        guard isEditMode, activeTool == .drawLine else { return }
        if pendingLinePoints.isEmpty {
            pendingLinePoints.append(coordinate)
        } else {
            pendingLinePoints.append(coordinate)
        }
        presentLineDraftIfNeeded()
    }

    func handlePoleTap(_ pole: Pole) {
        if isEditMode, activeTool == .delete {
            removePole(with: pole.id)
        } else {
            selectedAsset = .pole(pole.id)
        }
    }

    func handleSpliceTap(_ splice: SpliceEnclosure) {
        if isEditMode, activeTool == .delete {
            removeSplice(with: splice.id)
        } else {
            selectedAsset = .splice(splice.id)
        }
    }

    func handleFiberTap(_ line: FiberLine) {
        selectedAsset = .fiber(line.id)
    }

    func addPole(from draft: PoleDraft) {
        let pole = Pole(
            name: draft.name,
            coordinate: draft.coordinate,
            status: draft.status,
            capacity: draft.capacity,
            notes: draft.notes
        )
        poles.append(pole)
        poleDraft = nil
        selectedAsset = .pole(pole.id)
    }

    func addSplice(from draft: SpliceDraft) {
        let splice = SpliceEnclosure(
            label: draft.label,
            coordinate: draft.coordinate,
            status: draft.status,
            capacity: draft.capacity,
            notes: draft.notes
        )
        splices.append(splice)
        spliceDraft = nil
        selectedAsset = .splice(splice.id)
    }

    func addFiberLine(from draft: LineDraft) {
        guard draft.points.count >= 2 else { return }
        let endpoints = [draft.startEndpoint, draft.endEndpoint].compactMap { $0 }
        let line = FiberLine(
            name: draft.name,
            status: draft.status,
            capacity: draft.capacity,
            path: draft.points,
            endpoints: endpoints
        )
        fiberLines.append(line)
        lineDraft = nil
        selectedAsset = .fiber(line.id)
    }

    func cancelPoleDraft() {
        poleDraft = nil
    }

    func cancelSpliceDraft() {
        spliceDraft = nil
    }

    func cancelLineDraft() {
        pendingLinePoints.removeAll()
        lineDraft = nil
    }

    func consumeFocusRequest(_ id: MapFocusRequest.ID) {
        if focusRequest?.id == id {
            focusRequest = nil
        }
    }

    func endpointOptions() -> [AssetReference] {
        let poleRefs = poles.map { AssetReference.pole($0.id) }
        let spliceRefs = splices.map { AssetReference.splice($0.id) }
        return poleRefs + spliceRefs
    }

    func endpointLabel(for reference: AssetReference) -> String {
        switch reference {
        case .pole(let id):
            if let name = poles.first(where: { $0.id == id })?.name,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            return "Pole"
        case .splice(let id):
            if let label = splices.first(where: { $0.id == id })?.label,
               !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return label
            }
            return "Splice"
        }
    }

    // MARK: - Private Helpers
    private func presentLineDraftIfNeeded() {
        guard pendingLinePoints.count >= 2 else { return }
        let points = pendingLinePoints
        pendingLinePoints.removeAll()
        lineDraft = LineDraft(points: points)
    }

    private func deleteNearestAsset(to coordinate: CLLocationCoordinate2D) {
        let targetPoint = MKMapPoint(coordinate)
        let threshold: Double = 40 // meters

        if let pole = poles.min(by: { MKMapPoint($0.coordinate).distance(to: targetPoint) < MKMapPoint($1.coordinate).distance(to: targetPoint) }),
           MKMapPoint(pole.coordinate).distance(to: targetPoint) < threshold {
            removePole(with: pole.id)
            return
        }

        if let splice = splices.min(by: { MKMapPoint($0.coordinate).distance(to: targetPoint) < MKMapPoint($1.coordinate).distance(to: targetPoint) }),
           MKMapPoint(splice.coordinate).distance(to: targetPoint) < threshold {
            removeSplice(with: splice.id)
            return
        }

        if let (index, line) = fiberLines.enumerated().min(by: { lineDistance(from: coordinate, to: $0.element.path) < lineDistance(from: coordinate, to: $1.element.path) }),
           lineDistance(from: coordinate, to: line.path) < threshold {
            fiberLines.remove(at: index)
            if case .fiber(let id)? = selectedAsset, id == line.id {
                selectedAsset = nil
            }
        }
    }

    private func removePole(with id: Pole.ID) {
        poles.removeAll { $0.id == id }
        if case .pole(let selectedID)? = selectedAsset, selectedID == id {
            selectedAsset = nil
        }
    }

    private func removeSplice(with id: SpliceEnclosure.ID) {
        splices.removeAll { $0.id == id }
        if case .splice(let selectedID)? = selectedAsset, selectedID == id {
            selectedAsset = nil
        }
    }

    private func lineDistance(from coordinate: CLLocationCoordinate2D, to path: [CLLocationCoordinate2D]) -> Double {
        guard path.count >= 2 else { return .infinity }
        var minDistance = Double.infinity
        let targetPoint = MKMapPoint(coordinate)
        for idx in 1..<path.count {
            let a = MKMapPoint(path[idx - 1])
            let b = MKMapPoint(path[idx])
            let distance = targetPoint.distance(toLineSegmentBetween: a, and: b)
            minDistance = min(minDistance, distance)
        }
        return minDistance
    }

    private func focus(on selection: SelectedAsset) {
        switch selection {
        case .pole(let id):
            guard let pole = poles.first(where: { $0.id == id }) else { return }
            focus(on: pole.coordinate)
        case .splice(let id):
            guard let splice = splices.first(where: { $0.id == id }) else { return }
            focus(on: splice.coordinate)
        case .fiber(let id):
            guard let line = fiberLines.first(where: { $0.id == id }) else { return }
            focus(onLine: line)
        }
    }

    private func focus(on coordinate: CLLocationCoordinate2D) {
        focusRequest = MapFocusRequest(coordinate: coordinate, span: focusSpan)
    }

    private func focus(onLine line: FiberLine) {
        guard let center = midpoint(of: line.path) else { return }
        focusRequest = MapFocusRequest(coordinate: center, span: focusSpan)
    }

    private func midpoint(of coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }
        let total = coordinates.reduce(into: (lat: 0.0, lon: 0.0)) { partialResult, value in
            partialResult.lat += value.latitude
            partialResult.lon += value.longitude
        }
        let count = Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: total.lat / count, longitude: total.lon / count)
    }
}

// MARK: - Maps View
struct MapsView: View {
    @StateObject private var viewModel = RouteMapperViewModel()

    var body: some View {
        if #available(iOS 17.0, *) {
            MapsViewiOS17(viewModel: viewModel)
        } else {
            LegacyMapsView(viewModel: viewModel)
        }
    }
}

@available(iOS 17.0, *)
private struct MapsViewiOS17: View {
    @ObservedObject var viewModel: RouteMapperViewModel

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: .defaultCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    @State private var isSidebarCollapsed = false

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                ZStack(alignment: .leading) {
                    mapLayer(proxy: proxy)
                        .overlay(alignment: .bottom) {
                            if let instruction = viewModel.toolInstruction {
                                Text(instruction)
                                    .font(.footnote)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .padding(.bottom, 24)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            RouteMapperToolPicker(viewModel: viewModel)
                                .padding(.top, 16)
                                .padding(.trailing, 16)
                        }

                    RouteMapperSidebar(viewModel: viewModel)
                        .frame(maxHeight: .infinity)
                        .frame(width: isSidebarCollapsed ? 0 : 300)
                        .clipped()
                        .background {
                            if isSidebarCollapsed {
                                Color.clear
                            } else {
                                Rectangle().fill(.regularMaterial)
                            }
                        }
                        .shadow(radius: isSidebarCollapsed ? 0 : 8)
                        .animation(.easeInOut(duration: 0.2), value: isSidebarCollapsed)

                    sidebarToggleButton
                        .padding(.leading, isSidebarCollapsed ? 12 : 312)
                        .padding(.top, 16)
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Network Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $viewModel.isEditMode) {
                        Text("Edit Mode")
                    }
                    .toggleStyle(SwitchToggleStyle())
                }
            }
        }
        .sheet(item: $viewModel.poleDraft) { draft in
            PoleFormView(draft: draft) { updated in
                viewModel.addPole(from: updated)
            } onCancel: {
                viewModel.cancelPoleDraft()
            }
        }
        .sheet(item: $viewModel.spliceDraft) { draft in
            SpliceFormView(draft: draft) { updated in
                viewModel.addSplice(from: updated)
            } onCancel: {
                viewModel.cancelSpliceDraft()
            }
        }
        .sheet(item: $viewModel.lineDraft) { draft in
            LineFormView(
                draft: draft,
                endpointOptions: viewModel.endpointOptions(),
                endpointLabelProvider: viewModel.endpointLabel(for:)
            ) { updated in
                viewModel.addFiberLine(from: updated)
            } onCancel: {
                viewModel.cancelLineDraft()
            }
        }
        .onReceive(viewModel.$focusRequest.compactMap { $0 }) { request in
            cameraPosition = .region(MKCoordinateRegion(center: request.coordinate, span: request.span))
            viewModel.consumeFocusRequest(request.id)
        }
    }

    private func mapLayer(proxy: MapProxy) -> some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            if viewModel.enabledLayers.contains(.poles) {
                ForEach(viewModel.poles) { pole in
                    Annotation(
                        pole.name.isEmpty ? "Pole" : pole.name,
                        coordinate: pole.coordinate
                    ) {
                        assetPin(
                            color: pole.status.tint,
                            systemName: "bolt.fill",
                            label: pole.name.isEmpty ? "Pole" : pole.name
                        ) {
                            viewModel.handlePoleTap(pole)
                        }
                    }
                }
            }

            if viewModel.enabledLayers.contains(.splices) {
                ForEach(viewModel.splices) { splice in
                    Annotation(
                        splice.label.isEmpty ? "Splice" : splice.label,
                        coordinate: splice.coordinate
                    ) {
                        assetPin(
                            color: splice.status.tint,
                            systemName: "square.stack.3d.up.fill",
                            label: splice.label.isEmpty ? "Splice" : splice.label
                        ) {
                            viewModel.handleSpliceTap(splice)
                        }
                    }
                }
            }

            if viewModel.enabledLayers.contains(.fiber) {
                ForEach(viewModel.fiberLines) { line in
                    MapPolyline(coordinates: line.path)
                        .stroke(line.status.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .center) {
            if viewModel.shouldCaptureMapTap {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard viewModel.shouldCaptureMapTap,
                                      let coordinate = proxy.convert(value.location, from: .local) else { return }
                                viewModel.handleMapTap(at: coordinate)
                            }
                    )
            }
        }
    }

    private var sidebarToggleButton: some View {
        Button {
            isSidebarCollapsed.toggle()
        } label: {
            Image(systemName: isSidebarCollapsed ? "sidebar.leading" : "sidebar.trailing")
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func assetPin(color: Color, systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .symbolVariant(.fill)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(color, in: Circle())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LegacyMapsView: View {
    @ObservedObject var viewModel: RouteMapperViewModel

    @State private var mapRegion = MKCoordinateRegion(
        center: .defaultCenter,
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var isSidebarCollapsed = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                RouteMapperMapView(viewModel: viewModel, region: $mapRegion)
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        if let instruction = viewModel.toolInstruction {
                            Text(instruction)
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(.bottom, 24)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        RouteMapperToolPicker(viewModel: viewModel)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }

                RouteMapperSidebar(viewModel: viewModel)
                    .frame(maxHeight: .infinity)
                    .frame(width: isSidebarCollapsed ? 0 : 300)
                    .clipped()
                    .background {
                        if isSidebarCollapsed {
                            Color.clear
                        } else {
                            Rectangle().fill(.regularMaterial)
                        }
                    }
                    .shadow(radius: isSidebarCollapsed ? 0 : 8)
                    .animation(.easeInOut(duration: 0.2), value: isSidebarCollapsed)

                sidebarToggleButton
                    .padding(.leading, isSidebarCollapsed ? 12 : 312)
                    .padding(.top, 16)
            }
            .navigationTitle("Network Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $viewModel.isEditMode) {
                        Text("Edit Mode")
                    }
                    .toggleStyle(SwitchToggleStyle())
                }
            }
        }
        .sheet(item: $viewModel.poleDraft) { draft in
            PoleFormView(draft: draft) { updated in
                viewModel.addPole(from: updated)
            } onCancel: {
                viewModel.cancelPoleDraft()
            }
        }
        .sheet(item: $viewModel.spliceDraft) { draft in
            SpliceFormView(draft: draft) { updated in
                viewModel.addSplice(from: updated)
            } onCancel: {
                viewModel.cancelSpliceDraft()
            }
        }
        .sheet(item: $viewModel.lineDraft) { draft in
            LineFormView(
                draft: draft,
                endpointOptions: viewModel.endpointOptions(),
                endpointLabelProvider: viewModel.endpointLabel(for:)
            ) { updated in
                viewModel.addFiberLine(from: updated)
            } onCancel: {
                viewModel.cancelLineDraft()
            }
        }
    }

    private var sidebarToggleButton: some View {
        Button {
            isSidebarCollapsed.toggle()
        } label: {
            Image(systemName: isSidebarCollapsed ? "sidebar.leading" : "sidebar.trailing")
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared UI Components
private struct RouteMapperSidebar: View {
    @ObservedObject var viewModel: RouteMapperViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Layers")
                    .font(.headline)
                ForEach(MapLayer.allCases) { layer in
                    Toggle(layer.title, isOn: Binding(
                        get: { viewModel.enabledLayers.contains(layer) },
                        set: { value in
                            viewModel.toggle(layer: layer, isEnabled: value)
                        }
                    ))
                }

                Divider()

                if viewModel.enabledLayers.contains(.poles) {
                    assetSection(
                        title: "Poles",
                        items: viewModel.poles.map { (SelectedAsset.pole($0.id), $0.name.isEmpty ? "Pole" : $0.name) }
                    )
                }

                if viewModel.enabledLayers.contains(.splices) {
                    assetSection(
                        title: "Splice Enclosures",
                        items: viewModel.splices.map { (SelectedAsset.splice($0.id), $0.label.isEmpty ? "Splice" : $0.label) }
                    )
                }

                if viewModel.enabledLayers.contains(.fiber) && !viewModel.fiberLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fiber Lines")
                            .font(.headline)
                        ForEach(viewModel.fiberLines) { line in
                            Button {
                                viewModel.handleFiberTap(line)
                            } label: {
                                HStack {
                                    Text(line.name.isEmpty ? "Fiber Line" : line.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(line.capacity)-ct")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(viewModel.selectedAsset == .fiber(line.id) ? Color.accentColor.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func assetSection(title: String, items: [(SelectedAsset, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.0) { reference, label in
                Button {
                    viewModel.selectedAsset = reference
                } label: {
                    HStack {
                        Text(label)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(viewModel.selectedAsset == reference ? Color.accentColor.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RouteMapperToolPicker: View {
    @ObservedObject var viewModel: RouteMapperViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if viewModel.isEditMode {
                Picker("Tool", selection: Binding(
                    get: { viewModel.activeTool },
                    set: { viewModel.activeTool = $0 }
                )) {
                    Text("None").tag(EditTool?.none)
                    ForEach(EditTool.allCases) { tool in
                        Label(tool.label, systemImage: tool.systemImage)
                            .tag(EditTool?.some(tool))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
        }
    }
}

// MARK: - UIKit Backed Map View
private struct RouteMapperMapView: UIViewRepresentable {
    @ObservedObject var viewModel: RouteMapperViewModel
    @Binding var region: MKCoordinateRegion

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.showsCompass = true
        mapView.showsScale = false

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        let dragGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        dragGesture.minimumPressDuration = 0
        dragGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(dragGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        if mapView.region.center.distance(to: region.center) > 1 || abs(mapView.region.span.latitudeDelta - region.span.latitudeDelta) > 0.0001 || abs(mapView.region.span.longitudeDelta - region.span.longitudeDelta) > 0.0001 {
            mapView.setRegion(region, animated: true)
        }

        context.coordinator.updateAnnotations(on: mapView)
        context.coordinator.updateOverlays(on: mapView)

        if let request = viewModel.focusRequest {
            let newRegion = MKCoordinateRegion(center: request.coordinate, span: request.span)
            mapView.setRegion(newRegion, animated: true)
            viewModel.consumeFocusRequest(request.id)
        }
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        private let poleIdentifier = "RouteMapperPole"
        private let spliceIdentifier = "RouteMapperSplice"

        // The coordinator's parent must stay mutable so updateUIView can refresh
        // the reference to the representable when SwiftUI recreates it.
        var parent: RouteMapperMapView
        private var lineDragStart: CLLocationCoordinate2D?
        private var isDraggingLine = false

        init(parent: RouteMapperMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  parent.viewModel.shouldCaptureMapTap,
                  let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.viewModel.handleMapTap(at: coordinate)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

            guard parent.viewModel.isEditMode, parent.viewModel.activeTool == .drawLine else {
                if gesture.state == .ended {
                    isDraggingLine = false
                    lineDragStart = nil
                }
                return
            }

            switch gesture.state {
            case .began:
                lineDragStart = coordinate
                isDraggingLine = false
            case .changed:
                if !isDraggingLine, let start = lineDragStart {
                    let startPoint = MKMapPoint(start)
                    let currentPoint = MKMapPoint(coordinate)
                    if startPoint.distance(to: currentPoint) > 4 {
                        parent.viewModel.beginLineDrawing(at: start)
                        isDraggingLine = true
                    }
                }
            case .ended:
                if isDraggingLine {
                    parent.viewModel.finishLineDrawing(at: coordinate)
                }
                isDraggingLine = false
                lineDragStart = nil
            case .failed, .cancelled:
                isDraggingLine = false
                lineDragStart = nil
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func updateAnnotations(on mapView: MKMapView) {
            var annotations: [MKAnnotation] = []

            if parent.viewModel.enabledLayers.contains(.poles) {
                annotations.append(contentsOf: parent.viewModel.poles.map { PoleAnnotation(pole: $0) })
            }
            if parent.viewModel.enabledLayers.contains(.splices) {
                annotations.append(contentsOf: parent.viewModel.splices.map { SpliceAnnotation(splice: $0) })
            }

            let existing = mapView.annotations.compactMap { $0 as? RouteAssetAnnotation }
            if !existing.isEmpty {
                mapView.removeAnnotations(existing)
            }
            if !annotations.isEmpty {
                mapView.addAnnotations(annotations)
            }
        }

        func updateOverlays(on mapView: MKMapView) {
            let currentOverlays = mapView.overlays.compactMap { $0 as? RouteFiberOverlay }
            if !currentOverlays.isEmpty {
                mapView.removeOverlays(currentOverlays)
            }

            guard parent.viewModel.enabledLayers.contains(.fiber) else { return }
            let overlays = parent.viewModel.fiberLines.map { RouteFiberOverlay(line: $0) }
            if !overlays.isEmpty {
                mapView.addOverlays(overlays)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let assetAnnotation = annotation as? RouteAssetAnnotation else { return nil }

            switch assetAnnotation {
            case let poleAnnotation as PoleAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: poleIdentifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: poleIdentifier)
                view.annotation = annotation
                view.canShowCallout = false
                view.markerTintColor = poleAnnotation.pole.status.annotationTint
                view.glyphImage = UIImage(systemName: "bolt.fill")
                return view
            case let spliceAnnotation as SpliceAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: spliceIdentifier) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: spliceIdentifier)
                view.annotation = annotation
                view.canShowCallout = false
                view.markerTintColor = spliceAnnotation.splice.status.annotationTint
                view.glyphImage = UIImage(systemName: "square.stack.3d.up.fill")
                return view
            default:
                return nil
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let assetAnnotation = view.annotation as? RouteAssetAnnotation else { return }
            switch assetAnnotation {
            case let poleAnnotation as PoleAnnotation:
                parent.viewModel.handlePoleTap(poleAnnotation.pole)
            case let spliceAnnotation as SpliceAnnotation:
                parent.viewModel.handleSpliceTap(spliceAnnotation.splice)
            default:
                break
            }
            mapView.deselectAnnotation(view.annotation, animated: true)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let fiberOverlay = overlay as? RouteFiberOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: fiberOverlay)
            renderer.lineWidth = 4
            renderer.strokeColor = fiberOverlay.status.annotationTint
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

private protocol RouteAssetAnnotation: MKAnnotation {
    var identifier: UUID { get }
}

private final class PoleAnnotation: NSObject, RouteAssetAnnotation {
    let pole: Pole
    let identifier: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { pole.name.isEmpty ? "Pole" : pole.name }

    init(pole: Pole) {
        self.pole = pole
        self.identifier = pole.id
        self.coordinate = pole.coordinate
        super.init()
    }
}

private final class SpliceAnnotation: NSObject, RouteAssetAnnotation {
    let splice: SpliceEnclosure
    let identifier: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { splice.label.isEmpty ? "Splice" : splice.label }

    init(splice: SpliceEnclosure) {
        self.splice = splice
        self.identifier = splice.id
        self.coordinate = splice.coordinate
        super.init()
    }
}

private final class RouteFiberOverlay: MKPolyline {
    let line: FiberLine
    let identifier: UUID
    let status: AssetStatus

    init(line: FiberLine) {
        self.line = line
        self.identifier = line.id
        self.status = line.status
        var coordinates = line.path
        super.init(coordinates: &coordinates, count: coordinates.count)
    }
}

// MARK: - Forms
private struct PoleFormView: View {
    @State private var draft: PoleDraft
    let onSave: (PoleDraft) -> Void
    let onCancel: () -> Void

    init(draft: PoleDraft, onSave: @escaping (PoleDraft) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Pole name", text: $draft.name)
                    Picker("Status", selection: $draft.status) {
                        ForEach(AssetStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    Stepper(value: $draft.capacity, in: 1...96) {
                        Text("Capacity: \(draft.capacity)")
                    }
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Pole")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(draft)
                    }
                }
            }
        }
    }
}

private struct SpliceFormView: View {
    @State private var draft: SpliceDraft
    let onSave: (SpliceDraft) -> Void
    let onCancel: () -> Void

    init(draft: SpliceDraft, onSave: @escaping (SpliceDraft) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Label", text: $draft.label)
                    Picker("Status", selection: $draft.status) {
                        ForEach(AssetStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    Stepper(value: $draft.capacity, in: 1...288) {
                        Text("Capacity: \(draft.capacity)")
                    }
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Splice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(draft)
                    }
                }
            }
        }
    }
}

private struct LineFormView: View {
    @State private var draft: LineDraft
    let endpointOptions: [AssetReference]
    let endpointLabelProvider: (AssetReference) -> String
    let onSave: (LineDraft) -> Void
    let onCancel: () -> Void

    init(draft: LineDraft,
         endpointOptions: [AssetReference],
         endpointLabelProvider: @escaping (AssetReference) -> String,
         onSave: @escaping (LineDraft) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.endpointOptions = endpointOptions
        self.endpointLabelProvider = endpointLabelProvider
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Fiber name", text: $draft.name)
                    Picker("Status", selection: $draft.status) {
                        ForEach(AssetStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    Stepper(value: $draft.capacity, in: 1...864, step: 6) {
                        Text("Capacity: \(draft.capacity)")
                    }
                }

                Section("Endpoints") {
                    Picker("Start", selection: Binding(
                        get: { draft.startEndpoint },
                        set: { draft.startEndpoint = $0 }
                    )) {
                        Text("Unassigned").tag(AssetReference?.none)
                        ForEach(endpointOptions, id: \.id) { option in
                            Text(endpointLabelProvider(option)).tag(AssetReference?.some(option))
                        }
                    }

                    Picker("End", selection: Binding(
                        get: { draft.endEndpoint },
                        set: { draft.endEndpoint = $0 }
                    )) {
                        Text("Unassigned").tag(AssetReference?.none)
                        ForEach(endpointOptions, id: \.id) { option in
                            Text(endpointLabelProvider(option)).tag(AssetReference?.some(option))
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Fiber Line")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(draft)
                    }
                }
            }
        }
    }
}

// MARK: - Geometry helpers
private extension MKMapPoint {
    func distance(toLineSegmentBetween pointA: MKMapPoint, and pointB: MKMapPoint) -> Double {
        let lineLengthSquared = pow(pointB.x - pointA.x, 2) + pow(pointB.y - pointA.y, 2)
        guard lineLengthSquared > 0 else { return distance(to: pointA) }
        let t = max(0, min(1, ((x - pointA.x) * (pointB.x - pointA.x) + (y - pointA.y) * (pointB.y - pointA.y)) / lineLengthSquared))
        let projection = MKMapPoint(x: pointA.x + t * (pointB.x - pointA.x),
                                    y: pointA.y + t * (pointB.y - pointA.y))
        return distance(to: projection)
    }
}

private extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let locationA = CLLocation(latitude: latitude, longitude: longitude)
        let locationB = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return locationA.distance(from: locationB)
    }
}
