
import SwiftUI
import CoreLocation
import UIKit
import MapKit

// MARK: - iOS 26 Glass Helpers (local to CreateJobView)
private let GlassStroke = LinearGradient(
    gradient: Gradient(colors: [
        Color.white.opacity(0.35),
        Color.white.opacity(0.05)
    ]),
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private struct GlassBackground: View {
    var cornerRadius: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(GlassBackground(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlassStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Section Card
@ViewBuilder
private func SectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
        content()
    }
    .padding(16)
    .glassCard()
}

// MARK: - Small Utilities

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - Address Autocomplete (Apple Maps)
final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var distances: [String: Double] = [:] // key: composed title+subtitle, value: miles
    private let completer: MKLocalSearchCompleter

    override init() {
        let c = MKLocalSearchCompleter()
        c.resultTypes = [.address]
        self.completer = c
        super.init()
        self.completer.delegate = self
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.results = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Swallow errors quietly; leave results empty
        DispatchQueue.main.async { [weak self] in
            self?.results = []
        }
    }

    func updateDistances(from userLocation: CLLocation?) {
        guard let userLocation = userLocation else {
            DispatchQueue.main.async { [weak self] in self?.distances = [:] }
            return
        }
        let targets = Array(results.prefix(6))
        for item in targets {
            let key = item.subtitle.isEmpty ? item.title : "\(item.title) \(item.subtitle)"
            // Avoid duplicate lookups
            if distances[key] != nil { continue }

            let request = MKLocalSearch.Request(completion: item)
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, _ in
                guard let coordinate = response?.mapItems.first?.placemark.location else { return }
                let meters = coordinate.distance(from: userLocation)
                let miles = meters / 1609.344
                DispatchQueue.main.async {
                    self?.distances[key] = miles
                }
            }
        }
    }
}

// MARK: - Lightweight Location Provider
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            DispatchQueue.main.async { [weak self] in
                self?.location = loc
            }
            manager.stopUpdatingLocation() // one good fix; saves battery
        }
    }
}

// MARK: - Your CreateJobView (uses AddressField)

struct CreateJobView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    // Form fields
    @State private var addresses: [String] = [""]
    @State private var date = Date()
    @State private var status = "Pending"
    @State private var notes = ""
    @State private var materialsUsed = ""
    @State private var jobNumber = ""
    @State private var customStatusText = ""
    @State private var assignmentsText: String = ""
    @FocusState private var isAssignmentsFocused: Bool
    @FocusState private var focusedAddressIndex: Int?
    @StateObject private var addressSearch = AddressSearchCompleter()
    @StateObject private var locationProvider = LocationProvider()

    @State private var alertMessage: String?

    let statusOptions = ["Pending","Aerial","UG","Nid","Can","Done","Talk to Rick","Custom"]

    // Address suggestion state removed

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.05, green: 0.07, blue: 0.10), location: 0.0),   // deep ink
                        .init(color: Color(red: 0.10, green: 0.13, blue: 0.18), location: 0.35),  // night
                        .init(color: Color(red: 0.12, green: 0.30, blue: 0.36), location: 0.70),  // teal hint
                        .init(color: Color(red: 0.18, green: 0.12, blue: 0.28), location: 1.0)    // purple hint
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Addresses
                        SectionCard(title: addresses.count > 1 ? "Addresses" : "Address") {
                            VStack(spacing: 12) {
                                ForEach(Array(addresses.enumerated()), id: \.offset) { index, _ in
                                    addressField(for: index)
                                }

                                Button {
                                    addresses.append("")
                                    focusedAddressIndex = addresses.count - 1
                                } label: {
                                    Label("Add Another Address", systemImage: "plus.circle")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            .onAppear { locationProvider.request() }
                        }

                        // Date
                        SectionCard(title: "Date") {
                            DatePicker("Select Date", selection: $date, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                        }

                        // Status
                        SectionCard(title: "Status") {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Status", selection: $status) {
                                    ForEach(statusOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)

                                if status == "Custom" {
                                    TextField("Enter custom status", text: $customStatusText)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }

                        // Job Number
                        SectionCard(title: "Job Number *") {
                            TextField("Required", text: $jobNumber)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.9))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                        }

                        // Assignments (role-based)
                        if authViewModel.currentUser?.position == "Can" {
                            SectionCard(title: "Assignments") {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("e.g. 12.3.2", text: $assignmentsText)
                                        .keyboardType(.decimalPad)
                                        .textInputAutocapitalization(.never)
                                        .focused($isAssignmentsFocused)
                                        .onChange(of: assignmentsText) { newValue in
                                            assignmentsText = sanitizeAssignmentTyping(newValue)
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(.systemBackground).opacity(0.9))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                        )

                                    Text("Digits and dots only • examples: 12.3.2, 123.2.4")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if !assignmentsText.isEmpty && !isValidAssignment(assignmentsText) {
                                        Text("Invalid format. Use digits separated by single dots (no leading/trailing dot).")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }

                        // Materials
                        SectionCard(title: "Materials Used") {
                            TextField("Enter materials info…", text: $materialsUsed)
                                .textInputAutocapitalization(.sentences)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.9))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                        }

                        // Notes
                        SectionCard(title: "Notes") {
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.9))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                        }

                        // Save Button (prominent)
                        Button {
                            attemptSave()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(validAddressCount > 1 ? "Save Jobs" : "Save Job")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .glassCard(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Create Job")
            .navigationBarTitleDisplayMode(.inline)
            .jtNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        attemptSave()
                    }
                }
            }
            .alert(alertTitle, isPresented: alertBinding, actions: {
                Button("OK", role: .cancel) { alertMessage = nil }
            }, message: {
                if let alertMessage {
                    Text(alertMessage)
                }
            })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedAddressIndex != nil {
                        Spacer()
                        Button("Done") { focusedAddressIndex = nil }
                    }
                    if isAssignmentsFocused {
                        Button(decimalSeparator) { assignmentsText.append(decimalSeparator) }
                        Spacer()
                        Button("Done") { isAssignmentsFocused = false }
                    }
                }
            }
            .onChange(of: addressSearch.results) { _ in
                addressSearch.updateDistances(from: locationProvider.location)
            }
            .onChange(of: locationProvider.location) { _ in
                addressSearch.updateDistances(from: locationProvider.location)
            }
            .onChange(of: focusedAddressIndex) { newValue in
                guard let newValue else {
                    addressSearch.results = []
                    return
                }
                let current = addresses[safe: newValue] ?? ""
                handleAddressQueryChange(current)
            }
        }
    }

    // MARK: - Save

    private func attemptSave() {
        let trimmedAddresses = addresses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if jobNumber.isEmpty {
            alertMessage = "Please enter a Job Number before saving."
            return
        }

        if trimmedAddresses.isEmpty {
            alertMessage = "Please enter at least one address before saving."
            return
        }

        saveJobs(addressesToSave: trimmedAddresses)
    }

    private func saveJobs(addressesToSave: [String]) {
        guard let userID = authViewModel.currentUser?.id else { dismiss(); return }

        // Normalize legacy spelling ("Ariel" -> "Aerial") before saving
        let baseStatus = (status == "Custom")
            ? customStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
            : status
        let finalStatus = baseStatus.caseInsensitiveCompare("Ariel") == .orderedSame ? "Aerial" : baseStatus

        let sanitizedAssign = sanitizeAssignment(assignmentsText)
        let assignmentsValue = sanitizedAssign.isEmpty || !isValidAssignment(sanitizedAssign) ? nil : sanitizedAssign

        let geocoder = CLGeocoder()

        func processAddress(at index: Int) {
            if index >= addressesToSave.count {
                DispatchQueue.main.async { dismiss() }
                return
            }

            let currentAddress = addressesToSave[index]
            geocoder.geocodeAddressString(currentAddress) { placemarks, _ in
                let coord = placemarks?.first?.location?.coordinate

                let job = Job(
                    address: currentAddress,
                    date: date,
                    status: finalStatus,
                    assignedTo: finalStatus == "Pending" ? nil : userID,
                    createdBy: userID,
                    notes: notes,
                    jobNumber: jobNumber.isEmpty ? nil : jobNumber,
                    assignments: assignmentsValue,
                    materialsUsed: materialsUsed,
                    latitude: coord?.latitude,
                    longitude: coord?.longitude
                )

                DispatchQueue.main.async {
                    jobsViewModel.createJob(job)
                    if index == addressesToSave.count - 1 {
                        dismiss()
                    } else {
                        processAddress(at: index + 1)
                    }
                }
            }
        }

        processAddress(at: 0)
    }

    // MARK: - Assignments helpers

    private func sanitizeAssignmentTyping(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.filter { $0.isNumber || $0 == "." }
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        while s.hasPrefix(".") { s.removeFirst() }
        if s.count > 32 { s = String(s.prefix(32)) }
        return s
    }

    private func sanitizeAssignment(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.filter { $0.isNumber || $0 == "." }
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        if s.hasPrefix(".") { s.removeFirst() }
        if s.hasSuffix(".") { s.removeLast() }
        if s.count > 32 { s = String(s.prefix(32)) }
        return s
    }

    private func isValidAssignment(_ s: String) -> Bool {
        let pattern = "^[0-9]+(\\.[0-9]+)*$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private var decimalSeparator: String { Locale.current.decimalSeparator ?? "." }

    private var validAddressCount: Int {
        addresses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    private var alertTitle: String {
        "Cannot Save"
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue { alertMessage = nil }
            }
        )
    }

    @ViewBuilder
    private func addressField(for index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            TextField("Enter address", text: Binding(
                get: { addresses[index] },
                set: { newValue in
                    addresses[index] = newValue
                    if focusedAddressIndex == index {
                        handleAddressQueryChange(newValue)
                    }
                }
            ))
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .focused($focusedAddressIndex, equals: index)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )

            if focusedAddressIndex == index && !addressSearch.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(addressSearch.results.prefix(6).enumerated()), id: \.offset) { _, item in
                        Button {
                            let composed = item.subtitle.isEmpty ? item.title : "\(item.title) \(item.subtitle)"
                            addresses[index] = composed
                            addressSearch.results = []
                            focusedAddressIndex = nil
                            UIApplication.shared.endEditing()
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body)
                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                let key = item.subtitle.isEmpty ? item.title : "\(item.title) \(item.subtitle)"
                                if let miles = addressSearch.distances[key] {
                                    Text(String(format: "%.1f mi", miles))
                                        .font(.caption.bold())
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 8)
                                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                                        .overlay(Capsule().stroke(Color.gray.opacity(0.25)))
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)

                        if item != addressSearch.results.prefix(6).last {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.top, 58)
            }
        }
        .overlay(alignment: .topTrailing) {
            if addresses.count > 1 {
                Button {
                    removeAddress(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .padding(8)
                .buttonStyle(.plain)
            }
        }
    }

    private func handleAddressQueryChange(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 3 {
            addressSearch.update(query: query)
        } else {
            addressSearch.results = []
        }
    }

    private func removeAddress(at index: Int) {
        guard addresses.indices.contains(index) else { return }
        addresses.remove(at: index)
        if addresses.isEmpty {
            addresses = [""]
        }

        if let focusedIndex = focusedAddressIndex {
            if focusedIndex == index {
                focusedAddressIndex = nil
            } else if focusedIndex > index {
                focusedAddressIndex = focusedIndex - 1
            }
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
