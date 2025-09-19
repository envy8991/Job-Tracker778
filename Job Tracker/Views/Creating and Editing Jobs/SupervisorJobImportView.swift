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
            VStack(spacing: 20) {
                if let img = pickedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                }

                Button("Select Job Sheet") { showImagePicker = true }

                Button("Parse Sheet") { runParsing() }
                    .disabled(pickedImage == nil || isParsing)

                if isParsing { ProgressView() }

                if let err = parsingError {
                    Text(err.localizedDescription).foregroundColor(.red)
                }

                if parsedEntries.isEmpty {
                    Text("No job sheet selected")
                        .foregroundColor(.secondary)
                } else {
                    List(parsedEntries) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.resolvedAddress)
                                    .font(.headline)

                                if let jobNumber = entry.jobNumber {
                                    Text("Job #: \(jobNumber)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                if let assignee = assigneeDisplayName(for: entry) {
                                    Text("Assignee: \(assignee)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                if let notes = entry.notes {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if let fallbackNotes = entry.resolvedNotes {
                                    Text(fallbackNotes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if entry.notes != nil,
                                   let raw = entry.rawText,
                                   !raw.isEmpty,
                                   raw.caseInsensitiveCompare(entry.resolvedAddress) != .orderedSame {
                                    Text("Original: \(raw)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if confirmed.contains(token(for: entry)) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                            } else if pending.contains(token(for: entry)) {
                                ProgressView()
                            } else {
                                VStack(alignment: .trailing, spacing: 8) {
                                    Button("Import") {
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
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!entry.hasResolvableAddress)

                                    Button("Review…") {
                                        reviewFields = fields(for: entry)
                                        showReview = true
                                    }
                                    .disabled(!entry.hasResolvableAddress)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
        .onAppear {
            if pickedImage == nil {
                showImagePicker = true
            }
        }
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

        CLGeocoder().geocodeAddressString(job.address) { placemarks, _ in
            let coord = placemarks?.first?.location?.coordinate
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

            jobsViewModel.createJob(jobWithCoords)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                confirmed.insert(entryToken)
                pending.remove(entryToken)
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

    func parse(image: UIImage, users: [AppUser]) async throws -> [ParsedEntry] {
        let preparedImage = image.aiFixingOrientationAndResizingIfNeeded(maxDimension: 2048) ?? image
        // The 2048 px cap keeps these 0.8-quality JPEGs around 3–4 MB (≈5 MB once base64-encoded), well under OpenAI's 20 MB
        // per-image upload limit while preserving legible job text.
        guard let jpegData = preparedImage.jpegData(compressionQuality: 0.8) else { return [] }
        guard
            let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
            !apiKey.isEmpty
        else {
            throw ParserError.missingAPIKey
        }

        let base64 = jpegData.base64EncodedString()
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let rosterNames = users
            .map { "\($0.firstName) \($0.lastName)" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let fallbackAssigneeNames = [
            "Brandon",
            "Chris",
            "Hunter",
            "Justin",
            "Nate",
            "Rick",
            "Trey",
            "Will"
        ]

        let displayAssigneeNames: [String]
        if rosterNames.isEmpty {
            displayAssigneeNames = fallbackAssigneeNames
        } else {
            displayAssigneeNames = Array(Set(rosterNames)).sorted()
        }

        let limitedAssigneeNames = Array(displayAssigneeNames.prefix(12))

        let formattedAssigneeNames: String
        if let onlyName = limitedAssigneeNames.first, limitedAssigneeNames.count == 1 {
            formattedAssigneeNames = onlyName
        } else if limitedAssigneeNames.count >= 2, let last = limitedAssigneeNames.last {
            let head = limitedAssigneeNames.dropLast().joined(separator: ", ")
            formattedAssigneeNames = head.isEmpty ? last : "\(head), and \(last)"
        } else {
            formattedAssigneeNames = ""
        }

        let assigneeGuidance: String
        if formattedAssigneeNames.isEmpty {
            assigneeGuidance = "Capture the text exactly as written, even if it's only a first name, initials, or multiple names."
        } else {
            assigneeGuidance = "Expect names such as \(formattedAssigneeNames). Capture the text exactly as written, even if it's only a first name, initials, or multiple names."
        }

        let systemPrompt = """
        You extract structured job information from construction job sheets. Always reply with strictly valid JSON.
        """

        let extractionPrompt = """
        Analyze the provided job sheet image and return a JSON array. Each object must include:
        - "address": the job address as a string (required).
        - "jobNumber": a string job number or null if not shown.
        - "assigneeName": the person's name responsible for the job, or null.
        - "notes": any additional notes or description, or null.
        - "rawText": the original text snippet for this job entry, or null.
        Use null instead of empty strings when data is missing.
        The sheet is a table where each row describes one job. Follow these cues when extracting fields:
        - Column 5 (header "JOB #") contains the job number for that row. Read the string from this cell exactly as written (including values like "12345", "12345 ask Rick", "ask Rick", or "?"). Only use null when the cell is blank or illegible.
        Supervisors provided examples of acceptable job-number formats: 5-digit IDs such as "12345", annotated strings like "12345 ask Rick", and placeholders like "ask Rick" or "?" when the number is pending. Treat these literally as the jobNumber value when present.
        - Column 9 (header "ADDRESS" / "LOCATION") contains the full job address. Use the entire text from this column, including unit numbers or landmarks that appear there.
        - The rightmost column lists the assigned worker name(s). \(assigneeGuidance)
        When populating "rawText", capture the clearest full-line snippet for that row so supervisors can audit the entry later.
        Respond with JSON only (no explanations, markdown, or extra text). Return [] if no jobs are present.
        """

        let jobItemProperties: [String: Any] = [
            "address": ["type": "string"],
            "jobNumber": ["type": ["string", "null"]],
            "assigneeName": ["type": ["string", "null"]],
            "assigneeId": ["type": ["string", "null"]],
            "notes": ["type": ["string", "null"]],
            "rawText": ["type": ["string", "null"]]
        ]

        let jobItemSchema: [String: Any] = [
            "type": "object",
            "required": ["address"],
            "properties": jobItemProperties,
            "additionalProperties": false
        ]

        let responseSchema: [String: Any] = [
            "type": "json_schema",
            "json_schema": [
                "name": "job_sheet_entries",
                "schema": [
                    "type": "array",
                    "items": jobItemSchema
                ]
            ]
        ]

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "response_format": responseSchema,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": extractionPrompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.invalidResponse
        }

        // Surface server-side error messages if present
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw ParserError.serverError(message)
        }

        guard
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            throw ParserError.invalidResponse
        }

        let jsonData: Data
        if let contentItems = message["content"] as? [[String: Any]] {
            if let jsonItem = contentItems.first(where: { ($0["type"] as? String)?.lowercased() == "output_json" }),
               let jsonObject = jsonItem["json"],
               !(jsonObject is NSNull) {
                if JSONSerialization.isValidJSONObject(jsonObject) {
                    jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
                } else if let string = jsonObject as? String {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let data = trimmed.data(using: .utf8), !data.isEmpty else {
                        throw ParserError.malformedJSON("Parser response was empty. Please try again.")
                    }
                    jsonData = data
                } else {
                    throw ParserError.malformedJSON("Parser response was empty. Please try again.")
                }
            } else {
                let textPayload = contentItems.compactMap { item -> String? in
                    if let text = item["text"] as? String { return text }
                    return nil
                }.joined(separator: "\n")

                let trimmedPayload = textPayload.trimmingCharacters(in: .whitespacesAndNewlines)

                guard let data = trimmedPayload.data(using: .utf8), !data.isEmpty else {
                    throw ParserError.malformedJSON("Parser response was empty. Please try again.")
                }

                jsonData = data
            }
        } else if let contentString = message["content"] as? String {
            let trimmed = contentString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = trimmed.data(using: .utf8), !data.isEmpty else {
                throw ParserError.malformedJSON("Parser response was empty. Please try again.")
            }
            jsonData = data
        } else {
            throw ParserError.invalidResponse
        }

        return try parseEntries(from: jsonData, users: users)
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

    private struct RawEntry: Decodable {
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
