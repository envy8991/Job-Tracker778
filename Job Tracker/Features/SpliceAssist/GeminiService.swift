import Foundation
import FirebaseAuth

/// Authenticated transport for the app's Firebase callable AI functions. Provider
/// credentials never enter the application process or its configuration files.
struct AIBackendClient {
    enum ClientError: LocalizedError {
        case notSignedIn, invalidConfiguration, invalidResponse, server(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Sign in before using AI assistance."
            case .invalidConfiguration: return "AI assistance is not configured for this app."
            case .invalidResponse: return "AI assistance returned an unexpected response."
            case .server(let message): return message
            }
        }
    }

    private let session: URLSession
    private let tokenProvider: () async throws -> String
    private let endpoint: (String) -> URL?

    init(session: URLSession = .shared,
         tokenProvider: @escaping () async throws -> String = AIBackendClient.firebaseToken,
         endpoint: @escaping (String) -> URL? = AIBackendClient.firebaseEndpoint) {
        self.session = session
        self.tokenProvider = tokenProvider
        self.endpoint = endpoint
    }

    func call<Request: Encodable, Response: Decodable>(_ name: String, request payload: Request) async throws -> Response {
        guard let url = endpoint(name) else { throw ClientError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await tokenProvider())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(CallableRequest(data: payload))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        if http.statusCode != 200 {
            let error = try? JSONDecoder().decode(CallableErrorEnvelope.self, from: data)
            throw ClientError.server(error?.error.message ?? "AI assistance is temporarily unavailable.")
        }
        guard let result = try? JSONDecoder().decode(CallableResponse<Response>.self, from: data) else { throw ClientError.invalidResponse }
        return result.data
    }

    private static func firebaseToken() async throws -> String {
        guard let user = Auth.auth().currentUser else { throw ClientError.notSignedIn }
        return try await withCheckedThrowingContinuation { continuation in
            user.getIDToken { token, error in
                if let token { continuation.resume(returning: token) }
                else { continuation.resume(throwing: error ?? ClientError.notSignedIn) }
            }
        }
    }

    private static func firebaseEndpoint(_ name: String) -> URL? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let values = NSDictionary(contentsOfFile: path),
              let projectID = values["PROJECT_ID"] as? String else { return nil }
        return URL(string: "https://us-central1-\(projectID).cloudfunctions.net/\(name)")
    }
}

private struct CallableRequest<T: Encodable>: Encodable { let data: T }
private struct CallableResponse<T: Decodable>: Decodable {
    let data: T
    private enum CodingKeys: String, CodingKey { case data, result }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let result = try container.decodeIfPresent(T.self, forKey: .result) { data = result }
        else { data = try container.decode(T.self, forKey: .data) }
    }
}
private struct CallableErrorEnvelope: Decodable {
    struct BackendError: Decodable { let message: String }
    let error: BackendError
}

struct GeminiService {
    struct SpliceRequest: Encodable { let prompt: String; let systemPrompt: String; let imageBase64: String }
    struct SpliceResponse: Decodable { let content: String }
    private let backend: AIBackendClient

    init(backend: AIBackendClient = AIBackendClient()) { self.backend = backend }

    func generateContent(prompt: String, systemPrompt: String, base64Image: String) async throws -> String {
        let response: SpliceResponse = try await backend.call("spliceAssist", request: SpliceRequest(prompt: prompt, systemPrompt: systemPrompt, imageBase64: base64Image))
        return response.content
    }
}
