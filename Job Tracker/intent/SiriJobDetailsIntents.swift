import AppIntents
import Foundation

@available(iOS 16.0, *)
struct GetNearestJobAssignmentIntent: AppIntent {
    static var openAppWhenRun: Bool = false
    static var title: LocalizedStringResource = "Get Current Job Assignment"
    static var description = IntentDescription("Reads the assignment for the job you are at or closest to today.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get the current job assignment")
    }

    func perform() async throws -> some ProvidesDialog {
        switch try await JobIntentResolver.nearestJobOrDialog() {
        case .failure(let dialog):
            return .result(dialog: dialog)
        case .success(let target):
            let context = JobIntentFormatter.jobContext(target)
            guard let assignment = JobIntentFormatter.spokenValue(target.job.assignments) else {
                let prefix = target.fallbackReason.map { "\($0) " } ?? ""
                return .result(dialog: IntentDialog("\(prefix)There isn't an assignment saved for \(context)."))
            }

            let prefix = target.fallbackReason.map { "\($0) " } ?? ""
            return .result(dialog: IntentDialog("\(prefix)The assignment for \(context) is \(assignment)."))
        }
    }
}

@available(iOS 16.0, *)
struct SetNearestJobAssignmentIntent: AppIntent {
    static var openAppWhenRun: Bool = false
    static var title: LocalizedStringResource = "Set Current Job Assignment"
    static var description = IntentDescription("Saves an assignment code on the job you are at or closest to today.")

    @Parameter(title: "Assignment", requestValueDialog: "What assignment should I save?")
    var assignment: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set current job assignment to \(.$assignment)")
    }

    func perform() async throws -> some ProvidesDialog {
        switch try await JobIntentResolver.nearestJobOrDialog() {
        case .failure(let dialog):
            return .result(dialog: dialog)
        case .success(let target):
            let trimmedAssignment = assignment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAssignment.isEmpty else {
                return .result(dialog: IntentDialog("Please tell me the assignment to save."))
            }

            do {
                try await FirebaseService.shared.updateJobFieldsAsync(
                    jobId: target.job.id,
                    fields: ["assignments": trimmedAssignment]
                )
            } catch {
                return .result(dialog: IntentDialog("I couldn't save the assignment: \(error.localizedDescription)"))
            }

            let prefix = target.fallbackReason.map { "\($0) " } ?? ""
            return .result(dialog: IntentDialog("\(prefix)Saved assignment \(trimmedAssignment) for \(JobIntentFormatter.jobContext(target))."))
        }
    }
}

@available(iOS 16.0, *)
struct SetNearestJobFootageIntent: AppIntent {
    static var openAppWhenRun: Bool = false
    static var title: LocalizedStringResource = "Add Current Job Footage"
    static var description = IntentDescription("Adds CAN and NID footage to the job you are at or closest to today.")

    @Parameter(title: "CAN Footage", requestValueDialog: "What is the CAN footage?")
    var canFootage: String

    @Parameter(title: "NID Footage", requestValueDialog: "What is the NID footage?")
    var nidFootage: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add CAN \(.$canFootage) and NID \(.$nidFootage) footage")
    }

    func perform() async throws -> some ProvidesDialog {
        switch try await JobIntentResolver.nearestJobOrDialog() {
        case .failure(let dialog):
            return .result(dialog: dialog)
        case .success(let target):
            let can = canFootage.trimmingCharacters(in: .whitespacesAndNewlines)
            let nid = nidFootage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !can.isEmpty || !nid.isEmpty else {
                return .result(dialog: IntentDialog("Please tell me the CAN footage, the NID footage, or both."))
            }

            var fields: [String: Any] = [:]
            if !can.isEmpty { fields["canFootage"] = can }
            if !nid.isEmpty { fields["nidFootage"] = nid }

            do {
                try await FirebaseService.shared.updateJobFieldsAsync(jobId: target.job.id, fields: fields)
            } catch {
                return .result(dialog: IntentDialog("I couldn't save the footage: \(error.localizedDescription)"))
            }

            var pieces: [String] = []
            if let canLabel = JobIntentFormatter.footageLabel(can) { pieces.append("CAN \(canLabel)") }
            if let nidLabel = JobIntentFormatter.footageLabel(nid) { pieces.append("NID \(nidLabel)") }
            let prefix = target.fallbackReason.map { "\($0) " } ?? ""
            return .result(dialog: IntentDialog("\(prefix)Saved \(pieces.joined(separator: " and ")) for \(JobIntentFormatter.jobContext(target))."))
        }
    }
}

@available(iOS 16.0, *)
struct GetNearestJobFootageIntent: AppIntent {
    static var openAppWhenRun: Bool = false
    static var title: LocalizedStringResource = "Get Current Job Footage"
    static var description = IntentDescription("Reads the saved CAN and NID footage for the job you are at or closest to today.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get current job footage")
    }

    func perform() async throws -> some ProvidesDialog {
        switch try await JobIntentResolver.nearestJobOrDialog() {
        case .failure(let dialog):
            return .result(dialog: dialog)
        case .success(let target):
            let can = JobIntentFormatter.footageLabel(target.job.canFootage)
            let nid = JobIntentFormatter.footageLabel(target.job.nidFootage)
            guard can != nil || nid != nil else {
                let prefix = target.fallbackReason.map { "\($0) " } ?? ""
                return .result(dialog: IntentDialog("\(prefix)There isn't any CAN or NID footage saved for \(JobIntentFormatter.jobContext(target))."))
            }

            var pieces: [String] = []
            if let can { pieces.append("CAN \(can)") }
            if let nid { pieces.append("NID \(nid)") }
            let prefix = target.fallbackReason.map { "\($0) " } ?? ""
            return .result(dialog: IntentDialog("\(prefix)For \(JobIntentFormatter.jobContext(target)), \(pieces.joined(separator: " and "))."))
        }
    }
}

@available(iOS 16.0, *)
struct GetNearestJobSummaryIntent: AppIntent {
    static var openAppWhenRun: Bool = false
    static var title: LocalizedStringResource = "Get Current Job Details"
    static var description = IntentDescription("Summarizes the job you are at or closest to today, including status, assignment, and footage.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get current job details")
    }

    func perform() async throws -> some ProvidesDialog {
        switch try await JobIntentResolver.nearestJobOrDialog() {
        case .failure(let dialog):
            return .result(dialog: dialog)
        case .success(let target):
            var details = ["status \(target.job.displayStatus)"]
            if let assignment = JobIntentFormatter.spokenValue(target.job.assignments) {
                details.append("assignment \(assignment)")
            }
            if let can = JobIntentFormatter.footageLabel(target.job.canFootage) {
                details.append("CAN \(can)")
            }
            if let nid = JobIntentFormatter.footageLabel(target.job.nidFootage) {
                details.append("NID \(nid)")
            }
            if let jobNumber = JobIntentFormatter.spokenValue(target.job.jobNumber) {
                details.append("job number \(jobNumber)")
            }

            let prefix = target.fallbackReason.map { "\($0) " } ?? ""
            return .result(dialog: IntentDialog("\(prefix)For \(JobIntentFormatter.jobContext(target)): \(details.joined(separator: ", "))."))
        }
    }
}
