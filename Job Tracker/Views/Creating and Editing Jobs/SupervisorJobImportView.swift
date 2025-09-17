import SwiftUI
import UIKit
import Foundation
import CoreLocation

/// A single parsed line or entry from a job import sheet.
struct ParsedEntry: Identifiable {
    let id = UUID()
    let text: String
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
                        HStack {
                            Text(entry.text)
                            Spacer()
                            if confirmed.contains(token(for: entry)) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                            } else if pending.contains(token(for: entry)) {
                                ProgressView()
                            } else {
                                Button("Import") {
                                    let fields = extractFields(from: entry.text)
                                    let supervisorID = authViewModel.currentUser?.id
                                    let job = Job(
                                        address: fields.address,
                                        date: fields.date,
                                        status: "Pending",
                                        assignedTo: fields.assigneeID ?? "",   // creates it for the right user
                                        createdBy: supervisorID ?? "",         // important for rules/audit
                                        notes: fields.notes ?? "",
                                        jobNumber: fields.jobNumber,
                                        assignments: nil,
                                        materialsUsed: "",
                                        latitude: nil,
                                        longitude: nil
                                    )
                                    importEntry(job)
                                }
                                .buttonStyle(.bordered)

                                Button("Review…") {
                                    reviewFields = extractFields(from: entry.text)
                                    showReview = true
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

    // MARK: - Helpers (parsing/assignee resolution)

    private func token(for entry: ParsedEntry) -> String {
        // Prefer job # if present, else fall back to address guess; we’ll recompute via extractFields.
        let f = extractFields(from: entry.text)
        return f.jobNumber ?? f.address
    }

    /// Find a user whose name appears in the line. Matches first, last, or full name.
    private func resolveAssigneeID(in text: String) -> String? {
        let haystack = text.lowercased()
        for u in usersViewModel.allUsers {
            let first = u.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let last  = u.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let full  = (first + " " + last).trimmingCharacters(in: .whitespaces)
            if (!first.isEmpty && haystack.contains(first)) ||
               (!last.isEmpty && haystack.contains(last)) ||
               (!full.isEmpty && haystack.contains(full)) {
                return u.id
            }
        }
        return nil
    }

    /// Extract likely address, job number, and assignee from a raw OCR line.
    private func extractFields(from text: String) -> ParsedJobFields {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var addressCandidate = trimmed
        var jobNumberCandidate: String? = nil
        var assigneeIDCandidate: String? = nil

        // 1) Job number like 1234 / 12-345 / #1234
        if let match = trimmed.range(of: "[#]?([0-9]{3,}[A-Za-z0-9\\-]*)", options: .regularExpression) {
            let token = String(trimmed[match])
            jobNumberCandidate = token.replacingOccurrences(of: "#", with: "")
        }

        // 2) Resolve assignee by name
        assigneeIDCandidate = resolveAssigneeID(in: trimmed)

        // 3) Address-like prefix: house number + street words, stop at a comma if present
        if let regex = try? NSRegularExpression(pattern: "^\\s*\\d+\\s+[A-Za-z0-9 .'\\u2019\\u2013\\u2014-]+") {
            let ns = trimmed as NSString
            if let m = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                var leading = ns.substring(with: m.range)
                if let comma = leading.firstIndex(of: ",") { leading = String(leading[..<comma]) }
                addressCandidate = leading.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ParsedJobFields(
            address: addressCandidate,
            jobNumber: jobNumberCandidate,
            assigneeID: assigneeIDCandidate,
            notes: nil
        )
    }

    // MARK: - Actions

    /// Runs the GPT parsing on the selected image.
    private func runParsing() {
        guard let image = pickedImage else { return }
        isParsing = true
        parsingError = nil

        Task {
            do {
                let results = try await JobSheetParser.shared.parse(image: image)
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
    private func importEntry(_ job: Job) {
        let token = job.jobNumber ?? job.address
        pending.insert(token)

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
                confirmed.insert(token)
                pending.remove(token)
            }
        }
    }
}

/// GPT-based parser that extracts text lines from an image.
final class JobSheetParser {
    static let shared = JobSheetParser()
    private init() {}

    enum ParserError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenAI API key."
            case .invalidResponse:
                return "Invalid response from the server."
            case .serverError(let message):
                return message
            }
        }
    }

    func parse(image: UIImage) async throws -> [ParsedEntry] {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return [] }
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

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "Extract each job entry as a separate line."],
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

        let text: String
        if let contents = message["content"] as? [[String: Any]] {
            text = contents.compactMap { $0["text"] as? String }.joined(separator: "\n")
        } else if let contentString = message["content"] as? String {
            text = contentString
        } else {
            throw ParserError.invalidResponse
        }
        let lines = text
            .split(separator: "\n")
            .map { ParsedEntry(text: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.text.isEmpty }
        return lines
    }
}
