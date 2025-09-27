//  MapsView.swift
//  Job Tracker
//  Created by Quinton Thompson on 4/30/25.
//  Updated: Rebuilt with native SwiftUI mapping controls and structured asset models.
//

import SwiftUI
import MapKit
import CoreLocation

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

// MARK: - UI Helpers
private enum SelectedAsset: Hashable, Identifiable {
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

private enum MapLayer: String, CaseIterable, Identifiable {
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

private enum EditTool: String, CaseIterable, Identifiable {
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

private struct PoleDraft: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var name: String = ""
    var status: AssetStatus = .planned
    var capacity: Int = 1
    var notes: String = ""
}

private struct SpliceDraft: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var label: String = ""
    var status: AssetStatus = .planned
    var capacity: Int = 12
    var notes: String = ""
}

private struct LineDraft: Identifiable {
    let id = UUID()
    var points: [CLLocationCoordinate2D]
    var name: String = ""
    var status: AssetStatus = .planned
    var capacity: Int = 12
    var startEndpoint: AssetReference? = nil
    var endEndpoint: AssetReference? = nil
    var notes: String = ""
}

private extension CLLocationCoordinate2D {
    static let defaultCenter = CLLocationCoordinate2D(latitude: 35.9800, longitude: -88.9400)
}

// MARK: - Maps View
struct MapsView: View {
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: .defaultCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )

    @State private var isSidebarCollapsed = false
    @State private var enabledLayers: Set<MapLayer> = Set(MapLayer.allCases)
    @State private var isEditMode = false
    @State private var activeTool: EditTool? = nil

    @State private var poles: [Pole] = []
    @State private var splices: [SpliceEnclosure] = []
    @State private var fiberLines: [FiberLine] = []

    @State private var selectedAsset: SelectedAsset? = nil
    @State private var pendingLinePoints: [CLLocationCoordinate2D] = []

    @State private var poleDraft: PoleDraft? = nil
    @State private var spliceDraft: SpliceDraft? = nil
    @State private var lineDraft: LineDraft? = nil

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                ZStack(alignment: .leading) {
                    mapLayer(proxy: proxy)
                        .overlay(alignment: .bottom) {
                            if let instruction = toolInstruction {
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
                            toolPicker
                                .padding(.top, 16)
                                .padding(.trailing, 16)
                        }

                    sidebar()
                        .frame(maxHeight: .infinity)
                        .frame(width: isSidebarCollapsed ? 0 : 300)
                        .clipped()
                        .background(isSidebarCollapsed ? Color.clear : .regularMaterial)
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
                    Toggle(isOn: $isEditMode) {
                        Text("Edit Mode")
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: isEditMode) { newValue in
                        if !newValue {
                            activeTool = nil
                            pendingLinePoints.removeAll()
                        }
                    }
                }
            }
        }
        .sheet(item: $poleDraft) { draft in
            PoleFormView(draft: draft) { updated in
                addPole(from: updated)
                poleDraft = nil
            } onCancel: {
                poleDraft = nil
            }
        }
        .sheet(item: $spliceDraft) { draft in
            SpliceFormView(draft: draft) { updated in
                addSplice(from: updated)
                spliceDraft = nil
            } onCancel: {
                spliceDraft = nil
            }
        }
        .sheet(item: $lineDraft) { draft in
            LineFormView(
                draft: draft,
                endpointOptions: endpointOptions(),
                endpointLabelProvider: endpointLabel(for:)
            ) { updated in
                addFiberLine(from: updated)
                lineDraft = nil
            } onCancel: {
                pendingLinePoints = []
                lineDraft = nil
            }
        }
        .onChange(of: activeTool) { _ in
            pendingLinePoints.removeAll()
        }
    }

    // MARK: - Map Content
    private func mapLayer(proxy: MapProxy) -> some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            if enabledLayers.contains(.poles) {
                ForEach(poles) { pole in
                    MapAnnotation(coordinate: pole.coordinate) {
                        assetPin(
                            color: pole.status.tint,
                            systemName: "bolt.fill",
                            label: pole.name.isEmpty ? "Pole" : pole.name
                        ) {
                            handlePoleTap(pole)
                        }
                    }
                }
            }

            if enabledLayers.contains(.splices) {
                ForEach(splices) { splice in
                    MapAnnotation(coordinate: splice.coordinate) {
                        assetPin(
                            color: splice.status.tint,
                            systemName: "square.stack.3d.up.fill",
                            label: splice.label.isEmpty ? "Splice" : splice.label
                        ) {
                            handleSpliceTap(splice)
                        }
                    }
                }
            }

            if enabledLayers.contains(.fiber) {
                ForEach(fiberLines) { line in
                    MapPolyline(coordinates: line.path)
                        .stroke(line.status.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .center) {
            if shouldCaptureMapTap {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard shouldCaptureMapTap,
                                      let coordinate = proxy.convert(value.location, from: .local) else { return }
                                handleMapTap(at: coordinate)
                            }
                    )
            }
        }
    }

    private var shouldCaptureMapTap: Bool {
        guard isEditMode, let tool = activeTool else { return false }
        switch tool {
        case .addPole, .addSplice, .drawLine, .delete:
            return true
        }
    }

    // MARK: - Sidebar
    @ViewBuilder
    private func sidebar() -> some View {
        if isSidebarCollapsed {
            Color.clear
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Layers")
                            .font(.headline)
                        ForEach(MapLayer.allCases) { layer in
                            Toggle(layer.title, isOn: Binding(
                                get: { enabledLayers.contains(layer) },
                                set: { value in
                                    if value {
                                        enabledLayers.insert(layer)
                                    } else {
                                        enabledLayers.remove(layer)
                                    }
                                }
                            ))
                        }

                        Divider()

                        if enabledLayers.contains(.poles) {
                            assetSection(
                                title: "Poles",
                                items: poles.map { (SelectedAsset.pole($0.id), $0.name.isEmpty ? "Pole" : $0.name) }
                            )
                        }

                        if enabledLayers.contains(.splices) {
                            assetSection(
                                title: "Splice Enclosures",
                                items: splices.map { (SelectedAsset.splice($0.id), $0.label.isEmpty ? "Splice" : $0.label) }
                            )
                        }

                        if enabledLayers.contains(.fiber) && !fiberLines.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fiber Lines")
                                    .font(.headline)
                                ForEach(fiberLines) { line in
                                    Button {
                                        selectedAsset = .fiber(line.id)
                                        focus(on: line)
                                    } label: {
                                        HStack {
                                            Text(line.name.isEmpty ? "Fiber Line" : line.name)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text("\(line.capacity)-ct")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(8)
                                        .background(selectedAsset == .fiber(line.id) ? Color.accentColor.opacity(0.1) : Color.clear)
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
        }
    }

    private func assetSection(title: String,
                               items: [(SelectedAsset, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.0) { reference, label in
                Button {
                    selectedAsset = reference
                    focus(onSelection: reference)
                } label: {
                    HStack {
                        Text(label)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(8)
                    .background(selectedAsset == reference ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sidebarToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isSidebarCollapsed.toggle()
            }
        } label: {
            Image(systemName: isSidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(.primary)
                .padding(10)
                .background(.regularMaterial, in: Circle())
                .shadow(radius: 3)
        }
        .buttonStyle(.plain)
    }

    private var toolPicker: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isEditMode {
                Picker("Edit Tool", selection: Binding(
                    get: { activeTool },
                    set: { activeTool = $0 }
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

    private var toolInstruction: String? {
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

    // MARK: - Asset Helpers
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        guard isEditMode, let tool = activeTool else { return }
        switch tool {
        case .addPole:
            poleDraft = PoleDraft(coordinate: coordinate)
        case .addSplice:
            spliceDraft = SpliceDraft(coordinate: coordinate)
        case .drawLine:
            pendingLinePoints.append(coordinate)
            if pendingLinePoints.count >= 2 {
                lineDraft = LineDraft(points: pendingLinePoints)
                pendingLinePoints.removeAll()
            }
        case .delete:
            deleteNearestAsset(to: coordinate)
        }
    }

    private func handlePoleTap(_ pole: Pole) {
        if isEditMode, activeTool == .delete {
            poles.removeAll { $0.id == pole.id }
        } else {
            selectedAsset = .pole(pole.id)
            focus(on: pole)
        }
    }

    private func handleSpliceTap(_ splice: SpliceEnclosure) {
        if isEditMode, activeTool == .delete {
            splices.removeAll { $0.id == splice.id }
        } else {
            selectedAsset = .splice(splice.id)
            focus(on: splice)
        }
    }

    private func addPole(from draft: PoleDraft) {
        let pole = Pole(
            name: draft.name,
            coordinate: draft.coordinate,
            status: draft.status,
            capacity: draft.capacity,
            notes: draft.notes
        )
        poles.append(pole)
        selectedAsset = .pole(pole.id)
        focus(on: pole)
    }

    private func addSplice(from draft: SpliceDraft) {
        let splice = SpliceEnclosure(
            label: draft.label,
            coordinate: draft.coordinate,
            status: draft.status,
            capacity: draft.capacity,
            notes: draft.notes
        )
        splices.append(splice)
        selectedAsset = .splice(splice.id)
        focus(on: splice)
    }

    private func addFiberLine(from draft: LineDraft) {
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
        selectedAsset = .fiber(line.id)
        focus(on: line)
    }

    private func deleteNearestAsset(to coordinate: CLLocationCoordinate2D) {
        let targetPoint = MKMapPoint(coordinate)
        let threshold: Double = 40 // meters

        let nearestPole = poles.min { lhs, rhs in
            MKMapPoint(lhs.coordinate).distance(to: targetPoint) < MKMapPoint(rhs.coordinate).distance(to: targetPoint)
        }
        if let pole = nearestPole,
           MKMapPoint(pole.coordinate).distance(to: targetPoint) < threshold {
            poles.removeAll { $0.id == pole.id }
            return
        }

        let nearestSplice = splices.min { lhs, rhs in
            MKMapPoint(lhs.coordinate).distance(to: targetPoint) < MKMapPoint(rhs.coordinate).distance(to: targetPoint)
        }
        if let splice = nearestSplice,
           MKMapPoint(splice.coordinate).distance(to: targetPoint) < threshold {
            splices.removeAll { $0.id == splice.id }
            return
        }

        let nearestLine = fiberLines.enumerated().min { lhs, rhs in
            lineDistance(from: coordinate, to: lhs.element.path) < lineDistance(from: coordinate, to: rhs.element.path)
        }
        if let (index, line) = nearestLine,
           lineDistance(from: coordinate, to: line.path) < threshold {
            fiberLines.remove(at: index)
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

    private func focus(on pole: Pole) {
        focus(on: pole.coordinate)
    }

    private func focus(on splice: SpliceEnclosure) {
        focus(on: splice.coordinate)
    }

    private func focus(on line: FiberLine) {
        guard let center = midpoint(of: line.path) else { return }
        focus(on: center)
    }

    private func focus(on coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: span))
    }

    private func focus(onSelection selection: SelectedAsset) {
        switch selection {
        case .pole(let id):
            guard let pole = poles.first(where: { $0.id == id }) else { return }
            focus(on: pole)
        case .splice(let id):
            guard let splice = splices.first(where: { $0.id == id }) else { return }
            focus(on: splice)
        case .fiber(let id):
            guard let line = fiberLines.first(where: { $0.id == id }) else { return }
            focus(on: line)
        }
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

    private func endpointOptions() -> [AssetReference] {
        let poleRefs = poles.map { AssetReference.pole($0.id) }
        let spliceRefs = splices.map { AssetReference.splice($0.id) }
        return poleRefs + spliceRefs
    }

    private func endpointLabel(for reference: AssetReference) -> String {
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
