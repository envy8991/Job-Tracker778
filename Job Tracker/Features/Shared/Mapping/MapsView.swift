import SwiftUI
import CoreLocation
import UIKit

// MARK: - Data Models
// These structs define the data for our network assets.

struct Pole: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var status: AssetStatus
    var installDate: Date?
    var lastInspection: Date?
    var material: String
    var notes: String
    var imageUrl: String?

    public init(
        id: UUID,
        name: String,
        coordinate: CLLocationCoordinate2D,
        status: AssetStatus,
        installDate: Date? = nil,
        lastInspection: Date? = nil,
        material: String,
        notes: String,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.status = status
        self.installDate = installDate
        self.lastInspection = lastInspection
        self.material = material
        self.notes = notes
        self.imageUrl = imageUrl
    }

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
    private enum CodingKeys: String, CodingKey {
        case id, name, coordinate, status, installDate, lastInspection, material, notes, imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let coord = try container.decode(CodableCoordinate.self, forKey: .coordinate)
        coordinate = coord.coordinate
        status = try container.decode(AssetStatus.self, forKey: .status)
        installDate = try container.decodeIfPresent(Date.self, forKey: .installDate)
        lastInspection = try container.decodeIfPresent(Date.self, forKey: .lastInspection)
        material = try container.decode(String.self, forKey: .material)
        notes = try container.decode(String.self, forKey: .notes)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(CodableCoordinate(coordinate), forKey: .coordinate)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(installDate, forKey: .installDate)
        try container.encodeIfPresent(lastInspection, forKey: .lastInspection)
        try container.encode(material, forKey: .material)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
    }
}

struct SpliceEnclosure: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D
    var status: AssetStatus
    var capacity: Int
    var notes: String
    var imageUrl: String?

    init(
        id: UUID,
        name: String,
        coordinate: CLLocationCoordinate2D,
        status: AssetStatus,
        capacity: Int,
        notes: String,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.status = status
        self.capacity = capacity
        self.notes = notes
        self.imageUrl = imageUrl
    }

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
    private enum CodingKeys: String, CodingKey {
        case id, name, coordinate, status, capacity, notes, imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let coord = try container.decode(CodableCoordinate.self, forKey: .coordinate)
        coordinate = coord.coordinate
        status = try container.decode(AssetStatus.self, forKey: .status)
        capacity = try container.decode(Int.self, forKey: .capacity)
        notes = try container.decode(String.self, forKey: .notes)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(CodableCoordinate(coordinate), forKey: .coordinate)
        try container.encode(status, forKey: .status)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
    }
}

struct FiberLine: Identifiable, Hashable, Codable {
    let id: UUID
    var startPoleId: Pole.ID
    var endPoleId: Pole.ID
    var status: AssetStatus
    var fiberCount: Int
    var notes: String

    init(
        id: UUID,
        startPoleId: Pole.ID,
        endPoleId: Pole.ID,
        status: AssetStatus,
        fiberCount: Int,
        notes: String
    ) {
        self.id = id
        self.startPoleId = startPoleId
        self.endPoleId = endPoleId
        self.status = status
        self.fiberCount = fiberCount
        self.notes = notes
    }

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
    private enum CodingKeys: String, CodingKey {
        case id, startPoleId, endPoleId, status, fiberCount, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startPoleId = try container.decode(UUID.self, forKey: .startPoleId)
        endPoleId = try container.decode(UUID.self, forKey: .endPoleId)
        status = try container.decode(AssetStatus.self, forKey: .status)
        fiberCount = try container.decode(Int.self, forKey: .fiberCount)
        notes = try container.decode(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startPoleId, forKey: .startPoleId)
        try container.encode(endPoleId, forKey: .endPoleId)
        try container.encode(status, forKey: .status)
        try container.encode(fiberCount, forKey: .fiberCount)
        try container.encode(notes, forKey: .notes)
    }
}

private struct CodableCoordinate: Codable {
    var latitude: Double
    var longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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

    private let storage: FiberMapStorage

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
    
    init(storage: FiberMapStorage = .shared) {
        self.storage = storage
        if !loadFromStorage() {
            loadInitialData()
            persistSilently()
        }
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
            persistSilently()
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
            persistSilently()
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
            persistSilently()
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
        persistSilently()
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

    private func loadFromStorage() -> Bool {
        do {
            guard let snapshot = try storage.load() else { return false }
            self.poles = snapshot.poles
            self.splices = snapshot.splices
            self.lines = snapshot.lines
            return true
        } catch {
            return false
        }
    }

    private func persistSilently() {
        do {
            try storage.save(poles: poles, splices: splices, lines: lines)
        } catch {
#if DEBUG
            print("FiberMapStorage save error:", error)
#endif
        }
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

    var body: some View {
        ZStack {
            LeafletWebMapView(viewModel: viewModel)
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

extension Binding {
    init(_ source: Binding<Value?>, default defaultValue: Value) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in
                source.wrappedValue = newValue
            }
        )
    }
}

