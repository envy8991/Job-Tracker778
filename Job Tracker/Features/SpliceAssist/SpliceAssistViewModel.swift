import SwiftUI
import UIKit

@MainActor
final class SpliceAssistViewModel: ObservableObject {
    enum Action {
        case troubleshoot
        case findAssignment
        case analyze

        var title: String {
            switch self {
            case .troubleshoot:
                return "Troubleshooting"
            case .findAssignment:
                return "Assignment Finder"
            case .analyze:
                return "Splicing Analysis"
            }
        }

        var symbolName: String {
            switch self {
            case .troubleshoot:
                return "exclamationmark.triangle.fill"
            case .findAssignment:
                return "magnifyingglass"
            case .analyze:
                return "bolt.fill"
            }
        }
    }

    struct Message: Identifiable {
        enum Kind {
            case success
            case error
        }

        let id = UUID()
        let text: String
        let kind: Kind
    }

    struct Result: Identifiable {
        let id = UUID()
        let action: Action
        let content: String
    }

    // MARK: - Published state
    @Published private(set) var mapImage: UIImage?
    @Published var canIdentifier: String = ""
    @Published var isT2SplitterPresent: Bool = false

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var message: Message?
    @Published private(set) var result: Result?

    private var mapImageBase64: String?
    private let geminiService: GeminiService

    init(geminiService: GeminiService = GeminiService()) {
        self.geminiService = geminiService
    }

    // MARK: - Derived state
    var hasMapImage: Bool { mapImageBase64 != nil }
    var canRunAnalysis: Bool {
        let trimmed = canIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasMapImage && !trimmed.isEmpty
    }

    // MARK: - Image handling
    func setMapImage(_ image: UIImage?) {
        guard let image else {
            mapImage = nil
            mapImageBase64 = nil
            result = nil
            return
        }

        let preparedImage = image.aiFixingOrientationAndResizingIfNeeded(maxDimension: 2048) ?? image
        guard let jpegData = preparedImage.jpegData(compressionQuality: 0.85) else {
            message = Message(text: "Unable to prepare the selected image. Try choosing a different file.", kind: .error)
            return
        }

        mapImage = UIImage(data: jpegData)
        mapImageBase64 = jpegData.base64EncodedString()
        result = nil
        message = Message(text: "Map cropped for better accuracy!", kind: .success)
    }

    func clearMessage() {
        message = nil
    }

    // MARK: - Actions
    func performTroubleshoot(currentCan: String, missingColor: String) async {
        let trimmedCan = currentCan.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedColor = missingColor.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCan.isEmpty, !trimmedColor.isEmpty else {
            message = Message(text: "Enter both the current can identifier and the missing fiber color.", kind: .error)
            return
        }

        guard let mapImageBase64 else {
            message = Message(text: "Upload and crop a map before troubleshooting.", kind: .error)
            return
        }

        await runGeminiRequest(
            action: .troubleshoot,
            prompt: "Find the source of light for the \(trimmedColor) fiber at can \(trimmedCan).",
            systemPrompt: Self.troubleshootSystemPrompt(currentCan: trimmedCan, missingColor: trimmedColor),
            imageBase64: mapImageBase64
        )
    }

    func performAssignmentSearch() async {
        guard let mapImageBase64 else {
            message = Message(text: "Upload and crop a map before searching for an assignment.", kind: .error)
            return
        }

        await runGeminiRequest(
            action: .findAssignment,
            prompt: "Find a spare assignment in this cropped map.",
            systemPrompt: Self.assignmentSystemPrompt,
            imageBase64: mapImageBase64
        )
    }

    func performAnalysis() async {
        let trimmedIdentifier = canIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedIdentifier.isEmpty else {
            message = Message(text: "Enter a splice can identifier before running the analysis.", kind: .error)
            return
        }

        guard let mapImageBase64 else {
            message = Message(text: "Upload and crop a map before running the analysis.", kind: .error)
            return
        }

        await runGeminiRequest(
            action: .analyze,
            prompt: "Analyze for identifier \"\(trimmedIdentifier)\" in this cropped map.",
            systemPrompt: Self.analysisSystemPrompt(for: trimmedIdentifier, isT2: isT2SplitterPresent),
            imageBase64: mapImageBase64
        )
    }

    // MARK: - Private helpers
    private func runGeminiRequest(action: Action, prompt: String, systemPrompt: String, imageBase64: String) async {
        isProcessing = true
        result = nil
        message = nil

        do {
            let response = try await geminiService.generateContent(
                prompt: prompt,
                systemPrompt: systemPrompt,
                base64Image: imageBase64
            )
            result = Result(action: action, content: response)
        } catch {
            let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            message = Message(text: description, kind: .error)
        }

        isProcessing = false
    }
}

private extension SpliceAssistViewModel {
    static func troubleshootSystemPrompt(currentCan: String, missingColor: String) -> String {
        """
        You are a fiber optic network tracing expert. The user has provided a cropped image focusing on their work area.
        1. Locate the can identifier \"\(currentCan)\" within the user's cropped map image.
        2. From \"\(currentCan)\", visually trace the main fiber line backwards/upstream to find the immediately preceding splice can identifier also visible within the cropped area.
        3. Your response must be ONLY in this structured format:
        Upstream Source: The light for the **\(missingColor)** fiber at **\(currentCan)** originates from the upstream can: **[Upstream Can Identifier]**.
        ---
        Troubleshooting Steps:
        1. **Travel to [Upstream Can Identifier]:** This is the most likely location of the fault.
        2. **Inspect the Splice:** Open the can and locate the splice tray for the **\(missingColor)** fiber.
        3. **Verify Connection:** Check if the **\(missingColor)** fiber was mistakenly used, was never spliced through, or has a bad connection.
        """
    }

    static var assignmentSystemPrompt: String {
        """
        You are an expert map analyst working with a user-cropped image for high accuracy.
        1. Scan the provided cropped map for a **hollow gray circle** icon.
        2. Extract the full identifier text next to the first hollow gray circle you find.
        3. Your response must be ONLY in this format:
        Found Assignment: [Identifier]
        ---
        Explanation: Within the focused area you provided, the identifier **[Identifier]** was selected because it is marked with a hollow gray circle, indicating a spare, unassigned splice point.
        """
    }

    static func analysisSystemPrompt(for identifier: String, isT2: Bool) -> String {
        let splitterState = isT2 ? "PRESENT" : "NOT PRESENT"
        let scenario = isT2 ? "T2" : "Direct Drop"

        return """
        You are a fiber optic expert analyzing a user-cropped image for high accuracy. Follow these steps precisely:
        1. **Locate:** Find \"\(identifier)\" within the focused image.
        2. **Parse:** Extract the final digit from the identifier.
        3. **Map Color:** Based on a T2 splitter being \(splitterState), determine the correct color.
        4. **Formulate Instructions:** Create detailed, bulleted splicing and push light instructions.

        Your response must be ONLY in this structured format:
        Reasoning:
        - **Location:** The identifier \"\(identifier)\" was successfully located in the provided cropped area.
        - **Parsed Digit:** The final digit is [Digit].
        - **Assigned Color:** For a \(scenario) scenario, this corresponds to the **[Color]** fiber.
        ---
        Drop Splicing Actions:
        1. [Step 1 for drop]
        2. [Step 2 for drop]
        3. [Step 3 for drop]
        ---
        Push Light Actions:
        - The following fibers are not assigned here and must be pushed through: **[List of Colors]**.
        1. [Step 1 for push]
        2. [Step 2 for push]
        """
    }
}
