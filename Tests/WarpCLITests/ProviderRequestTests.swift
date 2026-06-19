import XCTest
@testable import WarpCLICore

final class ProviderRequestTests: XCTestCase {
    func testOpenRouterRequestUsesChatCompletionsStreamingShape() throws {
        let client = OpenRouterProviderClient()
        let request = AIChatRequest(
            provider: .openRouter,
            model: "openai/gpt-4o",
            messages: [.user("Summarize this diff")],
            attachments: [],
            stream: true
        )

        let urlRequest = try client.makeURLRequest(request, apiKey: "test-key")
        let body = try XCTUnwrap(urlRequest.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(json?["model"] as? String, "openai/gpt-4o")
        XCTAssertEqual(json?["stream"] as? Bool, true)
        XCTAssertEqual((json?["messages"] as? [[String: Any]])?.first?["role"] as? String, "user")
    }
}
