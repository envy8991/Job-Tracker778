import SwiftUI
import UIKit
import Foundation
import CoreLocation

/// A structured entry returned from the GPT-powered parser.
struct ParsedEntry: Identifiable {
    let id = UUID()
    let address: String
    let jobNumber: String?
    let assigneeName: String?
    let assigneeID: String?
    let notes: String?
    let rawText: String?

    init(
        address: String,
        jobNumber: String? = nil,
        assigneeName: String? = nil,
        assigneeID: String? = nil,
        notes: String? = nil,
        rawText: String? = nil
    ) {
        self.address = ParsedEntry.clean(address)
        self.jobNumber = ParsedEntry.normalizeJobNumber(jobNumber)
        self.assigneeName = ParsedEntry.cleanOptional(assigneeName)
        self.assigneeID = ParsedEntry.cleanOptional(assigneeID)
        self.notes = ParsedEntry.cleanOptional(notes)
        self.rawText = ParsedEntry.cleanOptional(rawText)
    }

    /// The best available address for UI/display. Falls back to the raw line when needed.
    var resolvedAddress: String {
        if !address.isEmpty { return address }
        if let raw = rawText, !raw.isEmpty { return raw }
        return "Unknown address"
    }

    /// Notes supplied by GPT, falling back to the raw text when useful.
    var resolvedNotes: String? {
        if let notes = notes, !notes.isEmpty { return notes }
        if let raw = rawText,
           !raw.isEmpty,
           raw.caseInsensitiveCompare(resolvedAddress) != .orderedSame {
            return raw
        }
        return nil
    }

    /// Whether we have enough text to create a job without prompting the user again.
    var hasResolvableAddress: Bool {
        !address.isEmpty || (rawText?.isEmpty == false)
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanOptional(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func normalizeJobNumber(_ value: String?) -> String? {
        guard var trimmed = cleanOptional(value) else { return nil }
        if trimmed.hasPrefix("#") {
            trimmed = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// View that allows supervisors to import a job sheet and parse it using GPT-powered AI.
struct SupervisorJobImportView: View {
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var pickedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var parsedEntries: [ParsedEntry] = []
    @State private var isParsing = false
    @State private var parsingError: Error?
    @State private var pending: Set<String> = []
    @State private var confirmed: Set<String> = []
    @State private var showUploadConsent = false

    // Review → open Create Job prefilled
    private struct ParsedJobFields {
        var address: String
        var jobNumber: String?
        var assigneeID: String?
        var notes: String?
        var date: Date = Date()
    }
    @State private var showReview = false
    @State private var reviewFields: ParsedJobFields? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                JTGradients.background(stops: 4)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: JTSpacing.lg) {
                        headerCard
                        actionCard

                        if let err = parsingError {
                            GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
                                Label(err.localizedDescription, systemImage: "exclamationmark.triangle")
                                    .font(JTTypography.subheadline)
                                    .foregroundStyle(JTColors.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(JTSpacing.lg)
                            }
                        }

                        parsedEntriesSection
                    }
                    .padding(JTSpacing.lg)
                }
            }
            .navigationTitle("Import Job Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .jtNavigationBarStyle()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $pickedImage)
        }
        .sheet(isPresented: $showReview) {
            if let f = reviewFields {
                SupervisorCreateJobView(
                    prefillAddress: f.address,
                    prefillDate: f.date,
                    prefillJobNumber: f.jobNumber,
                    prefillUserID: f.assigneeID,
                    prefillNotes: f.notes
                )
                .environmentObject(jobsViewModel)
                .environmentObject(authViewModel)
                .environmentObject(usersViewModel)
            }
        }
        .alert("Upload Job Sheet?", isPresented: $showUploadConsent) {
            Button("Cancel", role: .cancel) { }
            Button("Upload & Parse") { runParsing() }
        } message: {
            Text("The selected image will be securely sent to Job Tracker's AI provider for parsing. It is processed transiently, is not stored by Job Tracker, and can contain sensitive job details. Provider handling is governed by the company AI agreement.")
        }
        .onAppear {
            if pickedImage == nil {
                showImagePicker = true
            }
        }
    }

    private var headerCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Label("Supervisor Import", systemImage: "doc.text.viewfinder")
                    .font(JTTypography.title3)
                    .foregroundStyle(JTColors.textPrimary)

                Text("Choose a job sheet image, parse it, then import or review each job before it is assigned.")
                    .font(JTTypography.subheadline)
                    .foregroundStyle(JTColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let img = pickedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
                        .overlay {
                            JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius)
                                .stroke(JTColors.glassSoftStroke, lineWidth: 1)
                        }
                } else {
                    HStack(spacing: JTSpacing.sm) {
                        Image(systemName: "photo")
                        Text("No job sheet selected")
                    }
                    .font(JTTypography.subheadline)
                    .foregroundStyle(JTColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JTSpacing.xl)
                    .jtGlassBackground(cornerRadius: JTShapes.smallCardCornerRadius, strokeColor: JTColors.glassSoftStroke)
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    private var actionCard: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
            VStack(spacing: JTSpacing.md) {
                Button {
                    showImagePicker = true
                } label: {
                    Label("Select Job Sheet", systemImage: "photo.on.rectangle")
                        .font(JTTypography.button)
                        .foregroundStyle(JTColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JTSpacing.md)
                        .jtGlassBackground(cornerRadius: JTShapes.buttonCornerRadius, strokeColor: JTColors.glassSoftStroke)
                }
                .buttonStyle(.plain)

                JTPrimaryButton(isParsing ? "Parsing…" : "Parse Sheet", systemImage: "wand.and.stars") {
                    showUploadConsent = true
                }
                .disabled(pickedImage == nil || isParsing)

                Text("Privacy: only the selected sheet is uploaded after confirmation. Job Tracker does not retain the image; request data exists only while processing. Parsed jobs are saved only when you import them.")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isParsing {
                    ProgressView("Reading job sheet…")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                        .tint(JTColors.accent)
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    @ViewBuilder
    private var parsedEntriesSection: some View {
        if parsedEntries.isEmpty {
            GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
                VStack(spacing: JTSpacing.sm) {
                    Image(systemName: "tray")
                        .font(.system(size: 34))
                        .foregroundStyle(JTColors.textMuted)
                    Text("No parsed jobs yet")
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)
                    Text("Parsed jobs will appear here with import and review actions.")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(JTSpacing.xl)
            }
        } else {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Text("Parsed Jobs")
                    .font(JTTypography.title3)
                    .foregroundStyle(JTColors.textPrimary)

                ForEach(parsedEntries) { entry in
                    parsedEntryCard(entry)
                }
            }
        }
    }

    private func parsedEntryCard(_ entry: ParsedEntry) -> some View {
        let entryToken = token(for: entry)
        return GlassCard(cornerRadius: JTShapes.largeCardCornerRadius, strokeColor: JTColors.glassSoftStroke) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack(alignment: .top, spacing: JTSpacing.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.resolvedAddress)
                            .font(JTTypography.headline)
                            .foregroundStyle(JTColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: JTSpacing.xs) {
                            if let jobNumber = entry.jobNumber {
                                importChip("#\(jobNumber)", tint: JTColors.accent)
                            }
                            if let assignee = assigneeDisplayName(for: entry) {
                                importChip(assignee, tint: JTColors.info)
                            }
                        }
                    }

                    Spacer(minLength: JTSpacing.sm)

                    if confirmed.contains(entryToken) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(JTColors.success)
                    } else if pending.contains(entryToken) {
                        ProgressView()
                            .tint(JTColors.accent)
                    }
                }

                if let notes = entry.notes ?? entry.resolvedNotes {
                    Text(notes)
                        .font(JTTypography.subheadline)
                        .foregroundStyle(JTColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if entry.notes != nil,
                   let raw = entry.rawText,
                   !raw.isEmpty,
                   raw.caseInsensitiveCompare(entry.resolvedAddress) != .orderedSame {
                    Text("Original: \(raw)")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !confirmed.contains(entryToken) && !pending.contains(entryToken) {
                    HStack(spacing: JTSpacing.sm) {
                        Button {
                            let fields = fields(for: entry)
                            let supervisorID = authViewModel.currentUser?.id
                            let job = Job(
                                address: fields.address,
                                date: fields.date,
                                status: "Pending",
                                assignedTo: fields.assigneeID ?? "",
                                createdBy: supervisorID ?? "",
                                notes: fields.notes ?? "",
                                jobNumber: fields.jobNumber,
                                assignments: nil,
                                materialsUsed: "",
                                latitude: nil,
                                longitude: nil
                            )
                            importEntry(job, for: entry)
                        } label: {
                            Label("Import", systemImage: "tray.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(JTColors.accent)
                        .disabled(!entry.hasResolvableAddress)

                        Button {
                            reviewFields = fields(for: entry)
                            showReview = true
                        } label: {
                            Label("Review", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(JTColors.accent)
                        .disabled(!entry.hasResolvableAddress)
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    private func importChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(JTTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.vertical, 5)
            .padding(.horizontal, JTSpacing.sm)
            .background(tint.opacity(0.16), in: Capsule())
    }

    // MARK: - Helpers

    private func token(for entry: ParsedEntry) -> String {
        if let jobNumber = entry.jobNumber, !jobNumber.isEmpty {
            return jobNumber
        }
        if !entry.address.isEmpty {
            return entry.address
        }
        if let raw = entry.rawText, !raw.isEmpty {
            return raw
        }
        return entry.id.uuidString
    }

    private func fields(for entry: ParsedEntry) -> ParsedJobFields {
        ParsedJobFields(
            address: entry.resolvedAddress,
            jobNumber: entry.jobNumber,
            assigneeID: entry.assigneeID,
            notes: entry.resolvedNotes
        )
    }

    private func assigneeDisplayName(for entry: ParsedEntry) -> String? {
        if let id = entry.assigneeID,
           let user = usersViewModel.user(id: id) {
            let combined = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty { return combined }
        }
        return entry.assigneeName
    }

    // MARK: - Actions

    /// Runs the GPT parsing on the selected image.
    private func runParsing() {
        guard let image = pickedImage else { return }
        isParsing = true
        parsingError = nil

        Task {
            do {
                let results = try await JobSheetParser.shared.parse(
                    image: image,
                    users: usersViewModel.allUsers
                )
                await MainActor.run {
                    self.parsedEntries = results
                    self.isParsing = false
                }
            } catch {
                await MainActor.run {
                    self.parsingError = error
                    self.isParsing = false
                }
            }
        }
    }

    /// Imports a parsed entry as a Job and tracks the state of the upload.
    /// Geocodes to attach coordinates, mirroring the manual create flow.
    private func importEntry(_ job: Job, for entry: ParsedEntry) {
        let entryToken = token(for: entry)
        pending.insert(entryToken)

        Task {
            let coord = await MapKitGeocoding.coordinate(for: job.address)
            let jobWithCoords = Job(
                address: job.address,
                date: job.date,
                status: job.status,
                assignedTo: job.assignedTo ?? "",
                createdBy: job.createdBy ?? "",
                notes: job.notes ?? "",
                jobNumber: job.jobNumber,
                assignments: job.assignments,
                materialsUsed: job.materialsUsed ?? "",
                latitude: coord?.latitude,
                longitude: coord?.longitude
            )

            await MainActor.run {
                jobsViewModel.createJob(jobWithCoords)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    confirmed.insert(entryToken)
                    pending.remove(entryToken)
                }
            }
        }
    }
}

/// GPT-based parser that extracts structured job data from an image.
final class JobSheetParser {
    static let shared = JobSheetParser()
    private init() {}

    enum ParserError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case malformedJSON(String)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenAI API key."
            case .invalidResponse:
                return "Invalid response from the server."
            case .malformedJSON(let message):
                return message
            case .serverError(let message):
                return message
            }
        }
    }

    private struct ParseRequest: Encodable { let imageBase64: String }
    private struct ParseResponse: Decodable { let items: [RawEntry] }

    func parse(image: UIImage, users: [AppUser]) async throws -> [ParsedEntry] {
        let preparedImage = image.aiFixingOrientationAndResizingIfNeeded(maxDimension: 2048) ?? image
        guard let jpegData = preparedImage.jpegData(compressionQuality: 0.72) else { return [] }
        guard jpegData.count <= 4 * 1024 * 1024 else {
            throw ParserError.serverError("The job sheet is too large. Crop it or choose a lower-resolution image.")
        }
        let response: ParseResponse = try await AIBackendClient().call(
            "parseJobSheet",
            request: ParseRequest(imageBase64: jpegData.base64EncodedString())
        )
        let encoded = try JSONEncoder().encode(response.items)
        // IDs are resolved from the server-side roster; local matching remains only
        // as a compatibility fallback for older endpoint responses.
        return try parseEntries(from: encoded, users: users)
    }

    func parseEntries(from jsonData: Data, users: [AppUser]) throws -> [ParsedEntry] {
        guard !jsonData.isEmpty else {
            throw ParserError.malformedJSON("Parser response was empty. Please try again.")
        }

        let decoder = JSONDecoder()

        let rawEntries: [RawEntry]
        do {
            rawEntries = try decoder.decode([RawEntry].self, from: jsonData)
        } catch {
            do {
                let wrapper = try decoder.decode(ResponseWrapper.self, from: jsonData)
                rawEntries = wrapper.items
            } catch let decodingError {
                throw ParserError.malformedJSON("Failed to decode parser response as job JSON. \(decodingError.localizedDescription)")
            }
        }

        func trimmed(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        let entries = rawEntries.compactMap { raw -> ParsedEntry? in
            let addressCandidate = trimmed(raw.address) ?? trimmed(raw.rawText)
            let rawLine = trimmed(raw.rawText) ?? trimmed(raw.notes) ?? trimmed(raw.address)

            if addressCandidate == nil && rawLine == nil {
                return nil
            }

            let normalizedAssigneeName = trimmed(raw.assigneeName)
            let resolvedAssigneeID = trimmed(raw.assigneeID) ?? assigneeID(for: normalizedAssigneeName, in: users)

            return ParsedEntry(
                address: addressCandidate ?? "",
                jobNumber: raw.jobNumber,
                assigneeName: normalizedAssigneeName,
                assigneeID: resolvedAssigneeID,
                notes: raw.notes,
                rawText: rawLine
            )
        }

        return entries
    }

    private func assigneeID(for name: String?, in users: [AppUser]) -> String? {
        guard let rawName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty else {
            return nil
        }

        let targetComponents = normalizedComponents(from: rawName)
        guard !targetComponents.isEmpty else { return nil }

        for user in users {
            let userComponents = normalizedComponents(from: "\(user.firstName) \(user.lastName)")
            if userComponents == targetComponents {
                return user.id
            }
        }

        for user in users {
            let userComponents = normalizedComponents(from: "\(user.firstName) \(user.lastName)")
            if targetComponents.allSatisfy({ userComponents.contains($0) }) {
                return user.id
            }
        }

        if targetComponents.count == 1, let needle = targetComponents.first {
            for user in users {
                let first = normalizedComponents(from: user.firstName)
                let last = normalizedComponents(from: user.lastName)
                if first.contains(needle) || last.contains(needle) {
                    return user.id
                }
            }
        }

        return nil
    }

    private func normalizedComponents(from value: String) -> [String] {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return folded.split { !$0.isLetter && !$0.isNumber }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private struct RawEntry: Codable {
        let address: String?
        let jobNumber: String?
        let assigneeName: String?
        let assigneeID: String?
        let notes: String?
        let rawText: String?

        private enum CodingKeys: String, CodingKey {
            case address
            case jobNumber
            case jobNo = "job_no"
            case assigneeName
            case assignee
            case assignedTo
            case assigneeID
            case assigneeId
            case assignedUserID
            case assignedUserId = "assigned_user_id"
            case notes
            case note
            case rawText
            case originalText
            case entryText
            case sourceText = "source"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            address = RawEntry.decodeFirstString(for: [.address], in: container)
            jobNumber = RawEntry.decodeFirstString(for: [.jobNumber, .jobNo], in: container)
            assigneeName = RawEntry.decodeFirstString(for: [.assigneeName, .assignee, .assignedTo], in: container)
            assigneeID = RawEntry.decodeFirstString(for: [.assigneeID, .assigneeId, .assignedUserID, .assignedUserId], in: container)
            notes = RawEntry.decodeFirstString(for: [.notes, .note], in: container)
            rawText = RawEntry.decodeFirstString(for: [.rawText, .originalText, .entryText, .sourceText], in: container)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(address, forKey: .address)
            try container.encodeIfPresent(jobNumber, forKey: .jobNumber)
            try container.encodeIfPresent(assigneeName, forKey: .assigneeName)
            try container.encodeIfPresent(assigneeID, forKey: .assigneeId)
            try container.encodeIfPresent(notes, forKey: .notes)
            try container.encodeIfPresent(rawText, forKey: .rawText)
        }

        private static func decodeFirstString(
            for keys: [CodingKeys],
            in container: KeyedDecodingContainer<CodingKeys>
        ) -> String? {
            for key in keys {
                if let value = decodeString(for: key, in: container) {
                    return value
                }
            }
            return nil
        }

        private static func decodeString(
            for key: CodingKeys,
            in container: KeyedDecodingContainer<CodingKeys>
        ) -> String? {
            guard container.contains(key) else { return nil }
            if let string = try? container.decode(String.self, forKey: key) {
                return string
            }
            if let int = try? container.decode(Int.self, forKey: key) {
                return String(int)
            }
            if let double = try? container.decode(Double.self, forKey: key) {
                if double.rounded() == double {
                    return String(Int(double))
                }
                return String(double)
            }
            if let bool = try? container.decode(Bool.self, forKey: key) {
                return String(bool)
            }
            return nil
        }
    }

    private struct ResponseWrapper: Decodable {
        let jobs: [RawEntry]?
        let entries: [RawEntry]?

        var items: [RawEntry] {
            jobs ?? entries ?? []
        }
    }
}
