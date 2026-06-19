import Foundation

@MainActor
final class MCPManager: ObservableObject {
    @Published var servers: [MCPServer] = []
    @Published var logs: [UUID: String] = [:]
    @Published var lastError: String?

    private var processes: [UUID: Process] = [:]

    func discover() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.mcp.json",
            "\(home)/.claude.json",
            "\(home)/.codex/config.toml",
            "\(home)/.warp/.mcp.json"
        ]
        var discovered: [MCPServer] = []
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            if path.hasSuffix(".json") {
                discovered.append(contentsOf: discoverJSON(path: path))
            } else {
                discovered.append(MCPServer(name: URL(fileURLWithPath: path).lastPathComponent, command: "config", status: .discovered, configPath: path))
            }
        }
        servers = discovered
    }

    func start(_ server: MCPServer) {
        guard processes[server.id] == nil else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: server.command)
        process.arguments = server.arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            processes[server.id] = process
            update(server.id, status: .running)
            logs[server.id] = "Started \(server.name)"
        } catch {
            update(server.id, status: .failed)
            logs[server.id] = error.localizedDescription
            lastError = error.localizedDescription
        }
    }

    func stop(_ server: MCPServer) {
        processes[server.id]?.terminate()
        processes[server.id] = nil
        update(server.id, status: .stopped)
        logs[server.id, default: ""] += "\nStopped \(server.name)"
    }

    func restart(_ server: MCPServer) {
        stop(server)
        start(server)
    }

    func remove(_ server: MCPServer) {
        stop(server)
        servers.removeAll { $0.id == server.id }
        logs[server.id] = nil
    }

    private func update(_ id: UUID, status: MCPStatus) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].status = status
    }

    private func discoverJSON(path: String) -> [MCPServer] {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        let serverMap = (root["mcpServers"] as? [String: Any]) ?? (root["servers"] as? [String: Any]) ?? [:]
        return serverMap.compactMap { name, value in
            guard let config = value as? [String: Any],
                  let command = config["command"] as? String else { return nil }
            let args = config["args"] as? [String] ?? []
            return MCPServer(name: name, command: command, arguments: args, status: .discovered, configPath: path)
        }
    }
}
