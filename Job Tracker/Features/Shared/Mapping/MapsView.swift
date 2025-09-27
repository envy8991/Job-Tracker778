import SwiftUI
import MapKit

// MARK: - Data Models
// These structs define the data for our network assets.

struct Pole: Identifiable, Hashable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var status: AssetStatus
    var installDate: Date?
    var lastInspection: Date?
    var material: String
    var notes: String
    var imageUrl: String?

    static func == (lhs: Pole, rhs: Pole) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.status == rhs.status &&
        lhs.installDate == rhs.installDate &&
        lhs.lastInspection == rhs.lastInspection &&
        lhs.material == rhs.material &&
        lhs.notes == rhs.notes &&
        lhs.imageUrl == rhs.imageUrl
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(status)
        hasher.combine(installDate)
        hasher.combine(lastInspection)
        hasher.combine(material)
        hasher.combine(notes)
        hasher.combine(imageUrl)
    }
}

struct SpliceEnclosure: Identifiable, Hashable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var status: AssetStatus
    var capacity: Int
    var notes: String
    var imageUrl: String?

    static func == (lhs: SpliceEnclosure, rhs: SpliceEnclosure) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.status == rhs.status &&
        lhs.capacity == rhs.capacity &&
        lhs.notes == rhs.notes &&
        lhs.imageUrl == rhs.imageUrl
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(status)
        hasher.combine(capacity)
        hasher.combine(notes)
        hasher.combine(imageUrl)
    }
}

struct FiberLine: Identifiable, Hashable {
    let id: UUID
    var startPoleId: Pole.ID
    var endPoleId: Pole.ID
    var status: AssetStatus
    var fiberCount: Int
    var notes: String

    static func == (lhs: FiberLine, rhs: FiberLine) -> Bool {
        lhs.id == rhs.id &&
        lhs.startPoleId == rhs.startPoleId &&
        lhs.endPoleId == rhs.endPoleId &&
        lhs.status == rhs.status &&
        lhs.fiberCount == rhs.fiberCount &&
        lhs.notes == rhs.notes
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startPoleId)
        hasher.combine(endPoleId)
        hasher.combine(status)
        hasher.combine(fiberCount)
        hasher.combine(notes)
    }
}

enum AssetStatus: String, CaseIterable, Identifiable, Codable {
    case good = "Good"
    case needsInspection = "Needs Inspection"
    case damaged = "Damaged"
    case active = "Active"
    case inactive = "Inactive"
    case planned = "Planned"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .good, .active: return .green
        case .needsInspection, .planned: return .blue
        case .damaged, .inactive: return .red
        }
    }
    
    var uiColor: UIColor {
        switch self {
        case .good, .active: return .systemGreen
        case .needsInspection, .planned: return .systemBlue
        case .damaged, .inactive: return .systemRed
        }
    }
}

// Wrapper to make AnyHashable identifiable for sheets
struct AnyIdentifiable: Identifiable {
    let id = UUID()
    let value: AnyHashable
}


// MARK: - Map View Model
@MainActor
class FiberMapViewModel: ObservableObject {
    // Data stores for our assets
    @Published var poles: [Pole] = []
    @Published var splices: [SpliceEnclosure] = []
    @Published var lines: [FiberLine] = []

    // UI State
    @Published var isEditMode = false {
        didSet {
            handleEditModeChange(from: oldValue)
        }
    }
    @Published var activeTool: EditTool?
    @Published var selectedAsset: AnyHashable?
    @Published var lineStartPole: Pole?
    @Published var editInstruction: String?
    @Published var visibleLayers: Set<MapLayer> = [.poles, .splices, .lines]
    
    // Sheet presentation
    @Published var itemToEdit: AnyIdentifiable?
    
    init() {
        loadInitialData()
    }
    
    // Asset lookup for drawing lines
    func pole(for id: Pole.ID) -> Pole? {
        poles.first { $0.id == id }
    }
    
    // UI Interaction
    func handleMapTap(coordinate: CLLocationCoordinate2D) {
        guard isEditMode, let tool = activeTool else {
            selectedAsset = nil
            return
        }
        
        switch tool {
        case .addPole:
            let newPole = Pole(id: UUID(), name: "New Pole", coordinate: coordinate, status: .good, material: "Wood", notes: "")
            itemToEdit = AnyIdentifiable(value: newPole)
        case .addSplice:
            let newSplice = SpliceEnclosure(id: UUID(), name: "New Splice", coordinate: coordinate, status: .good, capacity: 12, notes: "")
            itemToEdit = AnyIdentifiable(value: newSplice)
        default:
            break
        }
    }
    
    func handlePoleTap(_ pole: Pole) {
        guard isEditMode else {
            selectedAsset = pole
            return
        }
        
        switch activeTool {
        case .drawLine:
            if let startPole = lineStartPole {
                // Finish drawing line if it's not the same pole
                if pole.id != startPole.id {
                     let newLine = FiberLine(id: UUID(), startPoleId: startPole.id, endPoleId: pole.id, status: .active, fiberCount: 12, notes: "")
                     itemToEdit = AnyIdentifiable(value: newLine)
                }
                resetToolState()
            } else {
                // Start drawing line
                lineStartPole = pole
                updateInstruction()
            }
        case .delete:
            poles.removeAll { $0.id == pole.id }
            // Also remove lines connected to this pole
            lines.removeAll { $0.startPoleId == pole.id || $0.endPoleId == pole.id }
        default:
            itemToEdit = AnyIdentifiable(value: pole)
        }
    }
    
    func handleSpliceTap(_ splice: SpliceEnclosure) {
        guard isEditMode else {
            selectedAsset = splice
            return
        }
        
        if activeTool == .delete {
            splices.removeAll { $0.id == splice.id }
        } else {
            itemToEdit = AnyIdentifiable(value: splice)
        }
    }
    
    func handleLineTap(_ line: FiberLine) {
         guard isEditMode else {
            selectedAsset = line
            return
        }
        if activeTool == .delete {
            lines.removeAll { $0.id == line.id }
        } else {
            itemToEdit = AnyIdentifiable(value: line)
        }
    }

    func saveItem<T: Hashable>(_ item: T) {
         if let pole = item as? Pole {
            if let index = poles.firstIndex(where: { $0.id == pole.id }) {
                poles[index] = pole
            } else {
                poles.append(pole)
            }
        } else if let splice = item as? SpliceEnclosure {
            if let index = splices.firstIndex(where: { $0.id == splice.id }) {
                splices[index] = splice
            } else {
                splices.append(splice)
            }
        } else if let line = item as? FiberLine {
             if let index = lines.firstIndex(where: { $0.id == line.id }) {
                lines[index] = line
            } else {
                lines.append(line)
            }
        }
        itemToEdit = nil
    }
    
    func cancelEdit() {
        itemToEdit = nil
    }

    func toggleLayer(_ layer: MapLayer) {
        if visibleLayers.contains(layer) {
            visibleLayers.remove(layer)
        } else {
            visibleLayers.insert(layer)
        }
    }
    
    func selectTool(_ tool: EditTool?) {
        if activeTool == tool {
            activeTool = nil
        } else {
            activeTool = tool
        }
        resetToolState(except: tool)
    }
    
    private func resetToolState(except newTool: EditTool? = nil) {
        lineStartPole = nil
        if newTool != .drawLine {
             activeTool = newTool
        }
        updateInstruction()
    }

    private func handleEditModeChange(from previousValue: Bool) {
        guard previousValue != isEditMode else { return }

        lineStartPole = nil

        if isEditMode {
            updateInstruction()
        } else {
            editInstruction = nil
        }
    }

    private func updateInstruction() {
        if isEditMode {
            if let tool = activeTool {
                switch tool {
                case .addPole: editInstruction = "Tap map to add a pole."
                case .addSplice: editInstruction = "Tap map to add a splice."
                case .drawLine:
                    if lineStartPole != nil {
                        editInstruction = "Select an end pole for the line."
                    } else {
                        editInstruction = "Select a start pole for the line."
                    }
                case .delete: editInstruction = "Tap an asset to delete it."
                }
            } else {
                editInstruction = "Select an editing tool."
            }
        } else {
            editInstruction = nil
        }
    }

    // Load sample data to populate the map initially
    private func loadInitialData() {
        let pole1 = Pole(id: UUID(), name: "P-001", coordinate: .init(latitude: 35.9735, longitude: -88.9450), status: .good, installDate: Date(), lastInspection: Date(), material: "Wood", notes: "Standard utility pole.", imageUrl: "https://placehold.co/400x300/cccccc/ffffff?text=Pole+P-001")
        let pole2 = Pole(id: UUID(), name: "P-002", coordinate: .init(latitude: 35.9738, longitude: -88.9425), status: .needsInspection, installDate: Date(), lastInspection: Date(), material: "Wood", notes: "Leaning slightly.")
        
        let splice1 = SpliceEnclosure(id: UUID(), name: "SC-101", coordinate: .init(latitude: 35.97355, longitude: -88.9449), status: .good, capacity: 144, notes: "Attached to pole P-001.")
        
        let line1 = FiberLine(id: UUID(), startPoleId: pole1.id, endPoleId: pole2.id, status: .active, fiberCount: 48, notes: "Main trunk line.")
        
        self.poles = [pole1, pole2]
        self.splices = [splice1]
        self.lines = [line1]
    }
}

// MARK: - Enums for UI controls
enum EditTool: String, CaseIterable, Identifiable {
    case addPole, addSplice, drawLine, delete
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .addPole: "plus.viewfinder"
        case .addSplice: "square.stack.3d.up.fill"
        case .drawLine: "pencil.and.ruler.fill"
        case .delete: "trash.fill"
        }
    }
    
    var label: String {
        switch self {
        case .addPole: "Add Pole"
        case .addSplice: "Add Splice"
        case .drawLine: "Draw Line"
        case .delete: "Delete"
        }
    }
}

enum MapLayer: String, CaseIterable, Identifiable {
    case poles, splices, lines
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .poles: "Poles"
        case .splices: "Splices"
        case .lines: "Lines"
        }
    }
}

// MARK: - Main SwiftUI View
struct MapsView: View {
    @StateObject private var viewModel = FiberMapViewModel()
    @State private var showControls = true
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.9735, longitude: -88.9450),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    var body: some View {
        ZStack {
            UIKitMapView(viewModel: viewModel, region: $region)
                .ignoresSafeArea()

            // Overlays for controls and instructions
            VStack {
                Spacer()
                if let instruction = viewModel.editInstruction {
                    Text(instruction)
                        .padding(12)
                        .background(.thinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            VStack {
                HStack(alignment: .top) {
                    if showControls {
                        ControlPanelView(viewModel: viewModel)
                            .padding([.leading, .top])
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Spacer()
                }
                Spacer()
            }
            .allowsHitTesting(showControls)

            VStack {
                HStack {
                    Button {
                        withAnimation(.easeInOut) {
                            showControls.toggle()
                        }
                    } label: {
                        Image(systemName: showControls ? "chevron.left" : "slider.horizontal.3")
                            .font(.title3.weight(.semibold))
                            .padding(12)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.leading, showControls ? 282 : 20)
                    .padding(.top, 20)
                    .accessibilityLabel(showControls ? "Hide map controls" : "Show map controls")
                    Spacer()
                }
                Spacer()
            }
        }
        .animation(.easeInOut, value: showControls)
        .sheet(item: $viewModel.itemToEdit) { itemWrapper in
            let item = itemWrapper.value
            if let pole = item as? Pole {
                PoleEditView(pole: pole, onSave: viewModel.saveItem, onCancel: viewModel.cancelEdit)
            } else if let splice = item as? SpliceEnclosure {
                SpliceEditView(splice: splice, onSave: viewModel.saveItem, onCancel: viewModel.cancelEdit)
            } else if let line = item as? FiberLine {
                LineEditView(line: line, onSave: viewModel.saveItem, onCancel: viewModel.cancelEdit)
            }
        }
    }
}

// MARK: - Control Panel UI
struct ControlPanelView: View {
    @ObservedObject var viewModel: FiberMapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Map Controls").font(.headline).padding(.bottom, 4)

            // Layer Toggles
            Text("Layers").font(.subheadline).foregroundStyle(.secondary)
            ForEach(MapLayer.allCases) { layer in
                Toggle(isOn: Binding(
                    get: { viewModel.visibleLayers.contains(layer) },
                    set: { _ in viewModel.toggleLayer(layer) }
                )) {
                    Text(layer.label)
                }
            }

            Divider().padding(.vertical, 8)
            
            // Edit Mode Toggle
            Toggle(isOn: $viewModel.isEditMode.animation()) {
                Text("Edit Mode").bold()
            }
            
            // Editing Tools
            if viewModel.isEditMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tools").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(EditTool.allCases) { tool in
                        Button(action: { viewModel.selectTool(tool) }) {
                            HStack {
                                Image(systemName: tool.icon)
                                Text(tool.label)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(8)
                        .background(viewModel.activeTool == tool ? Color.accentColor.opacity(0.3) : Color.clear)
                        .cornerRadius(8)
                        .tint(viewModel.activeTool == tool ? .primary : .secondary)
                    }
                }
                .padding(.top, 4)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(15)
        .shadow(radius: 5)
        .frame(width: 250)
    }
}

// MARK: - Editing Forms (Unchanged)
struct PoleEditView: View {
    @State var pole: Pole
    var onSave: (Pole) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $pole.name)
                    Picker("Status", selection: $pole.status) {
                        ForEach([AssetStatus.good, .needsInspection, .damaged], id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    TextField("Material", text: $pole.material)
                    DatePicker("Install Date", selection: Binding($pole.installDate, default: Date()), displayedComponents: .date)
                    DatePicker("Last Inspection", selection: Binding($pole.lastInspection, default: Date()), displayedComponents: .date)
                }
                Section("Notes") {
                    TextEditor(text: $pole.notes)
                }
            }
            .navigationTitle("Edit Pole")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(pole) } }
            }
        }
    }
}

struct SpliceEditView: View {
    @State var splice: SpliceEnclosure
    var onSave: (SpliceEnclosure) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $splice.name)
                    Picker("Status", selection: $splice.status) {
                         ForEach([AssetStatus.good, .needsInspection, .damaged], id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    Stepper("Capacity: \(splice.capacity)", value: $splice.capacity, in: 0...288)
                }
                Section("Notes") {
                    TextEditor(text: $splice.notes)
                }
            }
            .navigationTitle("Edit Splice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(splice) } }
            }
        }
    }
}

struct LineEditView: View {
    @State var line: FiberLine
    var onSave: (FiberLine) -> Void
    var onCancel: () -> Void
    
    var body: some View {
         NavigationStack {
            Form {
                Section("Details") {
                    Picker("Status", selection: $line.status) {
                        ForEach([AssetStatus.active, .inactive, .planned], id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    Stepper("Fiber Count: \(line.fiberCount)", value: $line.fiberCount, in: 0...864, step: 12)
                }
                Section("Notes") {
                    TextEditor(text: $line.notes)
                }
            }
            .navigationTitle("Edit Line")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(line) } }
            }
        }
    }
}

// MARK: - UIKit Map View Representable
struct UIKitMapView: UIViewRepresentable {
    @ObservedObject var viewModel: FiberMapViewModel
    @Binding var region: MKCoordinateRegion

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: true)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.updateAnnotations(on: uiView)
        context.coordinator.updateOverlays(on: uiView)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: UIKitMapView

        init(_ parent: UIKitMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            
            // Check if tap was on an annotation
            let view = mapView.hitTest(location, with: nil)
            if view is MKMarkerAnnotationView {
                // Let didSelect handle it
                return
            }

            parent.viewModel.handleMapTap(coordinate: coordinate)
        }

        func updateAnnotations(on mapView: MKMapView) {
            mapView.removeAnnotations(mapView.annotations)
            
            var annotations: [MKAnnotation] = []
            if parent.viewModel.visibleLayers.contains(.poles) {
                annotations.append(contentsOf: parent.viewModel.poles.map(PoleAnnotation.init))
            }
            if parent.viewModel.visibleLayers.contains(.splices) {
                 annotations.append(contentsOf: parent.viewModel.splices.map(SpliceAnnotation.init))
            }
            mapView.addAnnotations(annotations)
        }
        
        func updateOverlays(on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            if parent.viewModel.visibleLayers.contains(.lines) {
                 let polylines = parent.viewModel.lines.compactMap { line -> MKPolyline? in
                    guard let startPole = parent.viewModel.pole(for: line.startPoleId),
                          let endPole = parent.viewModel.pole(for: line.endPoleId) else { return nil }
                    
                    let coordinates = [startPole.coordinate, endPole.coordinate]
                    let polyline = FiberPolyline(coordinates: coordinates, count: 2)
                    polyline.lineData = line
                    return polyline
                }
                mapView.addOverlays(polylines)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let poleAnnotation = annotation as? PoleAnnotation {
                let identifier = "pole"
                var view: MKMarkerAnnotationView
                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    dequeuedView.annotation = annotation
                    view = dequeuedView
                } else {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                view.markerTintColor = poleAnnotation.pole.status.uiColor
                view.glyphImage = UIImage(systemName: "bolt.fill")
                return view
            } else if let spliceAnnotation = annotation as? SpliceAnnotation {
                let identifier = "splice"
                var view: MKMarkerAnnotationView
                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    dequeuedView.annotation = annotation
                    view = dequeuedView
                } else {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                view.markerTintColor = spliceAnnotation.splice.status.uiColor
                view.glyphImage = UIImage(systemName: "square.stack.3d.up.fill")
                return view
            }
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? FiberPolyline, let lineData = polyline.lineData {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = lineData.status.uiColor
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? PoleAnnotation {
                parent.viewModel.handlePoleTap(annotation.pole)
            } else if let annotation = view.annotation as? SpliceAnnotation {
                parent.viewModel.handleSpliceTap(annotation.splice)
            }
            mapView.deselectAnnotation(view.annotation, animated: true)
        }
        
         func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

// MARK: - Custom Annotation and Overlay Classes
private class PoleAnnotation: NSObject, MKAnnotation {
    let pole: Pole
    var coordinate: CLLocationCoordinate2D { pole.coordinate }
    var title: String? { pole.name }
    init(_ pole: Pole) { self.pole = pole }
}

private class SpliceAnnotation: NSObject, MKAnnotation {
    let splice: SpliceEnclosure
    var coordinate: CLLocationCoordinate2D { splice.coordinate }
    var title: String? { splice.name }
    init(_ splice: SpliceEnclosure) { self.splice = splice }
}

private class FiberPolyline: MKPolyline {
    var lineData: FiberLine?
}


// MARK: - Helper Extensions
extension Binding {
    init(_ source: Binding<Value?>, default defaultValue: Value) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}

