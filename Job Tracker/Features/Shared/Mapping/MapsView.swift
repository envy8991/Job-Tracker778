import SwiftUI
import Combine
import CoreLocation
import UIKit
import MapKit

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

struct MapSearchResult: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    init(id: UUID = UUID(), title: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    static func == (lhs: MapSearchResult, rhs: MapSearchResult) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct MapCenterCommand: Codable, Equatable {
    enum Kind: String, Codable {
        case searchResult
        case userLocation
    }

    let latitude: Double
    let longitude: Double
    let zoom: Double?
    let label: String?
    let kind: Kind?
}

protocol MapSearchProviding {
    func searchLocations(matching query: String) async throws -> [MapSearchResult]
}

struct AppleMapSearchProvider: MapSearchProviding {
    func searchLocations(matching query: String) async throws -> [MapSearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.compactMap { item in
            guard let coordinate = item.placemark.location?.coordinate else { return nil }
            return MapSearchResult(
                title: item.name ?? query,
                subtitle: item.placemark.title ?? "",
                coordinate: coordinate
            )
        }
    }
}


// MARK: - Map View Model
@MainActor
class FiberMapViewModel: ObservableObject {
    private static let defaultCamera = MapCameraState(latitude: 36.3219, longitude: -88.9562, zoom: 16)

    // Data stores for our assets
    @Published var poles: [Pole] = []
    @Published var splices: [SpliceEnclosure] = []
    @Published var lines: [FiberLine] = []

    private let storage: FiberMapStorage
    private let searchProvider: MapSearchProviding

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
    @Published var mapCamera: MapCameraState
    @Published private(set) var pendingCenterCommand: MapCenterCommand?
    @Published var searchResults: [MapSearchResult] = []
    @Published var isSearchingLocations = false
    @Published var searchError: String?

    // Sheet presentation
    @Published var itemToEdit: AnyIdentifiable?

    private var locationUpdatesCancellable: AnyCancellable?
    private var locationServiceIdentifier: ObjectIdentifier?

    init(storage: FiberMapStorage = .shared, searchProvider: MapSearchProviding = AppleMapSearchProvider()) {
        self.storage = storage
        self.searchProvider = searchProvider
        self.mapCamera = Self.defaultCamera
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

    func searchLocations(for query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchError = nil
            return
        }

        isSearchingLocations = true
        do {
            let results = try await searchProvider.searchLocations(matching: trimmed)
            searchResults = results
            searchError = results.isEmpty ? "No matches found." : nil
        } catch {
            searchResults = []
            searchError = "Unable to find that address. Please try again."
        }
        isSearchingLocations = false
    }

    func selectSearchResult(_ result: MapSearchResult, zoom: Double = 17) {
        searchResults = []
        searchError = nil
        let camera = MapCameraState(latitude: result.coordinate.latitude, longitude: result.coordinate.longitude, zoom: zoom)
        updateMapCamera(camera, highlight: result.title)
    }

    func clearSearchResults() {
        searchResults = []
        searchError = nil
    }

    func acknowledgeCenterCommand() {
        pendingCenterCommand = nil
    }

    func bindLocationService(_ service: LocationServiceProviding) {
        let identifier = ObjectIdentifier(service as AnyObject)
        guard locationServiceIdentifier != identifier else { return }
        locationServiceIdentifier = identifier

        locationUpdatesCancellable = service.currentPublisher
            .compactMap { $0 }
            .removeDuplicates(by: { lhs, rhs in
                abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 0.000_001 &&
                abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 0.000_001
            })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleDeviceLocationUpdate(location)
            }
    }

    func locateUser(
        using service: LocationServiceProviding,
        authorizationStatus: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
    ) {
        bindLocationService(service)

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let current = service.current {
                handleDeviceLocationUpdate(current)
            } else {
                service.startStandardUpdates()
            }
        case .notDetermined:
            service.requestAlwaysAuthorizationIfNeeded()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
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
            queueCenterCommand(label: nil)
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
            if let camera = snapshot.mapCamera {
                self.mapCamera = camera
            }
            return true
        } catch {
            return false
        }
    }

    private func updateMapCamera(_ camera: MapCameraState, highlight label: String?) {
        mapCamera = camera
        let kind: MapCenterCommand.Kind? = label == nil ? nil : .searchResult
        setPendingCenterCommand(camera: camera, label: label, kind: kind)
        persistSilently()
    }

    private func queueCenterCommand(label: String?, kind: MapCenterCommand.Kind? = nil) {
        setPendingCenterCommand(camera: mapCamera, label: label, kind: kind)
    }

    private func setPendingCenterCommand(
        camera: MapCameraState,
        label: String?,
        kind: MapCenterCommand.Kind? = nil
    ) {
        pendingCenterCommand = MapCenterCommand(
            latitude: camera.latitude,
            longitude: camera.longitude,
            zoom: camera.zoom,
            label: label,
            kind: kind
        )
    }

    private func handleDeviceLocationUpdate(_ location: CLLocation) {
        let coordinate = location.coordinate
        let zoom = mapCamera.zoom ?? 17
        let camera = MapCameraState(latitude: coordinate.latitude, longitude: coordinate.longitude, zoom: zoom)
        setPendingCenterCommand(camera: camera, label: "Current Location", kind: .userLocation)
    }

    private func persistSilently() {
        do {
            try storage.save(poles: poles, splices: splices, lines: lines, mapCamera: mapCamera)
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
    @State private var searchQuery = ""
    @State private var controlPanelWidth: CGFloat = 0
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        ZStack {
            LeafletWebMapView(viewModel: viewModel)
                .ignoresSafeArea()
                .safeAreaInset(edge: .top) {
                    searchOverlay
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

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
            let panelSpacing: CGFloat = 12
            let togglePeekWidth: CGFloat = 56
            let hiddenOffset: CGFloat = controlPanelWidth == 0
                ? 0
                : -(controlPanelWidth + panelSpacing) + togglePeekWidth

            HStack(alignment: .top, spacing: 0) {
                HStack(alignment: .top, spacing: panelSpacing) {
                    Button {
                        withAnimation(.easeInOut) {
                            showControls.toggle()
                        }
                    } label: {
                        Image(systemName: showControls ? "chevron.left" : "slider.horizontal.3")
                            .font(.title3.weight(.semibold))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                    }
                    .accessibilityLabel(showControls ? "Hide map controls" : "Show map controls")

                    ControlPanelView(viewModel: viewModel, idealWidth: 220)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear { controlPanelWidth = geometry.size.width }
                                    .onChange(of: geometry.size) { newSize in
                                        controlPanelWidth = newSize.width
                                    }
                            }
                        )
                        .allowsHitTesting(showControls)
                }
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.top, 20)
            .offset(x: showControls ? 0 : hiddenOffset)
            Spacer()
        }

        VStack {
            HStack(alignment: .top, spacing: 12) {
                Button(action: locateUser) {
                    Image(systemName: "location.circle.fill")
                        .font(.title3.weight(.semibold))
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .accessibilityLabel(Text(Accessibility.locateButtonLabel))

                Spacer()
            }
            .padding(
                .leading,
                showControls
                    ? max(controlPanelWidth + 96, 20)
                    : 20
            )
            .padding(.top, 20)
            Spacer()
        }
        }
        .animation(.easeInOut, value: showControls)
        .onAppear { viewModel.bindLocationService(locationService) }
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

    private func performSearch() {
        let query = searchQuery
        Task { await viewModel.searchLocations(for: query) }
    }

    private func locateUser() {
        viewModel.locateUser(using: locationService)
    }
}

extension MapsView {
    enum Accessibility {
        static let locateButtonLabel = "Show my location"
    }
}

// MARK: - Control Panel UI
struct ControlPanelView: View {
    @ObservedObject var viewModel: FiberMapViewModel
    let idealWidth: CGFloat?

    init(viewModel: FiberMapViewModel, idealWidth: CGFloat? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.idealWidth = idealWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Map Controls")
                .font(.headline)
                .padding(.bottom, 2)

            // Layer Toggles
            Text("Layers")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(MapLayer.allCases) { layer in
                    Toggle(isOn: Binding(
                        get: { viewModel.visibleLayers.contains(layer) },
                        set: { _ in viewModel.toggleLayer(layer) }
                    )) {
                        Text(layer.label)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().padding(.vertical, 6)

            // Edit Mode Toggle
            Toggle(isOn: $viewModel.isEditMode.animation()) {
                Text("Edit Mode")
                    .bold()
            }
            .padding(.vertical, 2)

            // Editing Tools
            if viewModel.isEditMode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tools")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(EditTool.allCases) { tool in
                        Button(action: { viewModel.selectTool(tool) }) {
                            HStack(spacing: 8) {
                                Image(systemName: tool.icon)
                                Text(tool.label)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(viewModel.activeTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(10)
                            .tint(viewModel.activeTool == tool ? .primary : .secondary)
                        }
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(.regularMaterial)
        .cornerRadius(15)
        .shadow(radius: 5)
        .frame(width: idealWidth)
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

private extension MapsView {
    @ViewBuilder
    var searchOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search for an address", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit { performSearch() }

                if viewModel.isSearchingLocations {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        viewModel.clearSearchResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }

                Button(action: performSearch) {
                    Text("Search")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = viewModel.searchError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if !viewModel.searchResults.isEmpty {
                Divider()
                    .padding(.top, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchResults) { result in
                            Button {
                                viewModel.selectSearchResult(result)
                                searchQuery = result.title
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if result.id != viewModel.searchResults.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 5)
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

