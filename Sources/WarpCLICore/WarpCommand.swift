import ArgumentParser
import Foundation

public struct WarpCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "warp",
        abstract: "Terminal-native AI companion for WarpClone.",
        version: "0.1.0",
        subcommands: [
            ChatCommand.self,
            AskCommand.self,
            AgentCommand.self,
            ReviewCommand.self,
            MCPCommand.self,
            ConfigCommand.self
        ],
        defaultSubcommand: ChatCommand.self
    )

    public init() {}
}

public struct AskCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "ask", abstract: "Send one prompt to the configured AI provider.")

    @Argument(help: "Prompt text.")
    public var prompt: [String] = []

    @Option(name: .shortAndLong, help: "Provider: openrouter, openai, anthropic, gemini.")
    public var provider: CLIProvider?

    @Option(name: .shortAndLong, help: "Model ID.")
    public var model: String?

    @Flag(name: .long, help: "Disable streaming output.")
    public var noStream = false

    @Flag(name: .long, help: "Allow agent tool loop affordances for this request.")
    public var agent = false

    public init() {}

    public func run() throws {
        try runAsyncAndBlock {
            let config = try CLIConfigStore().load()
            let resolvedProvider = provider ?? config.defaultProvider
            let resolvedModel = model ?? config.defaultModel
            let promptText = prompt.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !promptText.isEmpty else {
                throw ValidationError("Prompt cannot be empty.")
            }

            let request = AIChatRequest(
                provider: resolvedProvider,
                model: resolvedModel,
                messages: [.user(promptText)],
                stream: !noStream
            )

            for try await chunk in AIProviderRegistry().stream(request) {
                if chunk.kind == .token {
                    print(chunk.text, terminator: "")
                    fflush(stdout)
                }
            }
            print("")
        }
    }
}

public struct ChatCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "chat", abstract: "Start an interactive terminal chat session.")

    @Option(name: .shortAndLong, help: "Resume a saved session ID.")
    public var resume: String?

    @Flag(name: .shortAndLong, help: "Run in agent mode with tool-dispatch affordances.")
    public var agent = false

    public init() {}

    public func run() throws {
        try TerminalUI().run(resumeSessionId: resume, agentMode: agent)
    }
}

public struct AgentCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "agent", abstract: "Start an autonomous agent loop with explicit permission controls.")

    @Argument(help: "Task for the agent loop.")
    public var task: [String] = []

    @Option(name: .shortAndLong, help: "Permission level: ask, allow-read, allow-all, deny.")
    public var permission: PermissionMode = .ask

    public init() {}

    public func run() throws {
        let gate = PermissionGate(mode: permission)
        let readDecision = gate.evaluate(.mcpList)
        let taskText = task.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if taskText.isEmpty {
            print("Agent mode ready. Permission: \(permission.rawValue). MCP list: \(readDecision.reason).")
        } else {
            print("Agent task: \(taskText)")
            print("Permission: \(permission.rawValue). MCP list: \(readDecision.reason).")
        }
        try TerminalUI().run(resumeSessionId: nil, agentMode: true)
    }
}

public struct ReviewCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "review", abstract: "Review git changes with the configured AI provider.")

    @Option(name: .long, help: "Repository path.")
    public var path: String = FileManager.default.currentDirectoryPath

    @Flag(name: .shortAndLong, help: "Review staged changes.")
    public var staged = false

    @Flag(name: .long, help: "Review unstaged changes.")
    public var unstaged = false

    @Option(name: .long, help: "Compare changes against a branch or ref.")
    public var branch: String?

    @Option(name: .shortAndLong, help: "Provider override.")
    public var provider: CLIProvider?

    @Option(name: .shortAndLong, help: "Model override.")
    public var model: String?

    public init() {}

    public func run() throws {
        try runAsyncAndBlock {
            let config = try CLIConfigStore().load()
            let service = GitReviewService(repositoryPath: path)
            let prompt = try service.reviewPrompt(staged: staged && !unstaged, branch: branch)
            let request = AIChatRequest(
                provider: provider ?? config.defaultProvider,
                model: model ?? config.defaultModel,
                messages: [.user(prompt)],
                stream: true
            )

            for try await chunk in AIProviderRegistry().stream(request) {
                if chunk.kind == .token {
                    print(chunk.text, terminator: "")
                    fflush(stdout)
                }
            }
            print("")
        }
    }
}

public struct MCPCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Inspect and manage local MCP server configuration.",
        subcommands: [
            MCPListCommand.self,
            MCPDiscoverCommand.self,
            MCPStartCommand.self,
            MCPStopCommand.self
        ],
        defaultSubcommand: MCPListCommand.self
    )

    public init() {}
}

public struct MCPListCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "list", abstract: "List discovered MCP servers.")
    public init() {}

    public func run() throws {
        let servers = try MCPRegistry().discover()
        if servers.isEmpty {
            print("No MCP servers discovered.")
        } else {
            for server in servers {
                print("\(server.name)\t\(server.command) \(server.args.joined(separator: " "))\t\(server.source.path)")
            }
        }
    }
}

public struct MCPDiscoverCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "discover", abstract: "Discover MCP server definitions from local config files.")
    public init() {}

    public func run() throws {
        try MCPListCommand().run()
    }
}

public struct MCPStartCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "start", abstract: "Print the command needed to start an MCP server.")

    @Argument(help: "Server name.")
    public var name: String

    public init() {
        self.name = ""
    }

    public init(name: String) {
        self.name = name
    }

    public func run() throws {
        guard let server = try MCPRegistry().discover().first(where: { $0.name == name }) else {
            throw ValidationError("No MCP server named '\(name)' was discovered.")
        }
        print("\(server.command) \(server.args.joined(separator: " "))")
    }
}

public struct MCPStopCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "stop", abstract: "Stop is delegated to the owning MCP runtime.")

    @Argument(help: "Server name.")
    public var name: String

    public init() {
        self.name = ""
    }

    public init(name: String) {
        self.name = name
    }

    public func run() throws {
        print("Stop requested for \(name). WarpClone CLI does not terminate external MCP runtimes it did not start.")
    }
}

private func runAsyncAndBlock(_ operation: @escaping () async throws -> Void) throws {
    let semaphore = DispatchSemaphore(value: 0)
    final class Box {
        var result: Result<Void, Error>?
    }
    let box = Box()

    Task {
        do {
            try await operation()
            box.result = .success(())
        } catch {
            box.result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    try box.result?.get()
}

public struct ConfigCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "config", abstract: "Manage WarpClone CLI configuration and provider credentials.")

    @Option(name: .shortAndLong, help: "Default provider.")
    public var provider: CLIProvider?

    @Option(name: .shortAndLong, help: "Default model.")
    public var model: String?

    @Option(name: .long, help: "Save provider API key to Keychain.")
    public var apiKey: String?

    @Flag(name: .long, help: "Remove provider API key from Keychain.")
    public var removeAPIKey = false

    @Option(name: .long, help: "Permission mode.")
    public var permission: PermissionMode?

    @Flag(name: .long, help: "Show current configuration.")
    public var show = false

    public init() {}

    public func run() throws {
        let store = CLIConfigStore()
        var config = try store.load()
        let keychain = CLIKeychainStore()
        let selectedProvider = provider ?? config.defaultProvider
        var changedConfig = false

        if let provider {
            config.defaultProvider = provider
            changedConfig = true
        }
        if let model {
            config.defaultModel = model
            changedConfig = true
        }
        if let permission {
            config.permissionMode = permission
            changedConfig = true
        }
        if let apiKey {
            try keychain.saveAPIKey(apiKey, provider: selectedProvider)
            print("Saved API key for \(selectedProvider.displayName) to Keychain.")
        }
        if removeAPIKey {
            try keychain.deleteAPIKey(provider: selectedProvider)
            print("Removed API key for \(selectedProvider.displayName) from Keychain.")
        }

        if changedConfig {
            try store.save(config)
        }
        if show || (provider == nil && model == nil && apiKey == nil && !removeAPIKey && permission == nil) {
            let hasKey = (try keychain.loadAPIKey(provider: config.defaultProvider)) != nil
            print("""
            Provider: \(config.defaultProvider.rawValue)
            Model: \(config.defaultModel)
            Permission: \(config.permissionMode.rawValue)
            API key saved: \(hasKey ? "yes" : "no")
            """)
        }
    }
}
