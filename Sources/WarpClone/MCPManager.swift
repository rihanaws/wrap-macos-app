import Foundation
import CryptoKit
import WarpCLICore

@MainActor
final class MCPManager: ObservableObject {
    @Published var servers: [MCPServer] = []
    @Published var logs: [UUID: String] = [:]

    private var processes: [UUID: Process] = [:]
    private let securityPolicy = MCPSecurityPolicy()
    private let rateLimiter = MCPRateLimiter()
    private let auditLogger = AuditLogger()
    private let approvedHashesKey = "warpclone_mcp_approved_descriptor_hashes"
    private var approvedDescriptorHashes: Set<String>

    init(userDefaults: UserDefaults = .standard) {
        approvedDescriptorHashes = Set(userDefaults.stringArray(forKey: approvedHashesKey) ?? [])
        self.userDefaults = userDefaults
    }

    private let userDefaults: UserDefaults

    func discover() {
        let paths = defaultConfigPaths()
        var discovered: [MCPServer] = []

        for path in paths where FileManager.default.fileExists(atPath: path) {
            let parsedServers = discoverJSON(path: path)
            if parsedServers.isEmpty {
                discovered.append(MCPServer(
                    name: URL(fileURLWithPath: path).lastPathComponent,
                    command: "config",
                    status: .discovered,
                    configPath: path
                ))
            } else {
                discovered.append(contentsOf: parsedServers)
            }

            auditLogger.append(AuditLogEntry(
                action: .mcpServerDiscovered,
                source: .app,
                risk: .unknown,
                subject: path,
                detail: "Discovered MCP configuration"
            ))
        }

        servers = discovered
    }

    func start(_ server: MCPServer) {
        guard processes[server.id] == nil else { return }
        guard hasApprovedDescriptor(for: server) else {
            update(server.id, status: .discovered)
            logs[server.id] = "MCP server must be approved before it can start."
            auditLogger.append(AuditLogEntry(
                action: .mcpServerRejected,
                source: .app,
                risk: .unknown,
                subject: server.name,
                detail: "Start denied for unapproved descriptor \(server.descriptorHash)"
            ))
            return
        }
        guard server.command != "config" else {
            update(server.id, status: .failed)
            logs[server.id] = "This entry is a config marker, not a runnable MCP server."
            return
        }
        guard rateLimiter.allowsCall(serverID: server.id) else {
            update(server.id, status: .failed)
            logs[server.id] = "MCP rate limit exceeded. Try again in a minute."
            return
        }

        do {
            let sandboxHome = try securityPolicy.prepareSandboxHome(for: server.id)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: server.command)
            process.arguments = server.arguments
            process.currentDirectoryURL = sandboxHome

            var environment = securityPolicy.filteredEnvironment()
            environment["HOME"] = sandboxHome.path
            environment["WARPCLONE_MCP_SANDBOX"] = sandboxHome.path
            process.environment = environment

            let output = Pipe()
            process.standardOutput = output
            process.standardError = output

            try process.run()
            processes[server.id] = process
            update(server.id, status: .running)
            logs[server.id] = "Started \(server.name) in sandbox \(sandboxHome.path)"

            auditLogger.append(AuditLogEntry(
                action: .mcpServerStarted,
                source: .app,
                risk: .unknown,
                subject: server.name,
                detail: "Started \(server.command) with restricted environment"
            ))
        } catch {
            update(server.id, status: .failed)
            logs[server.id] = error.localizedDescription
            auditLogger.append(AuditLogEntry(
                action: .mcpServerRejected,
                source: .app,
                risk: .unknown,
                subject: server.name,
                detail: error.localizedDescription
            ))
        }
    }

    func approve(_ server: MCPServer) {
        guard !server.descriptorHash.isEmpty else {
            deny(server, reason: "Missing MCP descriptor hash.")
            return
        }

        approvedDescriptorHashes.insert(server.descriptorHash)
        persistApprovedDescriptorHashes()
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].isApproved = true
        }
        logs[server.id] = "Approved \(server.name)."
        auditLogger.append(AuditLogEntry(
            action: .mcpServerApproved,
            source: .app,
            risk: .unknown,
            subject: server.name,
            detail: "Approved descriptor \(server.descriptorHash)"
        ))
    }

    func deny(_ server: MCPServer, reason: String = "User denied MCP server approval.") {
        logs[server.id] = reason
        auditLogger.append(AuditLogEntry(
            action: .mcpServerRejected,
            source: .app,
            risk: .unknown,
            subject: server.name,
            detail: reason
        ))
    }

    func stop(_ server: MCPServer) {
        processes[server.id]?.terminate()
        processes[server.id] = nil
        update(server.id, status: .stopped)

        auditLogger.append(AuditLogEntry(
            action: .mcpServerStopped,
            source: .app,
            risk: .unknown,
            subject: server.name,
            detail: "Stopped MCP server"
        ))
    }

    func restart(_ server: MCPServer) {
        stop(server)
        start(server)
    }

    func remove(_ server: MCPServer) {
        stop(server)
        servers.removeAll { $0.id == server.id }
        logs[server.id] = nil

        auditLogger.append(AuditLogEntry(
            action: .mcpServerRemoved,
            source: .app,
            risk: .unknown,
            subject: server.name,
            detail: "Removed MCP server from app state"
        ))
    }

    private func update(_ id: UUID, status: MCPStatus) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].status = status
    }

    private func hasApprovedDescriptor(for server: MCPServer) -> Bool {
        !server.descriptorHash.isEmpty && approvedDescriptorHashes.contains(server.descriptorHash)
    }

    private func persistApprovedDescriptorHashes() {
        userDefaults.set(Array(approvedDescriptorHashes).sorted(), forKey: approvedHashesKey)
    }

    private func descriptorHash(name: String, command: String, arguments: [String], configPath: String) -> String {
        let descriptor = [
            name,
            command,
            arguments.joined(separator: "\u{1F}"),
            configPath
        ].joined(separator: "\u{1E}")
        let digest = SHA256.hash(data: Data(descriptor.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func defaultConfigPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.claude.json",
            "\(home)/.mcp.json",
            "\(home)/.codex/config.toml",
            "\(home)/.warp/.mcp.json",
            "\(home)/Library/Application Support/Claude/claude_desktop_config.json"
        ]
    }

    private func discoverJSON(path: String) -> [MCPServer] {
        guard
            path.hasSuffix(".json"),
            let data = FileManager.default.contents(atPath: path),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let serverMap = root["mcpServers"] as? [String: Any]
        else {
            return []
        }

        return serverMap.compactMap { name, value in
            guard
                let config = value as? [String: Any],
                let command = config["command"] as? String
            else {
                return nil
            }

            let args = config["args"] as? [String] ?? []
            let hash = securityPolicy.descriptorHash(name: name, command: command, arguments: args)
            let configPath = "\(path)#\(hash)"
            let descriptorHash = descriptorHash(
                name: name,
                command: command,
                arguments: args,
                configPath: configPath
            )
            return MCPServer(
                name: name,
                command: command,
                arguments: args,
                status: .discovered,
                configPath: configPath,
                descriptorHash: descriptorHash,
                isApproved: approvedDescriptorHashes.contains(descriptorHash)
            )
        }
    }
}
