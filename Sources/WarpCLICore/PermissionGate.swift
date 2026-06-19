import Foundation

public enum ToolAction: Equatable {
    case readFile(path: String)
    case writeFile(path: String, content: String)
    case editFile(path: String, replacement: String)
    case gitDiff(path: String)
    case mcpList
    case shell(command: String)

    public var isReadOnly: Bool {
        switch self {
        case .readFile, .gitDiff, .mcpList: true
        case .writeFile, .editFile, .shell: false
        }
    }

    public var isFileMutation: Bool {
        switch self {
        case .writeFile, .editFile:
            true
        case .readFile, .gitDiff, .mcpList, .shell:
            false
        }
    }
}

public struct PermissionDecision: Equatable {
    public var isAllowed: Bool
    public var reason: String

    public init(isAllowed: Bool, reason: String) {
        self.isAllowed = isAllowed
        self.reason = reason
    }
}

public final class PermissionGate {
    public var mode: PermissionMode

    public init(mode: PermissionMode) {
        self.mode = mode
    }

    public func evaluate(_ action: ToolAction) -> PermissionDecision {
        switch mode {
        case .allowAll:
            PermissionDecision(isAllowed: true, reason: "allow-all")
        case .allowWrite:
            PermissionDecision(
                isAllowed: action.isReadOnly || action.isFileMutation,
                reason: action.isReadOnly || action.isFileMutation ? "read/write action" : "shell execution blocked in allow-write mode"
            )
        case .allowRead:
            PermissionDecision(isAllowed: action.isReadOnly, reason: action.isReadOnly ? "read-only action" : "mutation blocked in allow-read mode")
        case .deny:
            PermissionDecision(isAllowed: false, reason: "all tools denied")
        case .ask:
            PermissionDecision(isAllowed: action.isReadOnly, reason: action.isReadOnly ? "read-only action" : "interactive approval required")
        }
    }
}

public final class ToolDispatcher {
    private let permissionGate: PermissionGate
    private let git: GitReviewService
    private let mcp: MCPRegistry

    public init(permissionGate: PermissionGate, git: GitReviewService = GitReviewService(), mcp: MCPRegistry = MCPRegistry()) {
        self.permissionGate = permissionGate
        self.git = git
        self.mcp = mcp
    }

    public func dispatch(_ action: ToolAction) throws -> String {
        let decision = permissionGate.evaluate(action)
        guard decision.isAllowed else {
            throw ToolDispatchError.denied(decision.reason)
        }

        switch action {
        case .readFile(let path):
            return try String(contentsOfFile: path, encoding: .utf8)
        case .writeFile(let path, let content):
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return "Wrote \(path)"
        case .editFile(let path, let replacement):
            guard FileManager.default.fileExists(atPath: path) else {
                throw ToolDispatchError.denied("Cannot edit missing file \(path)")
            }
            try replacement.write(toFile: path, atomically: true, encoding: .utf8)
            return "Edited \(path)"
        case .gitDiff(let path):
            return try GitReviewService(repositoryPath: path).diff()
        case .mcpList:
            return try mcp.discover().map { "\($0.name): \($0.command) \($0.args.joined(separator: " "))" }.joined(separator: "\n")
        case .shell(let command):
            return try runShell(command)
        }
    }

    private func runShell(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

public enum ToolDispatchError: Error, LocalizedError {
    case denied(String)

    public var errorDescription: String? {
        switch self {
        case .denied(let reason):
            "Tool action denied: \(reason)"
        }
    }
}
