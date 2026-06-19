import Foundation
import Darwin

public enum ToolRisk: String, Codable, CaseIterable, Identifiable, Sendable {
    case readOnly
    case write
    case destructive
    case network
    case credential
    case unknown

    public var id: String { rawValue }

    public var requiresApproval: Bool {
        switch self {
        case .readOnly:
            return false
        case .write, .destructive, .network, .credential, .unknown:
            return true
        }
    }
}

public enum ToolCallSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case user
    case agent
    case mcp
    case cli
    case app

    public var id: String { rawValue }
}

public enum ToolAction: Codable, Equatable, Sendable {
    case readFile(path: String)
    case gitDiff(path: String)
    case gitStatus(path: String)
    case mcpList
    case mcpCall(server: String, tool: String)
    case shell(command: String)
    case editFile(path: String, replacement: String)
    case writeFile(path: String, content: String)
    case deleteFile(path: String)
    case gitPush(remote: String, branch: String)
    case networkRequest(url: String, method: String)
    case openURL(url: String)

    public var displayName: String {
        switch self {
        case .readFile(let path): return "Read \(path)"
        case .gitDiff(let path): return "Git diff \(path)"
        case .gitStatus(let path): return "Git status \(path)"
        case .mcpList: return "List MCP servers"
        case .mcpCall(let server, let tool): return "MCP \(server): \(tool)"
        case .shell(let command): return command
        case .editFile(let path, _), .writeFile(let path, _): return "Write \(path)"
        case .deleteFile(let path): return "Delete \(path)"
        case .gitPush(let remote, let branch): return "Push \(remote)/\(branch)"
        case .networkRequest(let url, let method): return "\(method.uppercased()) \(url)"
        case .openURL(let url): return "Open \(url)"
        }
    }

    public var command: String? {
        switch self {
        case .shell(let command):
            return command
        case .gitDiff(let path):
            return "git diff -- \(path)"
        case .gitStatus(let path):
            return "git -C \(path) status --short --branch"
        case .gitPush(let remote, let branch):
            return "git push \(remote) \(branch)"
        default:
            return nil
        }
    }

    public var risk: ToolRisk {
        switch self {
        case .readFile, .gitDiff, .gitStatus, .mcpList:
            return .readOnly
        case .editFile, .writeFile:
            return .write
        case .deleteFile, .gitPush:
            return .destructive
        case .networkRequest, .openURL:
            return .network
        case .mcpCall:
            return .unknown
        case .shell(let command):
            return CommandSandbox().validate(command).risk
        }
    }

    public var isReadOnly: Bool { risk == .readOnly }
    public var isFileMutation: Bool {
        switch self {
        case .editFile, .writeFile, .deleteFile:
            return true
        default:
            return false
        }
    }
}

public struct PermissionDecision: Codable, Equatable, Sendable {
    public let isAllowed: Bool
    public let reason: String
    public let requiresUserApproval: Bool
    public let risk: ToolRisk

    public init(
        isAllowed: Bool,
        reason: String,
        requiresUserApproval: Bool = false,
        risk: ToolRisk = .unknown
    ) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.requiresUserApproval = requiresUserApproval
        self.risk = risk
    }
}

public struct PermissionEvaluation: Codable, Equatable, Sendable {
    public let action: ToolAction
    public let source: ToolCallSource
    public let decision: PermissionDecision
    public let evaluatedAt: Date

    public init(action: ToolAction, source: ToolCallSource, decision: PermissionDecision, evaluatedAt: Date = Date()) {
        self.action = action
        self.source = source
        self.decision = decision
        self.evaluatedAt = evaluatedAt
    }

    public var isAllowed: Bool { decision.isAllowed }
    public var reason: String { decision.reason }
    public var requiresUserApproval: Bool { decision.requiresUserApproval }
    public var risk: ToolRisk { decision.risk }
}

public struct CommandValidationResult: Codable, Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool
    public let risk: ToolRisk
    public let reason: String

    public init(isAllowed: Bool, requiresApproval: Bool, risk: ToolRisk, reason: String) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
        self.risk = risk
        self.reason = reason
    }
}

public struct CommandSandbox: Sendable {
    private let permanentBlocklist: [NSRegularExpression]
    private let destructiveApprovalPatterns: [NSRegularExpression]
    private let writeApprovalPatterns: [NSRegularExpression]
    private let networkApprovalPatterns: [NSRegularExpression]
    private let readOnlyPrefixes: Set<String>

    public init() {
        permanentBlocklist = [
            #"curl\s+.*\|\s*(sh|bash|zsh)"#,
            #"wget\s+.*\|\s*(sh|bash|zsh)"#,
            #":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;"#,
            #">\s*/dev/(disk|rdisk)"#,
            #"dd\s+.*\bof=/dev/"#
        ].map(Self.regex)

        destructiveApprovalPatterns = [
            #"\brm\s+(-[^\s]*[rf][^\s]*|-r|-f|--recursive|--force)"#,
            #"\bsudo\b"#,
            #"\bchmod\s+777\b"#,
            #"\bchown\b"#,
            #"\bgit\s+push\b"#,
            #"\bgit\s+reset\s+--hard\b"#,
            #"\bgit\s+clean\s+-[^\s]*f"#,
            #"\bmv\s+.*\s+/"#,
            #"\btruncate\b"#,
            #"\bmkfs\b"#,
            #"\bdiskutil\s+(erase|partition|unmount|apfs)"#
        ].map(Self.regex)

        writeApprovalPatterns = [
            #"\s>>?\s*[^&\s]"#,
            #"\btee\s+(-a\s+)?[^\s|]+"#,
            #"\btouch\b"#
        ].map(Self.regex)

        networkApprovalPatterns = [
            #"\bcurl\b"#,
            #"\bwget\b"#,
            #"\bssh\b"#,
            #"\bscp\b"#,
            #"\brsync\b"#,
            #"\bnc\b"#,
            #"\bnpm\s+(publish|login)"#
        ].map(Self.regex)

        readOnlyPrefixes = [
            "cat", "cd", "cut", "diff", "du", "echo", "env", "find", "git", "grep",
            "head", "jq", "less", "ls", "md5", "pwd", "rg", "sed", "shasum", "sort",
            "stat", "tail", "tree", "tr", "uniq", "wc", "which", "xcrun"
        ]
    }

    public func validate(_ command: String) -> CommandValidationResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CommandValidationResult(isAllowed: false, requiresApproval: false, risk: .unknown, reason: "Empty command")
        }

        if let pattern = firstMatch(in: trimmed, patterns: permanentBlocklist) {
            return CommandValidationResult(
                isAllowed: false,
                requiresApproval: false,
                risk: .destructive,
                reason: "Command is permanently blocked by sandbox policy: \(pattern)"
            )
        }

        if let pattern = firstMatch(in: trimmed, patterns: destructiveApprovalPatterns) {
            return CommandValidationResult(
                isAllowed: true,
                requiresApproval: true,
                risk: .destructive,
                reason: "Destructive command requires approval: \(pattern)"
            )
        }

        if let pattern = firstMatch(in: trimmed, patterns: writeApprovalPatterns) {
            return CommandValidationResult(
                isAllowed: true,
                requiresApproval: true,
                risk: .write,
                reason: "Write command requires approval: \(pattern)"
            )
        }

        if let pattern = firstMatch(in: trimmed, patterns: networkApprovalPatterns) {
            return CommandValidationResult(
                isAllowed: true,
                requiresApproval: true,
                risk: .network,
                reason: "Network command requires approval: \(pattern)"
            )
        }

        if isReadOnlyCommand(trimmed) {
            return CommandValidationResult(isAllowed: true, requiresApproval: false, risk: .readOnly, reason: "Read-only command")
        }

        return CommandValidationResult(
            isAllowed: true,
            requiresApproval: true,
            risk: .unknown,
            reason: "Unrecognized command requires approval"
        )
    }

    private func isReadOnlyCommand(_ command: String) -> Bool {
        let segments = command
            .components(separatedBy: CharacterSet(charactersIn: ";&|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !segments.isEmpty else { return false }

        return segments.allSatisfy { segment in
            let executable = segment.split(separator: " ").first.map(String.init) ?? ""
            let basename = URL(fileURLWithPath: executable).lastPathComponent
            if basename == "git" {
                return isReadOnlyGitCommand(segment)
            }
            return readOnlyPrefixes.contains(basename)
        }
    }

    private func isReadOnlyGitCommand(_ segment: String) -> Bool {
        let parts = segment.split(separator: " ").map(String.init)
        guard parts.first == "git" else { return false }
        let subcommand = parts.dropFirst().first { !$0.hasPrefix("-") } ?? ""
        return ["branch", "diff", "log", "ls-files", "show", "status"].contains(subcommand)
    }

    private func firstMatch(in command: String, patterns: [NSRegularExpression]) -> String? {
        let range = NSRange(command.startIndex..<command.endIndex, in: command)
        return patterns.first { $0.firstMatch(in: command, range: range) != nil }?.pattern
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}

public struct PermissionGate: Sendable {
    public let mode: PermissionMode
    public let commandSandbox: CommandSandbox

    public init(mode: PermissionMode, commandSandbox: CommandSandbox = CommandSandbox()) {
        self.mode = mode
        self.commandSandbox = commandSandbox
    }

    public func evaluate(_ action: ToolAction, source: ToolCallSource = .agent) -> PermissionEvaluation {
        PermissionEvaluation(action: action, source: source, decision: decision(for: action))
    }

    public func decision(for action: ToolAction) -> PermissionDecision {
        if case .shell(let command) = action {
            let validation = commandSandbox.validate(command)
            guard validation.isAllowed else {
                return PermissionDecision(
                    isAllowed: false,
                    reason: validation.reason,
                    requiresUserApproval: false,
                    risk: validation.risk
                )
            }
            if validation.requiresApproval {
                return approvalDecision(for: action, risk: validation.risk, reason: validation.reason)
            }
        }

        switch mode {
        case .ask:
            if action.isReadOnly {
                return PermissionDecision(isAllowed: true, reason: "read-only action allowed", risk: .readOnly)
            }
            return PermissionDecision(
                isAllowed: false,
                reason: "approval required",
                requiresUserApproval: true,
                risk: action.risk
            )
        case .allowRead:
            return PermissionDecision(
                isAllowed: action.isReadOnly,
                reason: action.isReadOnly ? "read-only action allowed" : "write, network, and destructive actions require approval",
                requiresUserApproval: !action.isReadOnly,
                risk: action.risk
            )
        case .allowWrite:
            let allowed = action.risk == .readOnly || action.risk == .write
            return PermissionDecision(
                isAllowed: allowed,
                reason: allowed ? "read/write action allowed" : "destructive, network, or unknown action requires approval",
                requiresUserApproval: !allowed,
                risk: action.risk
            )
        case .allowAll:
            return PermissionDecision(isAllowed: true, reason: "all tools allowed by configuration", risk: action.risk)
        case .deny:
            return PermissionDecision(isAllowed: false, reason: "all tools denied", risk: action.risk)
        }
    }

    private func approvalDecision(for action: ToolAction, risk: ToolRisk, reason: String) -> PermissionDecision {
        switch mode {
        case .allowAll:
            return PermissionDecision(isAllowed: true, reason: reason, requiresUserApproval: false, risk: risk)
        case .deny:
            return PermissionDecision(isAllowed: false, reason: "all tools denied", requiresUserApproval: false, risk: risk)
        case .ask, .allowRead, .allowWrite:
            return PermissionDecision(isAllowed: false, reason: reason, requiresUserApproval: true, risk: risk)
        }
    }
}

public enum AuditAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case permissionAllowed
    case permissionDenied
    case commandNeedsApproval
    case commandBlocked
    case mcpServerDiscovered
    case mcpServerApproved
    case mcpServerStarted
    case mcpServerStopped
    case mcpServerRemoved
    case mcpServerRejected
    case mcpToolInvoked
    case sanitizerStrippedControlSequence

    public var id: String { rawValue }
}

public struct AuditLogEntry: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let action: AuditAction
    public let source: ToolCallSource?
    public let risk: ToolRisk?
    public let subject: String
    public let detail: String

    public init(
        timestamp: Date = Date(),
        action: AuditAction,
        source: ToolCallSource? = nil,
        risk: ToolRisk? = nil,
        subject: String,
        detail: String
    ) {
        self.timestamp = timestamp
        self.action = action
        self.source = source
        self.risk = risk
        self.subject = subject
        self.detail = detail
    }
}

public final class AuditLogger: @unchecked Sendable {
    public let logURL: URL
    private let encoder: JSONEncoder
    private let queue = DispatchQueue(label: "dev.warpclone.audit-log")

    public init(logURL: URL = AuditLogger.defaultLogURL()) {
        self.logURL = logURL
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        ensureLogFile()
    }

    public static func defaultLogURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".warp", isDirectory: true)
            .appendingPathComponent("audit.log")
    }

    public func append(_ entry: AuditLogEntry) {
        queue.sync {
            ensureLogFile()
            guard let data = try? encoder.encode(entry) else { return }
            var line = data
            line.append(0x0A)

            if let handle = try? FileHandle(forWritingTo: logURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            }
        }
    }

    private func ensureLogFile() {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: logURL.path) {
            let fd = open(logURL.path, O_CREAT | O_WRONLY | O_APPEND, S_IRUSR | S_IWUSR)
            if fd >= 0 {
                close(fd)
            }
        } else {
            chmod(logURL.path, S_IRUSR | S_IWUSR)
        }
    }
}

public struct MCPSecurityPolicy: Sendable {
    public static let restrictedEnvironmentKeys: Set<String> = [
        "SUPABASE_SERVICE_ROLE_KEY",
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "GOOGLE_API_KEY",
        "GEMINI_API_KEY",
        "GITHUB_TOKEN",
        "DATABASE_URL",
        "OPENROUTER_API_KEY"
    ]

    public let sandboxRoot: URL
    public let maxToolRuntime: TimeInterval
    public let maxCallsPerMinute: Int

    public init(
        sandboxRoot: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".warp/mcp-sandbox", isDirectory: true),
        maxToolRuntime: TimeInterval = 5.0,
        maxCallsPerMinute: Int = 60
    ) {
        self.sandboxRoot = sandboxRoot
        self.maxToolRuntime = maxToolRuntime
        self.maxCallsPerMinute = maxCallsPerMinute
    }

    public func sandboxHome(for serverID: UUID) -> URL {
        sandboxRoot.appendingPathComponent(serverID.uuidString, isDirectory: true)
    }

    public func prepareSandboxHome(for serverID: UUID) throws -> URL {
        let home = sandboxHome(for: serverID)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        chmod(home.path, S_IRWXU)
        return home
    }

    public func filteredEnvironment(from environment: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        environment.filter { key, _ in
            !Self.restrictedEnvironmentKeys.contains(key) &&
            !key.localizedCaseInsensitiveContains("TOKEN") &&
            !key.localizedCaseInsensitiveContains("SECRET") &&
            !key.localizedCaseInsensitiveContains("API_KEY")
        }
    }

    public func descriptorHash(name: String, command: String, arguments: [String]) -> String {
        let normalized = ([name, command] + arguments).joined(separator: "\u{1F}")
        return String(normalized.utf8.reduce(UInt64(1469598103934665603)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
        }, radix: 16)
    }
}

public final class MCPRateLimiter: @unchecked Sendable {
    private let maxCalls: Int
    private let window: TimeInterval
    private var callsByServer: [UUID: [Date]] = [:]
    private let lock = NSLock()

    public init(maxCalls: Int = 60, window: TimeInterval = 60) {
        self.maxCalls = maxCalls
        self.window = window
    }

    public func allowsCall(serverID: UUID, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = now.addingTimeInterval(-window)
        let recent = (callsByServer[serverID] ?? []).filter { $0 >= cutoff }
        guard recent.count < maxCalls else {
            callsByServer[serverID] = recent
            return false
        }
        callsByServer[serverID] = recent + [now]
        return true
    }
}

public enum TerminalInputSanitizer {
    public static func sanitize(_ input: String) -> String {
        var result = ""
        var index = input.startIndex

        while index < input.endIndex {
            let scalar = input[index].unicodeScalars.first
            if scalar?.value == 0x1B {
                let next = input.index(after: index)
                guard next < input.endIndex else { break }

                let nextScalar = input[next].unicodeScalars.first?.value
                if nextScalar == 0x5D {
                    index = skipOSC(in: input, from: index)
                    continue
                }
                if nextScalar == 0x50 || nextScalar == 0x5E || nextScalar == 0x5F {
                    index = skipStringTerminatedSequence(in: input, from: index)
                    continue
                }
            }

            result.append(input[index])
            index = input.index(after: index)
        }

        return result
    }

    private static func skipOSC(in input: String, from start: String.Index) -> String.Index {
        var index = input.index(after: input.index(after: start))
        while index < input.endIndex {
            if input[index].unicodeScalars.first?.value == 0x07 {
                return input.index(after: index)
            }
            if input[index].unicodeScalars.first?.value == 0x1B {
                let next = input.index(after: index)
                if next < input.endIndex, input[next] == "\\" {
                    return input.index(after: next)
                }
            }
            index = input.index(after: index)
        }
        return input.endIndex
    }

    private static func skipStringTerminatedSequence(in input: String, from start: String.Index) -> String.Index {
        var index = input.index(after: input.index(after: start))
        while index < input.endIndex {
            if input[index].unicodeScalars.first?.value == 0x1B {
                let next = input.index(after: index)
                if next < input.endIndex, input[next] == "\\" {
                    return input.index(after: next)
                }
            }
            index = input.index(after: index)
        }
        return input.endIndex
    }
}

public final class ToolDispatcher {
    private let permissionGate: PermissionGate
    private let gitReviewService: GitReviewService
    private let auditLogger: AuditLogger?

    public init(
        permissionGate: PermissionGate,
        gitReviewService: GitReviewService = GitReviewService(),
        auditLogger: AuditLogger? = nil
    ) {
        self.permissionGate = permissionGate
        self.gitReviewService = gitReviewService
        self.auditLogger = auditLogger
    }

    public func dispatch(_ action: ToolAction, source: ToolCallSource = .agent) throws -> String {
        let evaluation = permissionGate.evaluate(action, source: source)
        auditLogger?.append(AuditLogEntry(
            action: auditAction(for: evaluation.decision),
            source: source,
            risk: evaluation.decision.risk,
            subject: action.displayName,
            detail: evaluation.decision.reason
        ))

        guard evaluation.decision.isAllowed else {
            throw ToolDispatchError.denied(evaluation.decision.reason)
        }

        switch action {
        case .readFile(let path):
            return try String(contentsOfFile: path, encoding: .utf8)
        case .gitDiff(let path):
            return try gitReviewService.diff(path: path)
        case .gitStatus(let path):
            let statusService = GitReviewService(repositoryPath: path)
            let summary = try statusService.status()
            return summary.files.map { "\($0.indexStatus)\($0.workTreeStatus) \($0.path)" }.joined(separator: "\n")
        case .mcpList:
            return "MCP list is available through `warp mcp list`."
        case .mcpCall:
            throw ToolDispatchError.unsupported("MCP tool invocation is not available from this dispatcher yet.")
        case .shell(let command):
            return try runShell(command)
        case .editFile(let path, let content), .writeFile(let path, let content):
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return "Wrote \(path)"
        case .deleteFile(let path):
            try FileManager.default.removeItem(atPath: path)
            return "Deleted \(path)"
        case .gitPush:
            throw ToolDispatchError.unsupported("Git push is intentionally not executed by the default dispatcher.")
        case .networkRequest, .openURL:
            throw ToolDispatchError.unsupported("Network and URL actions must be handled by a provider-specific client.")
        }
    }

    private func runShell(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw ToolDispatchError.failed(errorText.isEmpty ? outputText : errorText)
        }
        return outputText
    }

    private func auditAction(for decision: PermissionDecision) -> AuditAction {
        if decision.isAllowed {
            return .permissionAllowed
        }
        if decision.requiresUserApproval {
            return .commandNeedsApproval
        }
        return .commandBlocked
    }
}

public enum ToolDispatchError: Error, LocalizedError {
    case denied(String)
    case failed(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .denied(let reason):
            return "Tool action denied: \(reason)"
        case .failed(let message):
            return message
        case .unsupported(let message):
            return message
        }
    }
}
