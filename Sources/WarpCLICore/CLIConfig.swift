import Foundation
import ArgumentParser

public enum CLIProvider: String, Codable, CaseIterable, ExpressibleByArgument {
    case openRouter = "openrouter"
    case openAI = "openai"
    case anthropic
    case gemini

    public init?(argument: String) {
        let normalized = argument.lowercased()
        self = Self.allCases.first { $0.rawValue == normalized || $0.displayName.lowercased() == normalized } ?? .openRouter
        if !Self.allCases.map(\.rawValue).contains(normalized), !Self.allCases.map({ $0.displayName.lowercased() }).contains(normalized) {
            return nil
        }
    }

    public var displayName: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .openAI: "OpenAI-compatible"
        case .anthropic: "Anthropic-compatible"
        case .gemini: "Google Gemini-compatible"
        }
    }

    public var keychainServiceName: String {
        "com.warpclone.cli.\(rawValue)"
    }
}

public enum PermissionMode: String, Codable, CaseIterable, ExpressibleByArgument {
    case ask
    case allowRead = "allow-read"
    case allowWrite = "allow-write"
    case allowAll = "allow-all"
    case deny

    public init?(argument: String) {
        if argument == "read" {
            self = .allowRead
            return
        }
        if argument == "write" {
            self = .allowWrite
            return
        }
        self.init(rawValue: argument)
    }
}

public struct CLIConfig: Codable, Equatable {
    public var defaultProvider: CLIProvider
    public var defaultModel: String
    public var permissionMode: PermissionMode
    public var telemetryEnabled: Bool

    public init(
        defaultProvider: CLIProvider = .openRouter,
        defaultModel: String = "openai/gpt-4o",
        permissionMode: PermissionMode = .ask,
        telemetryEnabled: Bool = true
    ) {
        self.defaultProvider = defaultProvider
        self.defaultModel = defaultModel
        self.permissionMode = permissionMode
        self.telemetryEnabled = telemetryEnabled
    }
}

public final class CLIConfigStore {
    public let configDirectory: URL
    public var configFileURL: URL { configDirectory.appendingPathComponent("config.json") }

    public init(configDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".warp")) {
        self.configDirectory = configDirectory
    }

    public func load() throws -> CLIConfig {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return CLIConfig()
        }

        let data = try Data(contentsOf: configFileURL)
        return try JSONDecoder.warpCLI.decode(CLIConfig.self, from: data)
    }

    public func save(_ config: CLIConfig) throws {
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.warpCLI.encode(config)
        try data.write(to: configFileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}

extension JSONEncoder {
    static var warpCLI: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var warpCLI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
