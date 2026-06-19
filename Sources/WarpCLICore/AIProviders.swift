import Foundation

public struct AIChatRequest: Equatable {
    public var provider: CLIProvider
    public var model: String
    public var messages: [AIMessage]
    public var attachments: [AIImageAttachment]
    public var stream: Bool

    public init(provider: CLIProvider, model: String, messages: [AIMessage], attachments: [AIImageAttachment] = [], stream: Bool = true) {
        self.provider = provider
        self.model = model
        self.messages = messages
        self.attachments = attachments
        self.stream = stream
    }
}

public struct AIMessage: Equatable, Codable {
    public enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    public var role: Role
    public var content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }

    public static func system(_ content: String) -> AIMessage {
        AIMessage(role: .system, content: content)
    }

    public static func user(_ content: String) -> AIMessage {
        AIMessage(role: .user, content: content)
    }

    public static func assistant(_ content: String) -> AIMessage {
        AIMessage(role: .assistant, content: content)
    }
}

public struct AIImageAttachment: Equatable {
    public var data: Data
    public var mimeType: String

    public init(data: Data, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

public struct AIResponseChunk: Equatable {
    public enum Kind: Equatable {
        case token
        case toolCall
        case done
        case error
    }

    public var kind: Kind
    public var text: String

    public init(kind: Kind = .token, text: String) {
        self.kind = kind
        self.text = text
    }
}

public struct AIModelDescriptor: Codable, Equatable, Identifiable {
    public var id: String
    public var providerPrefix: String
    public var contextWindow: Int
    public var supportsVision: Bool

    public init(id: String, providerPrefix: String, contextWindow: Int, supportsVision: Bool) {
        self.id = id
        self.providerPrefix = providerPrefix
        self.contextWindow = contextWindow
        self.supportsVision = supportsVision
    }
}

public enum AIProviderError: Error, LocalizedError {
    case missingAPIKey(CLIProvider)
    case invalidResponse
    case httpStatus(Int, String)
    case unsupportedProvider(CLIProvider)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "No API key found for \(provider.displayName). Run `warp config --provider \(provider.rawValue) --api-key ...`."
        case .invalidResponse:
            "The provider returned an invalid response."
        case .httpStatus(let status, let body):
            "Provider returned HTTP \(status): \(body)"
        case .unsupportedProvider(let provider):
            "\(provider.displayName) does not support this operation."
        }
    }
}

public protocol AIProviderClient {
    func makeURLRequest(_ request: AIChatRequest, apiKey: String) throws -> URLRequest
    func stream(_ request: AIChatRequest, apiKey: String) -> AsyncThrowingStream<AIResponseChunk, Error>
}

public final class OpenRouterProviderClient: AIProviderClient {
    public init() {}

    public func makeURLRequest(_ request: AIChatRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("WarpClone CLI", forHTTPHeaderField: "X-Title")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: openAICompatibleBody(for: request))
        return urlRequest
    }

    public func stream(_ request: AIChatRequest, apiKey: String) -> AsyncThrowingStream<AIResponseChunk, Error> {
        streamOpenAICompatible(request, apiKey: apiKey, makeURLRequest)
    }

    public func fetchModels(apiKey: String) async throws -> [AIModelDescriptor] {
        var urlRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)

        struct Response: Decodable {
            struct Model: Decodable {
                struct Architecture: Decodable {
                    var modality: String?
                }

                var id: String
                var context_length: Int?
                var architecture: Architecture?
            }

            var data: [Model]
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.data.map { model in
            AIModelDescriptor(
                id: model.id,
                providerPrefix: model.id.split(separator: "/").first.map(String.init) ?? "custom",
                contextWindow: model.context_length ?? 0,
                supportsVision: model.architecture?.modality?.localizedCaseInsensitiveContains("image") ?? false
            )
        }
    }
}

public final class OpenAICompatibleProviderClient: AIProviderClient {
    public var baseURL: URL

    public init(baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        self.baseURL = baseURL
    }

    public func makeURLRequest(_ request: AIChatRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: openAICompatibleBody(for: request))
        return urlRequest
    }

    public func stream(_ request: AIChatRequest, apiKey: String) -> AsyncThrowingStream<AIResponseChunk, Error> {
        streamOpenAICompatible(request, apiKey: apiKey, makeURLRequest)
    }
}

public final class AnthropicProviderClient: AIProviderClient {
    public init() {}

    public func makeURLRequest(_ request: AIChatRequest, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let messages = request.messages.filter { $0.role != .system }.map { ["role": $0.role.rawValue, "content": $0.content] }
        let system = request.messages.first(where: { $0.role == .system })?.content
        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": 4096,
            "messages": messages,
            "stream": request.stream
        ]
        if let system {
            body["system"] = system
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    public func stream(_ request: AIChatRequest, apiKey: String) -> AsyncThrowingStream<AIResponseChunk, Error> {
        streamSSE(request, apiKey: apiKey, makeRequest: makeURLRequest) { line in
            guard line.hasPrefix("data:") else { return nil }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            if json["type"] as? String == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return AIResponseChunk(text: text)
            }
            return nil
        }
    }
}

public final class GeminiProviderClient: AIProviderClient {
    public init() {}

    public func makeURLRequest(_ request: AIChatRequest, apiKey: String) throws -> URLRequest {
        let encodedModel = request.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? request.model
        var urlRequest = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent?key=\(apiKey)")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let contents = request.messages.map { message in
            [
                "role": message.role == .assistant ? "model" : "user",
                "parts": [["text": message.content]]
            ] as [String: Any]
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: ["contents": contents])
        return urlRequest
    }

    public func stream(_ request: AIChatRequest, apiKey: String) -> AsyncThrowingStream<AIResponseChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlRequest = try makeURLRequest(request, apiKey: apiKey)
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    try validate(response: response, data: data)
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let candidates = json?["candidates"] as? [[String: Any]]
                    let content = candidates?.first?["content"] as? [String: Any]
                    let parts = content?["parts"] as? [[String: Any]]
                    let text = parts?.compactMap { $0["text"] as? String }.joined() ?? ""
                    continuation.yield(AIResponseChunk(text: text))
                    continuation.yield(AIResponseChunk(kind: .done, text: ""))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

public final class AIProviderRegistry {
    private let clients: [CLIProvider: AIProviderClient]
    private let keychain: CLIKeychainStore

    public init(keychain: CLIKeychainStore = CLIKeychainStore()) {
        self.keychain = keychain
        self.clients = [
            .openRouter: OpenRouterProviderClient(),
            .openAI: OpenAICompatibleProviderClient(),
            .anthropic: AnthropicProviderClient(),
            .gemini: GeminiProviderClient()
        ]
    }

    public func stream(_ request: AIChatRequest) -> AsyncThrowingStream<AIResponseChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = try keychain.loadAPIKey(provider: request.provider) else {
                        throw AIProviderError.missingAPIKey(request.provider)
                    }
                    guard let client = clients[request.provider] else {
                        throw AIProviderError.unsupportedProvider(request.provider)
                    }

                    for try await chunk in client.stream(request, apiKey: apiKey) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

func openAICompatibleBody(for request: AIChatRequest) -> [String: Any] {
    [
        "model": request.model,
        "stream": request.stream,
        "messages": request.messages.map { message in
            var dictionary: [String: Any] = [
                "role": message.role.rawValue,
                "content": message.content
            ]
            if message.role == .user, !request.attachments.isEmpty {
                dictionary["content"] = [["type": "text", "text": message.content]] + request.attachments.map { attachment in
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:\(attachment.mimeType);base64,\(attachment.data.base64EncodedString())"
                        ]
                    ]
                }
            }
            return dictionary
        }
    ]
}

func streamOpenAICompatible(
    _ request: AIChatRequest,
    apiKey: String,
    _ makeRequest: @escaping (AIChatRequest, String) throws -> URLRequest
) -> AsyncThrowingStream<AIResponseChunk, Error> {
    streamSSE(request, apiKey: apiKey, makeRequest: makeRequest) { line in
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        if payload == "[DONE]" {
            return AIResponseChunk(kind: .done, text: "")
        }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let text = delta["content"] as? String else {
            return nil
        }
        return AIResponseChunk(text: text)
    }
}

func streamSSE(
    _ request: AIChatRequest,
    apiKey: String,
    makeRequest: @escaping (AIChatRequest, String) throws -> URLRequest,
    parseLine: @escaping (String) -> AIResponseChunk?
) -> AsyncThrowingStream<AIResponseChunk, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                let urlRequest = try makeRequest(request, apiKey)
                let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                try validate(response: response, data: Data())
                for try await line in bytes.lines {
                    if let chunk = parseLine(line) {
                        continuation.yield(chunk)
                    }
                }
                continuation.yield(AIResponseChunk(kind: .done, text: ""))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

func validate(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else {
        throw AIProviderError.invalidResponse
    }
    guard (200..<300).contains(http.statusCode) else {
        throw AIProviderError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
    }
}
