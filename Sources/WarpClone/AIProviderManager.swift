import Foundation

struct AIRequest {
    var prompt: String
    var model: String
    var images: [ImageAttachment]
}

protocol AIProviderClient {
    var kind: AIProviderKind { get }
    func availableModels(apiKey: String) async throws -> [AIModel]
    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error>
}

final class AIProviderManager: ObservableObject {
    @Published var selectedKind: AIProviderKind = .openRouter
    @Published var models: [AIModel] = []
    @Published var lastError: String?
    @Published var isLoadingModels = false

    private let keychain: KeychainManager
    private let clients: [AIProviderKind: AIProviderClient]

    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
        self.clients = [
            .openAICompatible: OpenAICompatibleClient(),
            .anthropic: AnthropicClient(),
            .googleGemini: GeminiClient(),
            .openRouter: OpenRouterClient(),
            .copilot: CopilotAPIClient()
        ]
    }

    func loadModels(kind: AIProviderKind) async {
        await MainActor.run {
            self.isLoadingModels = true
            self.lastError = nil
        }
        defer {
            Task { @MainActor in
                self.isLoadingModels = false
            }
        }
        do {
            if kind == .copilot {
                let loaded = try await clients[kind]?.availableModels(apiKey: "") ?? []
                self.selectedKind = kind
                self.models = loaded
                return
            }

            guard let key = try keychain.read(service: serviceName(kind), account: "apiKey") else {
                await MainActor.run { self.lastError = "Missing API key for \(kind.rawValue)." }
                return
            }
            let loaded = try await clients[kind]?.availableModels(apiKey: key) ?? []
            await MainActor.run {
                self.selectedKind = kind
                self.models = loaded
                self.lastError = nil
            }
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
        }
    }

    func complete(kind: AIProviderKind, request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        if kind == .copilot {
            guard let client = clients[kind] else {
                throw ProviderError.unsupported(kind.rawValue)
            }
            return try await client.complete(request: request, apiKey: "")
        }

        guard let key = try keychain.read(service: serviceName(kind), account: "apiKey") else {
            throw ProviderError.missingAPIKey(kind.rawValue)
        }
        guard let client = clients[kind] else {
            throw ProviderError.unsupported(kind.rawValue)
        }
        return try await client.complete(request: request, apiKey: key)
    }

    func visionSupported(modelID: String) -> Bool {
        let lowercased = modelID.lowercased()
        return lowercased.contains("vision") ||
            lowercased.contains("gpt-4o") ||
            lowercased.contains("gemini") ||
            lowercased.contains("claude-3")
    }

    private func serviceName(_ kind: AIProviderKind) -> String {
        kind.keychainServiceName
    }
}

enum ProviderError: Error, LocalizedError {
    case missingAPIKey(String)
    case unsupported(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): "Missing API key for \(provider)."
        case .unsupported(let provider): "Unsupported provider \(provider)."
        case .invalidResponse: "Provider returned an invalid response."
        }
    }
}

final class OpenRouterClient: AIProviderClient {
    let kind: AIProviderKind = .openRouter

    func availableModels(apiKey: String) async throws -> [AIModel] {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable {
            struct Model: Decodable {
                var id: String
                var name: String?
                var context_length: Int?
                var architecture: Architecture?
            }
            struct Architecture: Decodable { var modality: String? }
            var data: [Model]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.data.map {
            AIModel(
                id: $0.id,
                name: $0.name ?? $0.id,
                supportsVision: ($0.architecture?.modality ?? "").contains("image"),
                contextWindow: $0.context_length ?? 0
            )
        }
    }

    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        var urlRequest = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: OpenAICompatibleClient.body(for: request, stream: false))
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let text = try OpenAICompatibleClient.extractText(data: data)
        return AsyncThrowingStream { continuation in
            continuation.yield(AIResponseChunk(text: text, isFinal: true))
            continuation.finish()
        }
    }
}

final class OpenAICompatibleClient: AIProviderClient {
    let kind: AIProviderKind = .openAICompatible
    var baseURL = URL(string: "https://api.openai.com/v1")!

    func availableModels(apiKey: String) async throws -> [AIModel] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct Response: Decodable { struct Model: Decodable { var id: String }; var data: [Model] }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.data.map { AIModel(id: $0.id, name: $0.id, supportsVision: $0.id.contains("4o"), contextWindow: 0) }
    }

    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: Self.body(for: request, stream: false))
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let text = try Self.extractText(data: data)
        return AsyncThrowingStream { continuation in
            continuation.yield(AIResponseChunk(text: text, isFinal: true))
            continuation.finish()
        }
    }

    static func body(for request: AIRequest, stream: Bool) -> [String: Any] {
        var content: [[String: Any]] = [["type": "text", "text": request.prompt]]
        for image in request.images {
            content.append([
                "type": "image_url",
                "image_url": ["url": "data:\(image.mimeType);base64,\(image.data.base64EncodedString())"]
            ])
        }
        return [
            "model": request.model,
            "stream": stream,
            "messages": [["role": "user", "content": content]]
        ]
    }

    static func extractText(data: Data) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw ProviderError.invalidResponse }
        return content
    }
}

final class AnthropicClient: AIProviderClient {
    let kind: AIProviderKind = .anthropic

    func availableModels(apiKey: String) async throws -> [AIModel] {
        [
            AIModel(id: "claude-3-5-sonnet-latest", name: "Claude 3.5 Sonnet", supportsVision: true, contextWindow: 200_000),
            AIModel(id: "claude-3-opus-latest", name: "Claude 3 Opus", supportsVision: true, contextWindow: 200_000),
            AIModel(id: "claude-3-haiku-latest", name: "Claude 3 Haiku", supportsVision: true, contextWindow: 200_000)
        ]
    }

    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": request.model,
            "max_tokens": 2048,
            "messages": [["role": "user", "content": request.prompt]]
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let text = content.first?["text"] as? String
        else { throw ProviderError.invalidResponse }
        return AsyncThrowingStream { continuation in
            continuation.yield(AIResponseChunk(text: text, isFinal: true))
            continuation.finish()
        }
    }
}

final class GeminiClient: AIProviderClient {
    let kind: AIProviderKind = .googleGemini

    func availableModels(apiKey: String) async throws -> [AIModel] {
        [
            AIModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", supportsVision: true, contextWindow: 1_000_000),
            AIModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", supportsVision: true, contextWindow: 1_000_000)
        ]
    }

    func complete(request: AIRequest, apiKey: String) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(request.model):generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": request.prompt]]]]
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else { throw ProviderError.invalidResponse }
        return AsyncThrowingStream { continuation in
            continuation.yield(AIResponseChunk(text: text, isFinal: true))
            continuation.finish()
        }
    }
}
