//
//  MapsView.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 4/30/25.
//  Updated: Removed Apple Pencil/markup tools and improved Pole Details (assign/footage/photos)
//

import SwiftUI
import MapKit
import Firebase
import FirebaseFirestore
import UIKit
import CoreLocation

// MARK: - Address Search Support
struct AddressSuggestion: Hashable {
    let title: String
    let subtitle: String
}

// Local (Apple) completer
final class LocalCompleter: NSObject, MKLocalSearchCompleterDelegate {
    let completer = MKLocalSearchCompleter()
    var onUpdate: (([AddressSuggestion]) -> Void)?
    var onFail: ((Error) -> Void)?
    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest, .query]
        completer.delegate = self
    }
    func query(_ fragment: String) { completer.queryFragment = fragment }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.prefix(20).map {
            AddressSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        onUpdate?(mapped)
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onFail?(error)
    }
}

// MARK: - Location helper
final class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onUpdate: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestOneShot(_ handler: @escaping (CLLocation) -> Void) {
        onUpdate = handler
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            onUpdate = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onUpdate?(loc); onUpdate = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onUpdate = nil
    }
}

// MARK: - Pole Model
struct Pole: Identifiable, Hashable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D

    // Metadata
    var canAtLocation: Bool = false
    var assignment: String = ""
    var footageFeet: Double? = nil   // stored in feet
    var notes: String = ""
    var photos: [UIImage] = []

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.coordinate = coordinate
    }

    static func == (lhs: Pole, rhs: Pole) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MarkupShape: Identifiable, Hashable {
    enum Kind: String, CaseIterable {
        case line
        case polygon
        case freehand
    }

    let id: UUID
    var kind: Kind
    var points: [CLLocationCoordinate2D]
    var strokeColor: UIColor
    var isDashed: Bool
    var fillColor: UIColor?

    init(id: UUID = UUID(),
         kind: Kind,
         points: [CLLocationCoordinate2D],
         strokeColor: UIColor,
         isDashed: Bool = false,
         fillColor: UIColor? = nil) {
        self.id = id
        self.kind = kind
        self.points = points
        self.strokeColor = strokeColor
        self.isDashed = isDashed
        self.fillColor = fillColor
    }

    static func == (lhs: MarkupShape, rhs: MarkupShape) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - MapCanvas (UIKit MapKit wrapper)
struct MapCanvas: UIViewRepresentable {
    @Binding var poles: [Pole]
    @Binding var region: MKCoordinateRegion
    @Binding var showUserLocation: Bool

    // programmatic region change version (only apply when this changes)
    let regionNonce: Int

    let isInteractionEnabled: Bool
    let mapType: MKMapType
    let onTap: (CLLocationCoordinate2D) -> Void
    let onInsertPole: (Int, CLLocationCoordinate2D) -> Void
    let canInsert: () -> Bool
    let onSelectPole: (Pole) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let mv = MKMapView()
        mv.delegate = context.coordinator
        mv.register(MKMarkerAnnotationView.self,
                    forAnnotationViewWithReuseIdentifier: "pin")
        // Tap
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        mv.addGestureRecognizer(tap)
        // Long-press insert
        let long = UILongPressGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleLong(_:)))
        mv.addGestureRecognizer(long)

        mv.mapType = mapType
        mv.setRegion(region, animated: false)
        context.coordinator.lastAppliedRegionNonce = regionNonce

        mv.showsUserLocation = showUserLocation
        mv.isZoomEnabled = isInteractionEnabled
        mv.isScrollEnabled = isInteractionEnabled
        if #available(iOS 17.0, *) {
            mv.setCameraZoomRange(.init(minCenterCoordinateDistance: 30, maxCenterCoordinateDistance: 1_000_000), animated: false)
        } else {
            mv.setCameraZoomRange(MKMapView.CameraZoomRange(minCenterCoordinateDistance: 30, maxCenterCoordinateDistance: 1_000_000), animated: false)
        }
        mv.isRotateEnabled = true
        mv.isPitchEnabled = false
        mv.showsCompass = true
        mv.camera.heading = 0
        return mv
    }

    func updateUIView(_ mv: MKMapView, context: Context) {
        if mv.mapType != mapType { mv.mapType = mapType }

        // Apply region ONLY when a new nonce is provided (programmatic change).
        if context.coordinator.lastAppliedRegionNonce != regionNonce {
            context.coordinator.suppressRegionCallback = true
            mv.setRegion(region, animated: false)
            context.coordinator.suppressRegionCallback = false
            context.coordinator.lastAppliedRegionNonce = regionNonce
        }

        mv.showsUserLocation = showUserLocation
        mv.isZoomEnabled = isInteractionEnabled
        mv.isScrollEnabled = isInteractionEnabled
        mv.isRotateEnabled = isInteractionEnabled

        context.coordinator.syncPoles(poles, on: mv)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapCanvas
        var suppressRegionCallback = false
        var lastAppliedRegionNonce: Int = -1

        init(parent: MapCanvas) { self.parent = parent }

        private var routeOverlay: MKPolyline?

        private final class PoleAnnotation: MKPointAnnotation {
            let poleID: UUID
            init(id: UUID, coordinate: CLLocationCoordinate2D) {
                self.poleID = id
                super.init()
                self.coordinate = coordinate
            }
        }

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            let mapView = gr.view as! MKMapView
            let coord = mapView.convert(gr.location(in: mapView), toCoordinateFrom: mapView)
            parent.onTap(coord)
        }

        @objc func handleLong(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began else { return }
            let map = gr.view as! MKMapView
            let coord = map.convert(gr.location(in: map), toCoordinateFrom: map)
            let insertIdx = max(0, parent.poles.count - 1)
            guard parent.canInsert() else { return }
            parent.onInsertPole(insertIdx, coord)
        }

        func syncPoles(_ poles: [Pole], on map: MKMapView) {
            let toRemove = map.annotations.compactMap { $0 as? PoleAnnotation }
            map.removeAnnotations(toRemove)
            let anns = poles.map { PoleAnnotation(id: $0.id, coordinate: $0.coordinate) }
            map.addAnnotations(anns)

            if let old = routeOverlay { map.removeOverlay(old) }
            routeOverlay = nil
            if poles.count > 1 {
                let coords = poles.map(\.coordinate)
                let pl = MKPolyline(coordinates: coords, count: coords.count)
                routeOverlay = pl
                map.addOverlay(pl)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pl = overlay as? MKPolyline, pl === routeOverlay {
                let r = MKPolylineRenderer(polyline: pl)
                r.strokeColor = .systemOrange
                r.lineWidth = 4
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? PoleAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "pin", for: ann) as! MKMarkerAnnotationView
            view.isDraggable = true
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .close)
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleSelectPole(_:)))
            view.addGestureRecognizer(tap)
            return view
        }

        @objc private func handleSelectPole(_ gr: UITapGestureRecognizer) {
            guard let view = gr.view as? MKAnnotationView,
                  let ann = view.annotation as? PoleAnnotation,
                  let pole = parent.poles.first(where: { $0.id == ann.poleID })
            else { return }
            parent.onSelectPole(pole)
        }

        func mapView(_ mapView: MKMapView,
                     annotationView view: MKAnnotationView,
                     didChange newState: MKAnnotationView.DragState,
                     fromOldState oldState: MKAnnotationView.DragState) {
            guard (newState == .ending || newState == .canceling),
                  let ann = view.annotation as? PoleAnnotation
            else { return }
            let coord = ann.coordinate
            if let idx = parent.poles.firstIndex(where: { $0.id == ann.poleID }) {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.poles[idx].coordinate = coord
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if suppressRegionCallback { return }
            let new = mapView.region
            let tol = 0.0001
            let old = parent.region
            let changed =
            abs(new.center.latitude - old.center.latitude) > tol ||
            abs(new.center.longitude - old.center.longitude) > tol ||
            abs(new.span.latitudeDelta - old.span.latitudeDelta) > tol ||
            abs(new.span.longitudeDelta - old.span.longitudeDelta) > tol
            if changed {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.region = new
                }
            }
        }
    }
}

// MARK: - MapsView
struct MapsView: View {
    @State private var region = MKCoordinateRegion(
        center: .init(latitude: 37.3349, longitude: -122.0090),
        span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    // programmatic region change version
    @State private var regionSetNonce = 0

    @State private var poles: [Pole] = []
    @State private var markups: [MarkupShape] = []
    @State private var selectedMarkupColor: UIColor = .systemRed
    @State private var selectedMarkupKind: MarkupShape.Kind = .line
    @State private var selectedMarkupIsDashed: Bool = false
    @State private var selectedMarkupFillColor: UIColor? = nil
    @State private var totalDistance: Double = 0
    @State private var showingHelp = false
    @State private var selectedPole: Pole?
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var mapTypeIndex = 0
    @State private var showDeleteOptions = false
    private let mapTypes: [MKMapType] = [.hybrid, .standard, .mutedStandard] // default imagery
    // Private session (invite-only)
    @State private var sessionID: String? = nil
    @State private var isHost: Bool = false
    @State private var participantsOnline: Int = 0
    @State private var showJoinSheet = false
    @State private var joinCodeInput = ""
    @State private var showInviteShare = false
    @State private var currentUserID: String = UIDevice.current.identifierForVendor?.uuidString ?? "anon"
    @State private var sessionListener: ListenerRegistration? = nil
    @State private var presenceListener: ListenerRegistration? = nil
    @State private var isApplyingRemoteUpdate = false

    @State private var didSetInitialRegion = false
    @State private var showUserLocation = false
    @StateObject private var locationFetcher = LocationFetcher()

    private func centerToDefaultAddress() {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = "1207 S College St, Trenton, TN 38382"
        req.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.98, longitude: -88.94),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        MKLocalSearch(request: req).start { resp, _ in
            guard let item = resp?.mapItems.first,
                  let coord = item.placemark.location?.coordinate else {
                didSetInitialRegion = true
                return
            }
            withAnimation {
                region.center = coord
                region.span = MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                regionSetNonce &+= 1
            }
            didSetInitialRegion = true
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                MapCanvas(
                    poles: $poles,
                    region: $region,
                    showUserLocation: $showUserLocation,
                    regionNonce: regionSetNonce,
                    isInteractionEnabled: true,
                    mapType: mapTypes[mapTypeIndex],
                    onTap: { coord in addPole(coord) },
                    onInsertPole: insertPole,
                    canInsert: { true },
                    onSelectPole: { selectedPole = $0 }
                )
                .ignoresSafeArea()
                .safeAreaInset(edge: .top) {
                    searchBar
                        .padding(.horizontal, 12)
                        .padding(.top, 60)
                        .zIndex(1)
                }
            }
            .onChange(of: poles) { _ in
                recalculateDistance()
                pushSessionStateIfNeeded()
            }
            .onChange(of: markups) { _ in
                pushSessionStateIfNeeded()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ActivityView(activityItems: [url])
                }
            }
            .sheet(isPresented: $showJoinSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Enter Session Code")) {
                            TextField("e.g. A1B2C3", text: $joinCodeInput)
                                .textInputAutocapitalization(.characters)
                                .disableAutocorrection(true)
                        }
                    }
                    .navigationTitle("Join Session")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showJoinSheet = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Join") {
                                let code = joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                joinSession(with: code)
                                showJoinSheet = false
                            }.disabled(joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showInviteShare) {
                if let code = sessionID {
                    ActivityView(activityItems: ["Join my Route Mapper session with code: \(code)"])
                }
            }
            .onAppear {
                currentUserID = UIDevice.current.identifierForVendor?.uuidString ?? "anon"
                localCompleter.onUpdate = { suggestions = $0; showSuggestions = isSearchFocused && !searchText.isEmpty }
                localCompleter.onFail = { _ in suggestions = []; showSuggestions = false }
                if !didSetInitialRegion {
                    centerToDefaultAddress()
                }
            }
            .onDisappear { endSession() }
            .onChange(of: searchText) { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count < 2 {
                    suggestions = []
                    showSuggestions = false
                } else {
                    showSuggestions = true
                    localCompleter.query(trimmed)
                }
            }
            .onChange(of: isSearchFocused) { focused in
                if !focused { showSuggestions = false }
            }

            controlOverlay
        }
        .navigationTitle("Route Mapper")
        .sheet(isPresented: $showingHelp) { RouteMapperHelp() }
        .sheet(item: $selectedPole) { pole in
            PoleInspectorView(pole: pole) { updated in
                if let idx = poles.firstIndex(where: { $0.id == updated.id }) {
                    poles[idx] = updated
                    recalculateDistance()
                }
            }
        }
    }

    // Address search state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showSuggestions: Bool = false
    @State private var suggestions: [AddressSuggestion] = []
    @State private var localCompleter = LocalCompleter()

    private func addPole(_ coord: CLLocationCoordinate2D) {
        poles.append(Pole(coordinate: coord))
    }

    private func insertPole(at idx: Int, _ coord: CLLocationCoordinate2D) {
        poles.insert(Pole(coordinate: coord), at: idx)
    }

    private func recalculateDistance() {
        totalDistance = poles.enumerated().dropFirst().reduce(0) { acc, pair in
            let prev = poles[pair.offset-1].coordinate
            let curr = pair.element.coordinate
            return acc + CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                .distance(from: CLLocation(latitude: curr.latitude, longitude: curr.longitude))
        }
    }

    private func formattedDistance(_ meters: Double) -> String {
        let fmt = LengthFormatter()
        fmt.unitStyle = .short
        fmt.numberFormatter.maximumFractionDigits = 2
        return fmt.string(fromMeters: meters)
    }

    // Jump to the user's current location
    private func jumpToUser() {
        locationFetcher.requestOneShot { loc in
            showUserLocation = true
            withAnimation {
                region.center = loc.coordinate
                region.span = MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                regionSetNonce &+= 1
            }
        }
    }

    // MARK: - PDF Export
    private func exportRoute() {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 800, height: 800)

        MKMapSnapshotter(options: options).start { snapshot, _ in
            guard let snapshot = snapshot else { return }
            let image = UIGraphicsImageRenderer(size: options.size).image { ctx in
                snapshot.image.draw(at: .zero)
                if poles.count > 1 {
                    ctx.cgContext.setStrokeColor(UIColor.systemOrange.cgColor)
                    ctx.cgContext.setLineWidth(4)
                    let pts = poles.map(\.coordinate).map { snapshot.point(for: $0) }
                    ctx.cgContext.addLines(between: pts)
                    ctx.cgContext.strokePath()
                }
            }
            if let url = RoutePDFGenerator.generate(
                poles: poles, mapImage: image, totalDistance: totalDistance
            ) {
                pdfURL = url
                showShareSheet = true
            }
        }
    }

    @ViewBuilder
    private var controlOverlay: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Session banner + controls
            if let code = sessionID {
                HStack(spacing: 8) {
                    Text("Session: \(code)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                    Text("Online: \(participantsOnline)")
                        .font(.caption2)
                        .padding(6)
                        .background(.thinMaterial, in: Capsule())
                    Button { showInviteShare = true } label: {
                        Image(systemName: "person.crop.circle.badge.plus").padding(6)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    Button(role: .destructive) { endSession() } label: {
                        Image(systemName: "xmark.circle.fill").padding(6)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                }
            } else {
                HStack(spacing: 8) {
                    Button { startSession() } label: {
                        Label("Start Session", systemImage: "person.2.fill")
                            .labelStyle(.iconOnly)
                            .padding(6)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    Button { showJoinSheet = true } label: {
                        Label("Join", systemImage: "link")
                            .labelStyle(.iconOnly)
                            .padding(6)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                }
            }

            Picker("", selection: $mapTypeIndex) {
                Image(systemName: "photo").tag(0)       // Hybrid (imagery) default
                Image(systemName: "map").tag(1)         // Standard
                Image(systemName: "moon.stars").tag(2)  // Muted Standard
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            if poles.count > 1 {
                Text("Total: \(formattedDistance(totalDistance))")
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                Button(action: { jumpToUser() }) {
                    Image(systemName: "location.fill").padding(10)
                }
                .background(.ultraThinMaterial, in: Circle())

                Button(action: { showingHelp = true }) {
                    Image(systemName: "questionmark.circle").padding(10)
                }
                .background(.ultraThinMaterial, in: Circle())

                Button(action: { showDeleteOptions = true }) {
                    Image(systemName: "trash").padding(10)
                }
                .background(.ultraThinMaterial, in: Circle())
                .confirmationDialog("Delete", isPresented: $showDeleteOptions, titleVisibility: .visible) {
                    Button("Delete Last Pole", role: .destructive) {
                        if !poles.isEmpty { poles.removeLast(); recalculateDistance() }
                    }
                    Button("Clear Route (All Poles)", role: .destructive) {
                        poles.removeAll(); totalDistance = 0
                    }
                    Button("Cancel", role: .cancel) { }
                }

                Button(action: { exportRoute() }) {
                    Image(systemName: "square.and.arrow.up").padding(10)
                }
                .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding()
    }
    
    
    // MARK: - Search UI
    @ViewBuilder
    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search address", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        suggestions = []
                        showSuggestions = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if showSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(8), id: \.self) { s in
                        Button {
                            isSearchFocused = false
                            showSuggestions = false
                            performSearch(for: s)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "mappin.circle")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.title).font(.callout).foregroundColor(.primary)
                                    if !s.subtitle.isEmpty {
                                        Text(s.subtitle).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                        }
                        .background(Color(.systemBackground).opacity(0.9))
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 34)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 6)
            }
        }
        .zIndex(2)
    }

    private func performSearch(for suggestion: AddressSuggestion) {
        let query = suggestion.subtitle.isEmpty ? suggestion.title : "\(suggestion.title), \(suggestion.subtitle)"
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        MKLocalSearch(request: request).start { resp, _ in
            guard let item = resp?.mapItems.first,
                  let coord = item.placemark.location?.coordinate else { return }
            withAnimation {
                region.center = coord
                region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                regionSetNonce &+= 1
            }
            addPole(coord)
        }
    }
    // MARK: - Help Sheet
    struct RouteMapperHelp: View {
        @Environment(\.dismiss) private var dismiss
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Route Mapper Guide").font(.title2).bold()
                        Group {
                            Text("Search: Use the search bar; tap a suggestion to zoom and drop a pole.")
                            Text("Add poles: Tap the map to drop poles in order. Long-press to insert between existing poles.")
                            Text("Move/delete poles: Drag a pin to reposition. Tap a pin → Close button to delete, or use the trash.")
                            Text("Edit details: Tap a pin to open details. Assignment accepts 54, 54.1, or 1.2.3. Add footage, notes, and photos.")
                            Text("Map gestures: Pinch to zoom, two-finger rotate. Tap the compass to face North.")
                            Text("Your location: Tap the target button to jump to your current position (grant permission if asked).")
                            Text("Map style: Use the segmented control to switch between Imagery, Standard, and Muted.")
                            Text("Realtime sessions: Start Session to host or Join with a code. Use the share button to invite; the ‘Online’ badge shows who’s in.")
                            Text("Export: The share icon exports a PDF with the route and details.")
                            Text("Tip: The map won’t snap back while you pan/zoom; it only recenters when you search or jump to a location.")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("How to Use")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Pole Inspector (improved)
    struct PoleInspectorView: View {
        @Environment(\.dismiss) private var dismiss
        @State var pole: Pole
        let onSave: (Pole) -> Void

        // Local UI state
        @State private var footageText: String = ""
        @State private var footageUnit: FootageUnit = .feet
        @State private var isPhotoSelectionMode = false
        @State private var selectedPhotoIndices = Set<Int>()
        @State private var showImagePicker = false
        @State private var fullScreenImage: UIImage? = nil

        enum FootageUnit: String, CaseIterable, Identifiable {
            case feet = "ft"
            case meters = "m"
            var id: String { rawValue }
        }

        private func isValidAssignment(_ s: String) -> Bool {
            let pattern = "^[0-9]+(?:\\.[0-9]+){0,2}$"
            return s.range(of: pattern, options: .regularExpression) != nil
        }

        private func prepareInitialFootage() {
            if let ft = pole.footageFeet {
                footageText = String(Int(round(ft))) // show as whole feet by default
                footageUnit = .feet
            } else {
                footageText = ""
                footageUnit = .feet
            }
        }

        var body: some View {
            NavigationView {
                Form {
                    // Assignment + CAN
                    Section("Assignment") {
                        HStack {
                            TextField("e.g. 54, 54.1, 1.2.3", text: $pole.assignment)
                                .keyboardType(.numbersAndPunctuation)
                            if !pole.assignment.isEmpty {
                                Image(systemName: isValidAssignment(pole.assignment) ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                    .foregroundColor(isValidAssignment(pole.assignment) ? .green : .red)
                            }
                        }
                        Toggle("CAN at location", isOn: $pole.canAtLocation)
                    }

                    // Footage
                    Section("Footage") {
                        HStack {
                            TextField("Length", text: $footageText)
                                .keyboardType(.numberPad)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.trailing)
                            Picker("", selection: $footageUnit) {
                                ForEach(FootageUnit.allCases) { u in
                                    Text(u.rawValue).tag(u)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                        Text("Optional. Saved in feet. If you enter meters, we’ll convert.").font(.caption).foregroundColor(.secondary)
                    }

                    // Notes
                    Section("Notes") {
                        TextEditor(text: $pole.notes).frame(minHeight: 100)
                    }

                    // Photos
                    Section {
                        HStack {
                            Text("Photos").font(.headline)
                            Spacer()
                            if isPhotoSelectionMode {
                                if !selectedPhotoIndices.isEmpty {
                                    Button(role: .destructive) {
                                        let sorted = selectedPhotoIndices.sorted(by: >)
                                        for idx in sorted { pole.photos.remove(at: idx) }
                                        selectedPhotoIndices.removeAll()
                                    } label: { Text("Delete Selected") }
                                }
                                Button("Done") { isPhotoSelectionMode = false; selectedPhotoIndices.removeAll() }
                            } else {
                                Button("Select") {
                                    isPhotoSelectionMode = true
                                    selectedPhotoIndices.removeAll()
                                }
                                Button {
                                    showImagePicker = true
                                } label: {
                                    Label("Add", systemImage: "plus")
                                }
                            }
                        }

                        if pole.photos.isEmpty {
                            Text("No photos yet. Tap Add to attach.").foregroundColor(.secondary)
                        } else {
                            let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(Array(pole.photos.enumerated()), id: \.offset) { idx, img in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if isPhotoSelectionMode {
                                                    if selectedPhotoIndices.contains(idx) {
                                                        selectedPhotoIndices.remove(idx)
                                                    } else {
                                                        selectedPhotoIndices.insert(idx)
                                                    }
                                                } else {
                                                    fullScreenImage = img
                                                }
                                            }

                                        if isPhotoSelectionMode {
                                            Image(systemName: selectedPhotoIndices.contains(idx) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedPhotoIndices.contains(idx) ? .accentColor : .white)
                                                .imageScale(.large)
                                                .padding(6)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 6)
                        }
                    }

                    // Location quick copy
                    Section("Location") {
                        HStack {
                            Text("Lat/Lon")
                            Spacer()
                            Text("\(String(format: "%.6f", pole.coordinate.latitude)), \(String(format: "%.6f", pole.coordinate.longitude))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .contextMenu {
                                    Button("Copy Coordinates") {
                                        UIPasteboard.general.string = "\(pole.coordinate.latitude),\(pole.coordinate.longitude)"
                                    }
                                }
                        }
                        Button {
                            UIPasteboard.general.string = "\(pole.coordinate.latitude),\(pole.coordinate.longitude)"
                        } label: {
                            Label("Copy Coordinates", systemImage: "doc.on.doc")
                        }
                    }
                }
                .navigationTitle("Pole Details")
                .onAppear { prepareInitialFootage() }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            // normalize footage to feet
                            let trimmed = footageText.trimmingCharacters(in: .whitespaces)
                            if let val = Double(trimmed) {
                                if footageUnit == .meters {
                                    pole.footageFeet = val * 3.28084
                                } else {
                                    pole.footageFeet = val
                                }
                            } else {
                                pole.footageFeet = nil
                            }
                            onSave(pole)
                            dismiss()
                        }
                        .disabled(!pole.assignment.isEmpty && !isValidAssignment(pole.assignment))
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: Binding(
                        get: { nil },
                        set: { img in if let img = img { pole.photos.append(img) } }
                    ))
                }
                .fullScreenCover(item: Binding(
                    get: {
                        if let img = fullScreenImage { return ImageBox(image: img) }
                        return nil
                    },
                    set: { box in fullScreenImage = box?.image }
                )) { box in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Image(uiImage: box.image)
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    fullScreenImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 28, weight: .bold))
                                        .padding()
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }

        // tiny wrapper for fullScreenCover
        struct ImageBox: Identifiable { let id = UUID(); let image: UIImage }
    }

    // MARK: - Route PDF Generator
    struct RoutePDFGenerator {
        static func generate(poles: [Pole], mapImage: UIImage, totalDistance: Double) -> URL? {
            let pdfMeta = [
                kCGPDFContextCreator: "Job Tracker",
                kCGPDFContextAuthor:  "Route Mapper"
            ] as CFDictionary
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("Route_\(UUID().uuidString).pdf")
            UIGraphicsBeginPDFContextToFile(tmpURL.path, .zero, pdfMeta as [NSObject:AnyObject])
            UIGraphicsBeginPDFPage()
            let title = "Route Map"
            title.draw(at: CGPoint(x: 40, y: 40),
                       withAttributes: [.font: UIFont.boldSystemFont(ofSize: 24)])
            mapImage.draw(in: CGRect(x: 40, y: 80, width: 500, height: 500))
            var rowY = 600
            "Pole | Assignment | CAN | Footage | Notes"
                .draw(at: CGPoint(x: 40, y: rowY),
                      withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
            rowY += 24
            for (i, pole) in poles.enumerated() {
                let footageStr: String = {
                    if let ft = pole.footageFeet {
                        let n = NumberFormatter()
                        n.maximumFractionDigits = 0
                        return "\(n.string(from: NSNumber(value: ft)) ?? "\(Int(ft))") ft"
                    }
                    return "—"
                }()
                let line = "\(i+1) | \(pole.assignment.isEmpty ? "—" : pole.assignment) | \(pole.canAtLocation ? "Yes" : "No") | \(footageStr) | \(pole.notes)"
                line.draw(at: CGPoint(x: 40, y: rowY),
                          withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
                rowY += 18
            }
            let len = LengthFormatter()
            len.unitStyle = .short
            let totalStr = "Total: \(len.string(fromMeters: totalDistance))"
            totalStr.draw(at: CGPoint(x: 40, y: rowY+20),
                          withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
            UIGraphicsEndPDFContext()
            return tmpURL
        }
    }

    // MARK: - Private Session Helpers (Firestore)
    private func startSession() {
        let code = generateSessionCode()
        let db = Firestore.firestore()
        let doc = db.collection("routeSessions").document(code)
        let payload: [String: Any] = [
            "createdBy": currentUserID,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "poles": serializePoles(poles),
            "markups": serializeMarkups(markups)
        ]
        doc.setData(payload) { err in
            guard err == nil else { return }
            self.sessionID = code
            self.isHost = true
            self.setupSessionListeners(for: code)
            self.updatePresence(online: true)
        }
    }

    private func joinSession(with code: String) {
        let db = Firestore.firestore()
        let doc = db.collection("routeSessions").document(code)
        doc.getDocument { snap, err in
            guard err == nil, let snap = snap, snap.exists else { return }
            self.sessionID = code
            self.isHost = false
            self.setupSessionListeners(for: code)
            self.updatePresence(online: true)
        }
    }

    private func endSession() {
        if let _ = sessionID {
            self.updatePresence(online: false)
            self.sessionListener?.remove(); self.sessionListener = nil
            self.presenceListener?.remove(); self.presenceListener = nil
        }
        self.sessionID = nil
        self.isHost = false
        self.participantsOnline = 0
        self.markups.removeAll()
        self.poles.removeAll()
        self.totalDistance = 0
    }

    private func setupSessionListeners(for code: String) {
        let db = Firestore.firestore()
        self.sessionListener = db.collection("routeSessions").document(code)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }
                let poleItems = data["poles"] as? [[String: Any]] ?? []
                let markupItems = data["markups"] as? [[String: Any]] ?? []
                let remotePoles = self.deserializePoles(poleItems)
                let remoteMarkups = self.deserializeMarkups(markupItems)
                self.isApplyingRemoteUpdate = true
                self.poles = remotePoles
                self.markups = remoteMarkups
                self.recalculateDistance()
                DispatchQueue.main.async { self.isApplyingRemoteUpdate = false }
            }
        self.presenceListener = db.collection("routeSessions").document(code)
            .collection("participants")
            .whereField("online", isEqualTo: true)
            .addSnapshotListener { snap, _ in
                self.participantsOnline = snap?.documents.count ?? 0
            }
    }

    private func updatePresence(online: Bool) {
        guard let code = sessionID else { return }
        let db = Firestore.firestore()
        let ref = db.collection("routeSessions").document(code)
            .collection("participants").document(currentUserID)
        ref.setData([
            "online": online,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func pushSessionStateIfNeeded() {
        if sessionID != nil && !isApplyingRemoteUpdate {
            pushSessionState()
        }
    }

    private func pushSessionState() {
        guard let code = sessionID else { return }
        let db = Firestore.firestore()
        db.collection("routeSessions").document(code).setData([
            "poles": serializePoles(poles),
            "markups": serializeMarkups(markups),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func serializePoles(_ poles: [Pole]) -> [[String: Any]] {
        poles.map {
            [
                "id": $0.id.uuidString,
                "lat": $0.coordinate.latitude,
                "lng": $0.coordinate.longitude,
                "assignment": $0.assignment,
                "can": $0.canAtLocation,
                "footageFeet": $0.footageFeet as Any,
                "notes": $0.notes
            ].compactMapValues { $0 }
        }
    }

    private func serializeMarkups(_ markups: [MarkupShape]) -> [[String: Any]] {
        markups.map { shape in
            var dict: [String: Any] = [
                "id": shape.id.uuidString,
                "kind": shape.kind.rawValue,
                "points": shape.points.map { ["lat": $0.latitude, "lng": $0.longitude] },
                "color": hexString(from: shape.strokeColor),
                "isDashed": shape.isDashed
            ]
            if let fill = shape.fillColor {
                dict["fillColor"] = hexString(from: fill)
            }
            return dict
        }
    }

    private func deserializePoles(_ items: [[String: Any]]) -> [Pole] {
        items.compactMap { dict in
            guard let lat = dict["lat"] as? CLLocationDegrees,
                  let lng = dict["lng"] as? CLLocationDegrees else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let poleID: UUID = {
                if let idString = dict["id"] as? String,
                   let uuid = UUID(uuidString: idString) {
                    return uuid
                }
                return UUID()
            }()

            var p = Pole(id: poleID, coordinate: coordinate)
            if let assignment = dict["assignment"] as? String { p.assignment = assignment }
            if let can = dict["can"] as? Bool { p.canAtLocation = can }
            if let feet = dict["footageFeet"] as? Double { p.footageFeet = feet }
            if let notes = dict["notes"] as? String { p.notes = notes }
            return p
        }
    }

    private func deserializeMarkups(_ items: [[String: Any]]) -> [MarkupShape] {
        items.compactMap { dict in
            let identifier: UUID = {
                if let idString = dict["id"] as? String, let uuid = UUID(uuidString: idString) {
                    return uuid
                }
                return UUID()
            }()

            let kind: MarkupShape.Kind = {
                if let raw = dict["kind"] as? String, let kind = MarkupShape.Kind(rawValue: raw) {
                    return kind
                }
                return .freehand
            }()

            let pointDictionaries = dict["points"] as? [[String: Any]] ?? []
            let coords = pointDictionaries.compactMap { entry -> CLLocationCoordinate2D? in
                guard let lat = entry["lat"] as? CLLocationDegrees,
                      let lng = entry["lng"] as? CLLocationDegrees else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }

            let strokeColor: UIColor = {
                if let hex = dict["color"] as? String, let color = color(fromHex: hex) {
                    return color
                }
                return .systemRed
            }()

            let fillColor: UIColor? = {
                guard let hex = dict["fillColor"] as? String else { return nil }
                return color(fromHex: hex)
            }()

            let isDashed = dict["isDashed"] as? Bool ?? false

            return MarkupShape(
                id: identifier,
                kind: kind,
                points: coords,
                strokeColor: strokeColor,
                isDashed: isDashed,
                fillColor: fillColor
            )
        }
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        if !color.getRed(&r, green: &g, blue: &b, alpha: &a),
           let converted = color.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
           ),
           let components = converted.components {
            switch components.count {
            case 4:
                r = components[0]; g = components[1]; b = components[2]; a = components[3]
            case 2:
                r = components[0]; g = components[0]; b = components[0]; a = components[1]
            default:
                break
            }
        }

        let clamp: (CGFloat) -> CGFloat = { min(max($0, 0), 1) }
        let red = Int(round(clamp(r) * 255))
        let green = Int(round(clamp(g) * 255))
        let blue = Int(round(clamp(b) * 255))
        let alpha = Int(round(clamp(a) * 255))
        return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    private func color(fromHex hex: String) -> UIColor? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        let r, g, b, a: CGFloat
        if cleaned.count == 6 {
            r = CGFloat((value & 0xFF0000) >> 16) / 255.0
            g = CGFloat((value & 0x00FF00) >> 8) / 255.0
            b = CGFloat(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = CGFloat((value & 0xFF000000) >> 24) / 255.0
            g = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(value & 0x000000FF) / 255.0
        }

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    private func generateSessionCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

// Small toggle icon chip (kept for consistency if you want to reuse)
private struct ToggleIcon: View {
    let isOn: Bool
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .padding(8)
                .background(isOn ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Circle())
        }
        .background(.ultraThinMaterial, in: Circle())
    }
}
