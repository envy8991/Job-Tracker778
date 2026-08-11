import XCTest
@testable import Job_Tracker

final class AIBackendClientTests: XCTestCase {
    private final class URLProtocolMock: URLProtocol {
        static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            do {
                let (response, data) = try Self.handler!(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        override func stopLoading() { }
    }

    private func client(response: String, status: Int = 200) -> AIBackendClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        URLProtocolMock.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(response.utf8))
        }
        return AIBackendClient(session: URLSession(configuration: configuration), tokenProvider: { "test-token" }, endpoint: { URL(string: "https://example.test/\($0)") })
    }

    func testDecodesNarrowSpliceResponse() async throws {
        let service = GeminiService(backend: client(response: #"{"result":{"content":"splice result"}}"#))
        let value = try await service.generateContent(prompt: "p", systemPrompt: "s", base64Image: "image")
        XCTAssertEqual(value, "splice result")
    }

    func testSurfacesMockedCallableFailure() async {
        let service = GeminiService(backend: client(response: #"{"error":{"message":"Rate limit reached"}}"#, status: 429))
        do {
            _ = try await service.generateContent(prompt: "p", systemPrompt: "s", base64Image: "image")
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Rate limit reached")
        }
    }
}
