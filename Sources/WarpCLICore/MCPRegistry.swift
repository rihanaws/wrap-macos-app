import Foundation

public struct MCPServerDescriptor: Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var command: String
    public var args: [String]
    public var environment: [String: String]
    public var source: URL

    public init(name: String, command: String, args: [String] = [], environment: [String: String] = [:], source: URL) {
        self.name = name
        self.command = command
        self.args = args
        self.environment = environment
        self.source = source
    }
}

public enum MCPRegistryParser {
    public static func parseClaudeJSON(data: Data, source: URL) throws -> [MCPServerDescriptor] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any] else {
            return []
        }

        return servers.compactMap { name, value in
            guard let dictionary = value as? [String: Any],
                  let command = dictionary["command"] as? String else {
                return nil
            }
            let args = dictionary["args"] as? [String] ?? []
            let environment = dictionary["env"] as? [String: String] ?? [:]
            return MCPServerDescriptor(name: name, command: command, args: args, environment: environment, source: source)
        }
        .sorted { $0.name < $1.name }
    }

    public static func parseCodexTOML(text: String, source: URL) -> [MCPServerDescriptor] {
        var descriptors: [MCPServerDescriptor] = []
        var currentName: String?
        var currentCommand: String?
        var currentArgs: [String] = []

        func flush() {
            guard let name = currentName, let command = currentCommand else { return }
            descriptors.append(MCPServerDescriptor(name: name, command: command, args: currentArgs, source: source))
        }

        for rawLine in text.split(separator: "\n").map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[mcp_servers."), line.hasSuffix("]") {
                flush()
                currentCommand = nil
                currentArgs = []
                currentName = line
                    .replacingOccurrences(of: "[mcp_servers.", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if line.hasPrefix("command") {
                currentCommand = value(afterEqualsIn: line)
            } else if line.hasPrefix("args") {
                currentArgs = arrayValue(afterEqualsIn: line)
            }
        }
        flush()
        return descriptors.sorted { $0.name < $1.name }
    }

    private static func value(afterEqualsIn line: String) -> String? {
        line.components(separatedBy: "=").dropFirst().joined(separator: "=")
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private static func arrayValue(afterEqualsIn line: String) -> [String] {
        let raw = line.components(separatedBy: "=").dropFirst().joined(separator: "=")
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return raw.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }.filter { !$0.isEmpty }
    }
}

public final class MCPRegistry {
    public var configPaths: [URL]

    public init(configPaths: [URL] = MCPRegistry.defaultConfigPaths()) {
        self.configPaths = configPaths
    }

    public func discover() throws -> [MCPServerDescriptor] {
        var servers: [MCPServerDescriptor] = []
        for url in configPaths where FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            if url.pathExtension == "json" {
                servers.append(contentsOf: try MCPRegistryParser.parseClaudeJSON(data: data, source: url))
            } else if let text = String(data: data, encoding: .utf8) {
                servers.append(contentsOf: MCPRegistryParser.parseCodexTOML(text: text, source: url))
            }
        }
        return servers
    }

    public static func defaultConfigPaths() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".codex/config.toml"),
            home.appendingPathComponent(".warp/.mcp.json"),
            home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        ]
    }
}
