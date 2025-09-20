

import SwiftUI
import MapKit

/* --- iOS 26-ish glass card --- */
private struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial, in:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 12)
    }
}
private extension View {
    func glassCard() -> some View { modifier(GlassCardModifier()) }
}

// Safe wrapper so we can call iOS 18-only toolbarBackgroundVisibility on earlier iOS without compile errors.
extension View {
    @ViewBuilder
    func navBarBackgroundVisibilityIfAvailable(_ visibility: Visibility) -> some View {
        if #available(iOS 18.0, *) {
            self.toolbarBackgroundVisibility(visibility, for: .navigationBar)
        } else {
            self
        }
    }
}

struct JobDetailView: View {
    @Binding var job: Job

    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    // Local states for editing
    @State private var editedStatus = ""
    @State private var customStatusText = ""
    @State private var editedNotes = ""
    @State private var editedJobNumber = ""
    @State private var selectedMaterialAriel = "None"
    @State private var selectedMaterialNid = ""
    @State private var preformCount = 0
    @State private var canFootage = ""     // CAN footage
    @State private var nidFootage = ""

    // Materials refinements per role
    @State private var uGuardCount = 0                 // Aerial & Can: 0–5 U-Guard pieces
    @State private var storageBracket = false          // Aerial: toggle
    @State private var nidBoxUsed = false              // Nid: 1 box (toggle)
    @State private var jumpersCount = 0                // Nid: 0–4 jumpers
    @State private var canMaterialsText = ""           // Can Splicers: free text
    @State private var undergroundMaterialsText = ""   // Underground: free text

    // Fiber type selection (all users)
    @State private var fiberType: String = ""

    // Assignments dotted code (only for Can Splicers in UI)
    @State private var assignmentsText = ""
    @FocusState private var isAssignmentsFocused: Bool
    @FocusState private var isAddressFocused: Bool

    // Address suggestions
    @State private var addressSuggestions = [MKLocalSearchCompletion]()
    @State private var showSuggestions = false
    @State private var disableSuggestions = false  // flag to prevent re-triggering
    @State private var addressText: String = ""

    let statusOptions = [
        "Pending",
        "Needs Aerial",
        "Needs Underground",
        "Needs Nid",
        "Needs Can",
        "Done",
        "Talk to Rick",   // fixed option
        "Custom"          // allows manual entry
    ]
    let arielMaterials = ["None", "Weatherhead", "Rams Head"]
    let nidMaterials: [String] = [] // NID uses toggles/steppers instead of fixed list
private let fiberChoices = ["Flat", "Round", "Mainline"]

    @State private var searchCompleter = SearchCompleterDelegate()

    // Photos
    @State private var showImagePicker = false
    @State private var newImages: [UIImage] = []
    @State private var isPhotoSelectionMode = false
    @State private var selectedPhotoURLs: Set<String> = []
    @State private var showDeletePhotosConfirmation = false

    // Full-screen viewer state
    @State private var fullScreenImageURL: URL? = nil

    // Saving progress HUD
    @State private var showSavingPopup = false
    @State private var savingProgress: Double = 0.0   // 0.0 ... 1.0
    @State private var savingStatus: String = "Starting…"

    // State for delete confirmation alert.
    @State private var showDeleteConfirmation = false

    // Locale-aware decimal separator used by the keyboard toolbar
    private var decimalSeparator: String { Locale.current.decimalSeparator ?? "." }

    var body: some View {
        NavigationStack {
            ZStack {
            JTGradients.background(stops: 4).edgesIgnoringSafeArea(.all)

                // Main editable form
                Form {
                    // MARK: Address
                Section(header: Text("Address")) {
                    TextField("Enter address", text: $addressText)
                        .disableAutocorrection(true)
                        .textContentType(.fullStreetAddress)
                        .textInputAutocapitalization(.never)
                        .focused($isAddressFocused)
                        .onChange(of: addressText) { newValue in
                            guard !disableSuggestions, isAddressFocused else { return }
                            job.address = newValue
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                showSuggestions = false
                                addressSuggestions.removeAll()
                                searchCompleter.completer.queryFragment = ""
                            } else {
                                searchCompleter.completer.queryFragment = newValue
                                showSuggestions = true
                            }
                        }
                        .glassCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                    // MARK: Details
                    Section(header: Text("Details")) {
                        TextField("Job #", text: $editedJobNumber)
                            .glassCard()
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        Picker("Status", selection: $editedStatus) {
                            ForEach(statusOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: editedStatus) { newValue in
                            // If user chose a predefined status, push it immediately
                            if newValue != "Custom" {
                                jobsViewModel.updateJobStatus(job: job, newStatus: newValue)
                            }
                        }
                        .glassCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        if editedStatus == "Custom" {
                            TextField("Enter custom status", text: $customStatusText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    let newStatus = customStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !newStatus.isEmpty { jobsViewModel.updateJobStatus(job: job, newStatus: newStatus) }
                                }
                                .onChange(of: customStatusText) { text in
                                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    // Optionally push live as they type once it's non-empty
                                    if !trimmed.isEmpty { jobsViewModel.updateJobStatus(job: job, newStatus: trimmed) }
                                }
                                .glassCard()
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                        Text(job.date, style: .date)
                            .foregroundColor(.secondary)
                            .glassCard()
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }

                    // MARK: Assignments (Separate) — only for Can Splicers
                    if authViewModel.currentUser?.position == "Can" {
                        Section(header: Text("Assignments")) {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("e.g. 54, 54.1, 12.3.2", text: $assignmentsText)
                                    .keyboardType(.decimalPad)
                                    .textInputAutocapitalization(.never)
                                    .focused($isAssignmentsFocused)
                                    .onChange(of: assignmentsText) { newValue in
                                        // Use typing-safe sanitizer so a trailing dot is allowed while composing
                                        assignmentsText = sanitizeAssignmentTyping(newValue)
                                    }
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("1–3 groups of digits separated by single dots • examples: 54, 54.1, 1.2.3")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if !assignmentsText.isEmpty && !isValidAssignment(assignmentsText) {
                                    Text("Invalid format. Use 1–3 groups of digits separated by single dots (e.g., 54, 54.1, 1.2.3).")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .glassCard()
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }

                    // MARK: Fiber Type (All Users)
                    Section(header: Text("Fiber Type")) {
                        Picker("Type", selection: $fiberType) {
                            ForEach(fiberChoices, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                        .glassCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }

                    // MARK: Materials (Separate Section by Role)
                    if let rawPosition = authViewModel.currentUser?.position {
                        // Normalize legacy "Ariel" → "Aerial" for display
                        let positionDisplay = (rawPosition.caseInsensitiveCompare("Ariel") == .orderedSame) ? "Aerial" : rawPosition

                        Section(header: Text("Materials — \(positionDisplay)")) {
                            switch rawPosition {
                            case "Ariel", "Aerial":
                                arielMaterialsSection
                            case "Nid":
                                nidMaterialsSection
                            case "Can":
                                canMaterialsSection
                            case "Underground":
                                undergroundMaterialsSection
                            default:
                                Text("No materials for this role.")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // MARK: Notes
                    Section(header: Text("Notes")) {
                        VStack {
                            TextEditor(text: $editedNotes)
                                .frame(minHeight: 80)
                        }
                        .glassCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }

                    Section(header: existingPhotosHeader) { existingPhotosSection }
                    Section(header: Text("New Photos"))      { newPhotosSection }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)   // keep gradient visible
                .navigationTitle("Job Detail")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .navBarBackgroundVisibilityIfAvailable(.visible)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { saveChanges() }
                            .disabled(
                                (authViewModel.currentUser?.position == "Can"
                                 && !assignmentsText.isEmpty
                                 && !isValidAssignment(assignmentsText))
                                || showSavingPopup
                            )
                    }
                    // Delete icon when user is creator
                    if job.createdBy == authViewModel.currentUser?.id {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
                // Suggestion overlay
                if showSuggestions && isAddressFocused && !addressSuggestions.isEmpty {
                    suggestionsOverlay
                }
                // Saving progress popup overlay
                if showSavingPopup {
                    savingHUD
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            // Image picker
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: Binding(
                    get: { nil },
                    set: { newImage in
                        if let newImage = newImage { newImages.append(newImage) }
                    }
                ))
            }
            // Delete confirmation
            .alert("Delete Job", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    jobsViewModel.deleteJob(documentID: job.id) { success in
                        if success { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this job? This action cannot be undone.")
            }
            .alert("Delete Selected Photos", isPresented: $showDeletePhotosConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedPhotos()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Remove \(selectedPhotoURLs.count) photo(s) from this job?")
            }
            // Full-screen photo viewer
            .fullScreenCover(item: Binding(
                get: { fullScreenImageURL.map { IdentifiedURL(url: $0) } },
                set: { fullScreenImageURL = $0?.url }
            )) { identified in
                ZStack {
                    Color.black.ignoresSafeArea()
                    AsyncImage(url: identified.url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .ignoresSafeArea()
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                Text("Failed to load image")
                                    .foregroundColor(.white)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                fullScreenImageURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .padding(16)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .toolbar { // Keyboard accessory for Assignments
                ToolbarItemGroup(placement: .keyboard) {
                    if isAssignmentsFocused {
                        Button(decimalSeparator) { assignmentsText.append(decimalSeparator) }
                        Spacer()
                        Button("Done") { isAssignmentsFocused = false }
                    }
                }
            }
            .onAppear {
                disableSuggestions = true
                showSuggestions = false
                addressText = job.address
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    disableSuggestions = false
                }
                // Initialize editable fields
                editedStatus     = job.status
                if !statusOptions.contains(job.status) {
                    customStatusText = job.status
                    editedStatus = "Custom"
                }
                editedNotes      = job.notes ?? ""
                editedJobNumber  = job.jobNumber ?? ""
                selectedMaterialAriel = "None"
                selectedMaterialNid   = nidMaterials.first ?? ""
                canFootage       = job.canFootage ?? ""
                nidFootage       = job.nidFootage ?? ""
                assignmentsText  = job.assignments ?? ""
                searchCompleter.onUpdate = { addressSuggestions = $0 }
                searchCompleter.onFail   = { print("SearchCompleter error:", $0.localizedDescription) }

                // Defaults for new materials fields
                uGuardCount = 0
                storageBracket = false
                nidBoxUsed = false
                jumpersCount = 0

                // Restore previously saved materials into role-specific UI
                if let position = authViewModel.currentUser?.position,
                   let materials = job.materialsUsed, !materials.isEmpty {
                    switch position {
                    case "Ariel":
                        preformCount = 0
                        parseAerialMaterials(from: materials)
                    case "Nid":
                        parseNidMaterials(from: materials)
                    case "Can":
                        canMaterialsText = materials
                        if let n = captureInt(after: "u-guard:", in: materials.lowercased()) { uGuardCount = n }
                    case "Underground":
                        undergroundMaterialsText = materials
                    default:
                        break
                    }
                }

                // Restore fiber type if present
                if let materials = job.materialsUsed?.lowercased() {
                    if materials.contains("fiber: flat") { fiberType = "Flat" }
                    else if materials.contains("fiber: round") { fiberType = "Round" }
                    else if materials.contains("fiber: mainline") { fiberType = "Mainline" }
                }
            }
        }
    }
}

// MARK: - Subviews for JobDetailView
extension JobDetailView {
    // Professional-looking square saving popup
    private var savingHUD: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            // Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Saving…")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(savingProgress * 100))%")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                ProgressView(value: savingProgress)
                    .frame(width: 240)
                Text(savingStatus)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .frame(width: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)
        }
    }
    private var existingPhotosHeader: some View {
        HStack {
            Text("Existing Photos")
            Spacer()
            if isPhotoSelectionMode {
                if !selectedPhotoURLs.isEmpty {
                    Button("Delete (\(selectedPhotoURLs.count))") {
                        showDeletePhotosConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                Button("Cancel") {
                    isPhotoSelectionMode = false
                    selectedPhotoURLs.removeAll()
                }
            } else if !job.photos.isEmpty {
                Button("Select") {
                    isPhotoSelectionMode = true
                }
            }
        }
    }
    // Ariel Materials Section (for Ariel position)
    private var arielMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Head type
            LabeledContent("Head Type") {
                Picker("", selection: $selectedMaterialAriel) {
                    ForEach(arielMaterials, id: \.self) { Text($0) }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
            }
            // Preforms
            Stepper(value: $preformCount, in: 0...50) {
                HStack {
                    Text("Preforms")
                    Spacer()
                    Text("\(preformCount)")
                        .foregroundColor(.secondary)
                }
            }
            // U-Guard
            Stepper(value: $uGuardCount, in: 0...5) {
                HStack {
                    Text("U-Guard")
                    Spacer()
                    Text("\(uGuardCount)")
                        .foregroundColor(.secondary)
                }
            }
            // Storage bracket toggle
            Toggle("Storage Bracket", isOn: $storageBracket)
            // Footage fields.
            TextField("CAN Footage", text: $canFootage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            TextField("NID Footage", text: $nidFootage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
        }
        .padding(.vertical, 2)
        .glassCard()
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    // NID Materials Section (for Nid position)
    private var nidMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("1 NID Box", isOn: $nidBoxUsed)
            Stepper(value: $jumpersCount, in: 0...4) {
                HStack {
                    Text("Jumpers")
                    Spacer()
                    Text("\(jumpersCount)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .glassCard()
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    // Can Splicers: U-Guard + free-text materials + CAN/NID Footage fields
    private var canMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(value: $uGuardCount, in: 0...5) {
                HStack {
                    Text("U-Guard")
                    Spacer()
                    Text("\(uGuardCount)")
                        .foregroundColor(.secondary)
                }
            }
            // Insert CAN/NID Footage inputs here
            TextField("CAN Footage", text: $canFootage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            TextField("NID Footage", text: $nidFootage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            VStack(alignment: .leading, spacing: 6) {
                Text("Materials Notes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextEditor(text: $canMaterialsText)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            }
        }
        .padding(.vertical, 2)
        .glassCard()
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    // Underground: CAN/NID Footage fields and free-text materials notes
    private var undergroundMaterialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Footage inputs (Underground should have these)
            TextField("CAN Footage", text: $canFootage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            TextField("NID Footage", text: $nidFootage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            // Free-text notes (unchanged)
            Text("Materials Notes")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextEditor(text: $undergroundMaterialsText)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
        }
        .padding(.vertical, 2)
        .glassCard()
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    // Existing Photos Section.
    private var existingPhotosSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if job.photos.isEmpty {
                Text("No existing photos")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(job.photos, id: \.self) { urlString in
                            let isSelected = selectedPhotoURLs.contains(urlString)
                            Button {
                                if isPhotoSelectionMode {
                                    if isSelected {
                                        selectedPhotoURLs.remove(urlString)
                                    } else {
                                        selectedPhotoURLs.insert(urlString)
                                    }
                                } else {
                                    if let url = URL(string: urlString) { fullScreenImageURL = url }
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    // Thumbnail
                                    if let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 100, height: 100)
                                                    .clipped()
                                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                                    )
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipped()
                                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                                    )
                                            case .failure:
                                                Color.red.frame(width: 100, height: 100)
                                                    .clipped()
                                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                                    )
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    } else {
                                        Color.gray.frame(width: 100, height: 100)
                                            .clipped()
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    }
                                    // Selection chrome
                                    if isPhotoSelectionMode {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.blue : Color.white, lineWidth: isSelected ? 3 : 1)
                                            .frame(width: 100, height: 100)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .imageScale(.large)
                                            .padding(6)
                                            .foregroundColor(isSelected ? .blue : .white)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    // New Photos Section.
    private var newPhotosSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if newImages.isEmpty {
                Text("No new photos added")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(newImages, id: \.self) { uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            Button("Add Photo") {
                showImagePicker = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .glassCard()
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    // Updated Address Suggestions Overlay.
    private var suggestionsOverlay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(addressSuggestions.prefix(5), id: \.self) { suggestion in
                    Button {
                        job.address = suggestion.title + " " + suggestion.subtitle
                        searchCompleter.completer.queryFragment = ""
                        disableSuggestions = true
                        addressSuggestions.removeAll()
                        showSuggestions = false
                        isAddressFocused = false
                        UIApplication.shared.endEditing()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            disableSuggestions = false
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .fontWeight(.semibold)
                            Text(suggestion.subtitle)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    Divider()
                }
            }
        }
        .frame(maxHeight: 220)
        .glassCard()
        .padding(.horizontal, 24)
        .padding(.top, 160)
    }

    // Save Changes and handle image uploads.
    private func saveChanges() {
        // Show HUD
        showSavingPopup = true
        savingProgress = 0.05
        savingStatus = "Saving address"

        // 1) Update basic fields in memory
        let finalStatus = editedStatus == "Custom"
            ? customStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
            : editedStatus
        job.status    = finalStatus
        job.notes     = editedNotes.isEmpty ? nil : editedNotes
        job.jobNumber = editedJobNumber.isEmpty ? nil : editedJobNumber

        // Assignments (validate & sanitize) — use strict sanitizer on save
        let sanitizedAssign = sanitizeAssignment(assignmentsText)
        job.assignments = sanitizedAssign.isEmpty || !isValidAssignment(sanitizedAssign) ? nil : sanitizedAssign

        // 1a) Save materials by role; write nil if nothing used/typed
        savingProgress = 0.12
        savingStatus = "Saving job number"
        if let position = authViewModel.currentUser?.position {
            switch position {
            case "Ariel":
                var parts: [String] = []
                if !fiberType.isEmpty { parts.append("Fiber: \(fiberType)") }
                if !selectedMaterialAriel.isEmpty && selectedMaterialAriel != "None" {
                    parts.append(selectedMaterialAriel) // Weatherhead or Rams Head
                }
                if preformCount > 0 { parts.append("Preforms: \(preformCount)") }
                if uGuardCount > 0 { parts.append("U-Guard: \(uGuardCount)") }
                if storageBracket { parts.append("Storage Bracket") }
                job.materialsUsed = parts.isEmpty ? nil : parts.joined(separator: ", ")
                job.canFootage = canFootage.isEmpty ? nil : canFootage
                job.nidFootage = nidFootage.isEmpty ? nil : nidFootage

            case "Nid":
                var parts: [String] = []
                if !fiberType.isEmpty { parts.append("Fiber: \(fiberType)") }
                if nidBoxUsed { parts.append("1 NID Box") }
                if jumpersCount > 0 { parts.append("Jumpers: \(jumpersCount)") }
                job.materialsUsed = parts.isEmpty ? nil : parts.joined(separator: ", ")
                job.canFootage = nil
                job.nidFootage = nil

            case "Can":
                var parts: [String] = []
                if !fiberType.isEmpty { parts.append("Fiber: \(fiberType)") }
                let text = canMaterialsText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { parts.append(text) }
                if uGuardCount > 0 { parts.append("U-Guard: \(uGuardCount)") }
                job.materialsUsed = parts.isEmpty ? nil : parts.joined(separator: ", ")
                job.canFootage = canFootage.isEmpty ? nil : canFootage
                job.nidFootage = nidFootage.isEmpty ? nil : nidFootage

            case "Underground":
                let text = undergroundMaterialsText.trimmingCharacters(in: .whitespacesAndNewlines)
                let prefix = fiberType.isEmpty ? nil : "Fiber: \(fiberType)"
                if let prefix = prefix, !text.isEmpty {
                    job.materialsUsed = "\(prefix), \(text)"
                } else if let prefix = prefix {
                    job.materialsUsed = prefix
                } else {
                    job.materialsUsed = text.isEmpty ? nil : text
                }
                job.canFootage = canFootage.isEmpty ? nil : canFootage
                job.nidFootage = nidFootage.isEmpty ? nil : nidFootage

            default:
                if !fiberType.isEmpty { job.materialsUsed = "Fiber: \(fiberType)" }
            }
        }

        if finalStatus.hasPrefix("Needs ") { job.assignedTo = nil }

        // 2) Reverse-geocode address → coordinates
        savingProgress = 0.24
        savingStatus = "Saving materials"
        CLGeocoder().geocodeAddressString(job.address) { placemarks, _ in
            let coord = placemarks?.first?.location?.coordinate
            job.latitude  = coord?.latitude
            job.longitude = coord?.longitude

            // 3) Upload new photos, then save
            if !newImages.isEmpty {
                savingProgress = 0.35
                savingStatus = "Uploading photos (0/\(newImages.count))"
                uploadAllNewImages(onEach: { done, total in
                    let base: Double = 0.35
                    let span: Double = 0.50    // will progress up to 0.85
                    let fraction = total > 0 ? Double(done) / Double(total) : 1.0
                    savingProgress = min(base + span * fraction, 0.85)
                    savingStatus = "Uploading photos (\(done)/\(total))"
                }, completion: { urls in
                    job.photos.append(contentsOf: urls)
                    savingProgress = 0.9
                    savingStatus = "Finalizing"
                    jobsViewModel.updateJob(job)
                    savingProgress = 1.0
                    savingStatus = "Saved"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showSavingPopup = false
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                    }
                })
            } else {
                savingProgress = 0.6
                savingStatus = "Finalizing"
                jobsViewModel.updateJob(job)
                savingProgress = 1.0
                savingStatus = "Saved"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSavingPopup = false
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        dismiss()
                }
            }
        }
    }

    private func uploadAllNewImages(onEach: ((Int, Int) -> Void)? = nil,
                                    completion: @escaping ([String]) -> Void) {
        let group = DispatchGroup()
        var uploadedURLs: [String] = []
        let total = newImages.count
        var completed = 0

        for uiImage in newImages {
            group.enter()
            FirebaseService.shared.uploadImage(uiImage, for: job.id) { result in
                defer {
                    completed += 1
                    onEach?(completed, total)
                    group.leave()
                }
                switch result {
                case .success(let url):
                    uploadedURLs.append(url)
                case .failure(let error):
                    print("Upload error:", error.localizedDescription)
                }
            }
        }

        group.notify(queue: .main) {
            completion(uploadedURLs)
        }
    }

    // MARK: - Materials Parsing Helpers
    /// Parse an Aerial materials string we previously saved to restore UI state.
    private func parseAerialMaterials(from text: String) {
        // Expected tokens like: "Weatherhead" or "Rams Head", "Preforms: N", "U-Guard: N", "Storage Bracket"
        selectedMaterialAriel = "None"
        let lower = text.lowercased()
        if lower.contains("weatherhead") {
            selectedMaterialAriel = "Weatherhead"
        } else if lower.contains("rams head") {
            selectedMaterialAriel = "Rams Head"
        } else {
            // Legacy data may explicitly store "None" as a token
            let tokens = lower.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if tokens.contains("none") { selectedMaterialAriel = "None" }
        }

        if let n = captureInt(after: "preforms:", in: lower) { preformCount = n }
        if let n = captureInt(after: "u-guard:", in: lower) { uGuardCount = n }
        storageBracket = lower.contains("storage bracket")
    }

    /// Parse a NID materials string we previously saved to restore UI state.
    private func parseNidMaterials(from text: String) {
        let lower = text.lowercased()
        nidBoxUsed = lower.contains("nid box")
        if let n = captureInt(after: "jumpers:", in: lower) { jumpersCount = n }
    }

    /// Utility: find an integer value after a given label (case-insensitive). e.g., label "preforms:" in "preforms: 3"
    private func captureInt(after label: String, in haystack: String) -> Int? {
        guard let range = haystack.range(of: label) else { return nil }
        let tail = haystack[range.upperBound...]
        let digits = tail.drop(while: { $0 == " " }).prefix { $0.isNumber }
        return Int(digits)
    }

    // MARK: - Assignment Helpers
    /// Live typing sanitizer: keeps a single trailing dot so users can continue typing (e.g., "12." -> keep).
    private func sanitizeAssignmentTyping(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep only digits and periods
        s = s.filter { $0.isNumber || $0 == "." }
        // Collapse repeated dots to a single dot
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        // Remove leading dots
        while s.hasPrefix(".") { s.removeFirst() }
        // IMPORTANT: do NOT strip a trailing dot here (user may be about to type the next part)
        if s.count > 32 { s = String(s.prefix(32)) }
        return s
    }

    /// Strict sanitizer used on save: trims edge dots and ensures canonical form.
    private func sanitizeAssignment(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.filter { $0.isNumber || $0 == "." }
        while s.contains("..") { s = s.replacingOccurrences(of: "..", with: ".") }
        if s.hasPrefix(".") { s.removeFirst() }
        if s.hasSuffix(".") { s.removeLast() }
        if s.count > 32 { s = String(s.prefix(32)) }
        return s
    }

    /// Valid pattern: 1–3 groups of digits separated by single dots (e.g., 54, 54.1, 1.2.3)
    private func isValidAssignment(_ s: String) -> Bool {
        // Allow 1 to 3 groups of digits separated by single dots, e.g., 54, 54.1, 1.2.3
        let pattern = "^[0-9]+(?:\\.[0-9]+){0,2}$"
        return s.range(of: pattern, options: .regularExpression) != nil
    }
    private func deleteSelectedPhotos() {
        guard !selectedPhotoURLs.isEmpty else { return }
        // Remove the selected URLs from the job model
        let toDelete = selectedPhotoURLs
        job.photos.removeAll { toDelete.contains($0) }
        // Persist change
        jobsViewModel.updateJob(job)
        // Reset selection state
        selectedPhotoURLs.removeAll()
        isPhotoSelectionMode = false
    }
}

struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}
