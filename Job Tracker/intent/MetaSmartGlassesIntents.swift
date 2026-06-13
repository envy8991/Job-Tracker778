import AppIntents
import Foundation

@available(iOS 26.0, *)
enum MetaEvidenceTypeIntentEnum: String, AppEnum {
    case footage = "Footage"
    case house = "House Photo"
    case nid = "NID Photo"
    case can = "CAN Photo"
    case note = "Note"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Evidence Type"

    static var caseDisplayRepresentations: [MetaEvidenceTypeIntentEnum: DisplayRepresentation] = [
        .footage: "Footage",
        .house: "House Photo",
        .nid: "NID Photo",
        .can: "CAN Photo",
        .note: "Note"
    ]
}

@available(iOS 26.0, *)
struct AddMetaSmartGlassesJobNoteIntent: AppIntent {
    static var openAppWhenRun: Bool = false
    static var title: LocalizedStringResource = "Add Meta Glasses Job Evidence"
    static var description = IntentDescription("Adds a hands-free Meta smart glasses evidence note to the current or nearest job.")

    @Parameter(title: "Evidence Type")
    var evidenceType: MetaEvidenceTypeIntentEnum

    @Parameter(title: "Details", requestValueDialog: "What should I add to the job?")
    var details: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\AddMetaSmartGlassesJobNoteIntent.$evidenceType) note: \(\AddMetaSmartGlassesJobNoteIntent.$details)")
    }

    func perform() async throws -> some ProvidesDialog {
        guard MetaSmartGlassesSettings.isEnabled else {
            return .result(dialog: IntentDialog("Turn on Meta Smart Glasses capture assistant in Job Tracker Settings first."))
        }

        let resolution = try await JobIntentResolver.nearestJobOrDialog()
        guard case .success(let target) = resolution else {
            if case .failure(let dialog) = resolution { return .result(dialog: dialog) }
            return .result(dialog: IntentDialog("I couldn't find a current job."))
        }

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDetails.isEmpty else {
            return .result(dialog: IntentDialog("Please provide details to add."))
        }

        let timestamp = Date().formatted(.dateTime.month(.abbreviated).day().hour().minute())
        let entry = "[Meta Glasses • \(evidenceType.rawValue) • \(timestamp)] \(trimmedDetails)"
        let existing = target.job.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let updatedNotes = existing.isEmpty ? entry : "\(existing)\n\(entry)"

        do {
            try await FirebaseService.shared.updateJobFieldsAsync(jobId: target.job.id, fields: ["notes": updatedNotes])
            var dialog = "Added \(evidenceType.rawValue.lowercased()) evidence to \(JobIntentFormatter.jobContext(target))."
            if let fallbackReason = target.fallbackReason {
                dialog += " \(fallbackReason)"
            }
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        } catch {
            return .result(dialog: IntentDialog("Couldn't add the Meta glasses note: \(error.localizedDescription)"))
        }
    }
}
