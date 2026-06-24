import Foundation

final class CopilotAPIClient: AIProviderClient {
    let kind: AIProviderKind = .copilot

    private let tokenStore: CopilotTokenStore
    private let baseURL = URL(string: "https://api.githubcopilot.com/chat/completions")!

    init(tokenStore: CopilotTokenStore = CopilotTokenStore()) {
        self.tokenStore = tokenStore
    }

    func availableModels(apiKey: String) async throws -> [AIModel] {
        [
            AIModel(id: "gpt-4o-copilot", name: "GPT-4o Copilot", supportsVision: false, contextWindow: 128_000),
            AIModel(id: "claude-sonnet-copilot", name: "Claude Sonnet Copilot", supportsVision: false, contextWindow: 200_000)
        ]
    }

    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        guard let token = try tokenStore.load(), !token.isExpired else {
            throw ProviderError.missingAPIKey(AIProviderKind.copilot.rawValue)
        }

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("copilot-chat", forHTTPHeaderField: "Copilot-Integration-Id")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": request.model,
            "stream": true,
            "messages": [
                [
                    "role": "user",
                    "content": request.prompt
                ]
            ]
        ])

        return streamCopilotSSE(request: urlRequest)
    }

    private func streamCopilotSSE(request: URLRequest) -> AsyncThrowingStream<AIResponseChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ProviderError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw ProviderError.invalidResponse
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" {
                            continuation.yield(AIResponseChunk(text: "", isFinal: true))
                            continuation.finish()
                            return
                        }
                        guard let data = payload.data(using: .utf8),
                              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any] else {
                            continue
                        }
                        if let text = delta["content"] as? String, !text.isEmpty {
                            continuation.yield(AIResponseChunk(text: text, isFinal: false))
                        }
                    }

                    continuation.yield(AIResponseChunk(text: "", isFinal: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
