

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
    @State private var editedPortalID = ""
    @State private var editedLocationNumber = ""
    @State private var selectedMaterialAriel = "None"
    @State private var selectedMaterialNid = ""
    @State private var preformCount = 0
    @State private var jHooksCount = 0
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
    @State private var jobPlacement: String = ""

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
private let jobPlacementChoices = ["OH", "UG"]

    @State private var searchCompleter = SearchCompleterDelegate()

    // Photos
    @State private var showImagePicker = false
    @State private var showPhotoSourceDialog = false
    @State private var activePhotoSlot: JobPhotoSlot?
    @State private var selectedPhotoSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var housePhotoImage: UIImage?
    @State private var nidPhotoImage: UIImage?
    @State private var canPhotoImage: UIImage?

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

    private var isPortalIDInvalid: Bool {
        let trimmed = editedPortalID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && Job.normalizedPortalID(from: trimmed) == nil
    }

    private var isLocationNumberInvalid: Bool {
        let trimmed = editedLocationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && Job.normalizedLocationNumber(from: trimmed) == nil
    }

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
                        TextField("Portal ID", text: $editedPortalID)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .glassCard()
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        if isPortalIDInvalid {
                            Text("Enter a numeric Portal ID or paste a Gibson portal edit link.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12))
                        }
                        TextField("Location Number", text: $editedLocationNumber)
                            .keyboardType(.numberPad)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .glassCard()
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        Text("Use this when there is no Portal ID. Enter the location number or paste a Gibson consumer search link.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 4, trailing: 12))
                        if isLocationNumberInvalid {
                            Text("Enter a numeric location number or paste a Gibson consumer search link.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12))
                        }
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

                    Section(header: Text("OH / UG")) {
                        HStack(spacing: 12) {
                            ForEach(jobPlacementChoices, id: \.self) { choice in
                                Button {
                                    jobPlacement = choice
                                } label: {
                                    Text(choice)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(jobPlacement == choice ? JTColors.accent.opacity(0.25) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(jobPlacement == choice ? JTColors.accent : Color.secondary.opacity(0.35), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
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

                    Section(header: Text("Job Photos")) { jobPhotoSlotsSection }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)   // keep gradient visible
                .navigationTitle("Job Detail")
                .navigationBarTitleDisplayMode(.inline)
                .jtNavigationBarStyle()
                .navBarBackgroundVisibilityIfAvailable(.visible)
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
                                || isPortalIDInvalid
                                || isLocationNumberInvalid
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
            .confirmationDialog(
                "Add Photo",
                isPresented: $showPhotoSourceDialog,
                titleVisibility: .visible
            ) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        selectedPhotoSource = .camera
                        showImagePicker = true
                    }
                }
                Button("Choose from Photos") {
                    selectedPhotoSource = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {
                    activePhotoSlot = nil
                }
            } message: {
                Text("Choose whether to use the camera now or pick an existing picture.")
            }
            .sheet(isPresented: $showImagePicker, onDismiss: {
                activePhotoSlot = nil
                selectedPhotoSource = .photoLibrary
            }) {
                ImagePicker(
                    image: Binding(
                        get: { nil },
                        set: { newImage in
                            guard let newImage else { return }
                            switch activePhotoSlot {
                            case .house:
                                housePhotoImage = newImage
                            case .nid:
                                nidPhotoImage = newImage
                            case .can:
                                canPhotoImage = newImage
                            case .none:
                                break
                            }
                        }
                    ),
                    sourceType: selectedPhotoSource
                )
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
                editedPortalID   = job.portalID ?? ""
                editedLocationNumber = job.locationNumber ?? ""
                selectedMaterialAriel = "None"
                selectedMaterialNid   = nidMaterials.first ?? ""
                canFootage       = job.canFootage ?? ""
                nidFootage       = job.nidFootage ?? ""
                jobPlacement     = job.jobPlacement ?? ""
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
                        jHooksCount = 0
                        parseAerialMaterials(from: materials)
                    case "Nid":
                        parseNidMaterials(from: materials)
                    case "Can":
                        canMaterialsText = sanitizeCanMaterialsTokens(from: materials).joined(separator: ", ")
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
    private var jobPhotoSlotsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            jobPhotoSlotCard(title: "House Picture", urlString: job.housePhotoURL, image: housePhotoImage, slot: .house)
            jobPhotoSlotCard(title: "NID Picture", urlString: job.nidPhotoURL, image: nidPhotoImage, slot: .nid)
            jobPhotoSlotCard(title: "CAN Picture", urlString: job.canPhotoURL, image: canPhotoImage, slot: .can)

            if !job.photos.isEmpty {
                legacyPhotosSection
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private func jobPhotoSlotCard(title: String, urlString: String?, image: UIImage?, slot: JobPhotoSlot) -> some View {
        jobPhotoSlotRow(title: title, urlString: urlString, image: image, slot: slot)
            .glassCard()
    }

    private var legacyPhotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other Job Photos")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(job.photos, id: \.self) { urlString in
                        legacyPhotoThumbnail(urlString: urlString)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .glassCard()
    }

    private func jobPhotoSlotRow(title: String, urlString: String?, image: UIImage?, slot: JobPhotoSlot) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onTapGesture {
                if image == nil, let urlString, let url = URL(string: urlString) {
                    fullScreenImageURL = url
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(image != nil || urlString?.isEmpty == false ? "Ready" : "Not added")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(image != nil || urlString?.isEmpty == false ? "Replace" : "Add") {
                activePhotoSlot = slot
                showPhotoSourceDialog = true
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
        }
    }


    private func legacyPhotoThumbnail(urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { fullScreenImageURL = url }
        } label: {
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
            // J Hooks
            Stepper(value: $jHooksCount, in: 0...50) {
                HStack {
                    Text("J Hooks")
                    Spacer()
                    Text("\(jHooksCount)")
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
        job.portalID = Job.normalizedPortalID(from: editedPortalID)
        job.locationNumber = Job.normalizedLocationNumber(from: editedLocationNumber)
        job.jobPlacement = normalizedPlacement(jobPlacement)

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
                if jHooksCount > 0 { parts.append("J Hooks: \(jHooksCount)") }
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
                var seenTokens = Set<String>()
                func appendUnique(_ token: String) {
                    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let key = trimmed.lowercased()
                    guard !seenTokens.contains(key) else { return }
                    seenTokens.insert(key)
                    parts.append(trimmed)
                }

                if !fiberType.isEmpty { appendUnique("Fiber: \(fiberType)") }
                let customTokens = sanitizeCanMaterialsTokens(from: canMaterialsText)
                customTokens.forEach { appendUnique($0) }
                if uGuardCount > 0 { appendUnique("U-Guard: \(uGuardCount)") }
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

            enqueuePendingPhotosIfNeeded()
            finalizeJobSave()
        }
    }

    private func enqueuePendingPhotosIfNeeded() {
        let pending: [(slot: JobPhotoSlot, image: UIImage)] = [
            housePhotoImage.map { (.house, $0) },
            nidPhotoImage.map { (.nid, $0) },
            canPhotoImage.map { (.can, $0) }
        ].compactMap { $0 }

        guard !pending.isEmpty else { return }
        savingProgress = 0.42
        savingStatus = "Queueing job photos"
        JobPhotoUploadQueue.shared.enqueue(pending, for: job.id)
    }

    private func finalizeJobSave() {
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
    }

    // MARK: - Materials Parsing Helpers
    /// Parse an Aerial materials string we previously saved to restore UI state.
    private func parseAerialMaterials(from text: String) {
        // Expected tokens like: "Weatherhead" or "Rams Head", "Preforms: N", "J Hooks: N", "U-Guard: N", "Storage Bracket"
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
        if let n = captureInt(after: "j hooks:", in: lower) { jHooksCount = n }
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

    /// Split CAN materials free text into clean tokens, filtering out reserved prefixes and duplicates.
    private func sanitizeCanMaterialsTokens(from raw: String) -> [String] {
        var seen = Set<String>()
        var cleaned: [String] = []

        for token in raw.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            guard !lower.hasPrefix("fiber:"), !lower.hasPrefix("u-guard:") else { continue }
            if seen.insert(lower).inserted {
                cleaned.append(trimmed)
            }
        }

        return cleaned
    }

    private func normalizedPlacement(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return jobPlacementChoices.contains(trimmed) ? trimmed : nil
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
}

struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}
