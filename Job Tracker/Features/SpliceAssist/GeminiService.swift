import Foundation

struct GeminiService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case serverError(String)
        case emptyContent

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add a Gemini API key to the app configuration before using Splice Assist."
            case .invalidResponse:
                return "The Gemini service returned an unexpected response."
            case .serverError(let message):
                return message
            case .emptyContent:
                return "No content was returned by the Gemini service."
            }
        }
    }

    private let apiKey: String?
    private let urlSession: URLSession

    init(apiKey: String? = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
         urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    func generateContent(prompt: String, systemPrompt: String, base64Image: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequest(
                contents: [
                    .init(parts: [
                        .init(text: prompt),
                        .init(inlineData: .init(mimeType: "image/jpeg", data: base64Image))
                    ])
                ],
                systemInstruction: .init(parts: [.init(text: systemPrompt)])
            )
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let serverError = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                throw ServiceError.serverError(serverError.error.message)
            } else {
                throw ServiceError.serverError("Gemini returned status code \(httpResponse.statusCode).")
            }
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard
            let text = decoded.candidates?.first?.content.parts.first(where: { $0.text != nil })?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            throw ServiceError.emptyContent
        }

        return text
    }
}

private struct GeminiRequest: Encodable {
    struct Content: Encodable {
        var parts: [Part]
    }

    struct Part: Encodable {
        var text: String?
        var inlineData: InlineData?
    }

    struct InlineData: Encodable {
        var mimeType: String
        var data: String
    }

    struct SystemInstruction: Encodable {
        var parts: [Part]
    }

    var contents: [Content]
    var systemInstruction: SystemInstruction
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            var parts: [Part]
        }

        var content: Content
    }

    struct Part: Decodable {
        var text: String?
    }

    var candidates: [Candidate]?
}

private struct GeminiErrorResponse: Decodable {
    struct GeminiError: Decodable {
        var message: String
    }

    var error: GeminiError
}
