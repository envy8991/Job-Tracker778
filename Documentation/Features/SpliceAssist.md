# Splice Assist

Splice Assist is an AI-powered troubleshooting tool that analyses uploaded splice maps to suggest fixes, spare assignments, and CAN insights. It leverages Google Gemini through `GeminiService`.

## Responsibilities

- Accept cropped splice map images from the user via `SpliceAssistImagePicker` and prepare them for AI analysis (orientation fix, resizing, JPEG compression).
- Let technicians specify the current CAN identifier, whether a T2 splitter is present, and other context before running analysis.
- Run Gemini multimodal prompts for three primary workflows: troubleshooting missing light, finding spare assignments, and general CAN analysis.
- Present status messages and results back to the user, highlighting success or error states.
- Prevent duplicate submissions while an AI request is running and clear previous results when new inputs are selected.

## Key Types

| Type | Role |
| --- | --- |
| `SpliceAssistView` | SwiftUI surface with segmented actions, image upload controls, text fields, and result presentation. |
| `SpliceAssistViewModel` | Manages image preparation, prompt construction, Gemini requests, and published state (`message`, `result`, `isProcessing`). |
| `GeminiService` | API wrapper responsible for sending prompts and encoded images to the Gemini endpoint and returning structured responses. |
| `SpliceAssistImagePicker` | Utility around `PHPickerViewController`/`UIImagePickerController` for selecting or cropping map images. |

## Workflow

1. **Image Selection** – Users import or crop a map image. The view model stores a Base64 representation so it can be reused across multiple Gemini requests without re-encoding.
2. **Input Gathering** – Depending on the selected action (`Action` enum), users provide CAN identifiers or fibre colour context.
3. **Gemini Request** – `runGeminiRequest` constructs a system prompt tailored to the action and posts it to the AI service alongside the encoded image.
4. **Result Handling** – Responses are normalised into plain text and exposed through `result`. Errors update `message` with `.error` state.

## Integration Notes

- Store the Gemini API key securely (e.g., in an encrypted plist or remote config) and ensure `GeminiService` reads it at runtime.
- Consider caching recent results if technicians often re-run the same analysis to save API quota.
- Wrap network calls in `Task`/`async` contexts so the UI stays responsive. The view model is annotated with `@MainActor` to simplify UI updates.
