import Foundation
import WarpCLICore

enum BlockStatus: String, Codable, CaseIterable, Equatable {
    case running
    case succeeded
    case failed
    case cancelled

    var symbolName: String {
        switch self {
        case .running: "clock.arrow.circlepath"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .cancelled: "minus.circle.fill"
        }
    }
}

struct TerminalBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var command: String
    var rawOutput: String
    var status: BlockStatus
    var startedAt: Date
    var endedAt: Date?
    var isBookmarked: Bool

    init(
        id: UUID = UUID(),
        command: String,
        rawOutput: String = "",
        status: BlockStatus = .running,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.command = command
        self.rawOutput = AIOutputSanitizer.sanitize(rawOutput)
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isBookmarked = isBookmarked
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

struct TerminalPane: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var workingDirectory: String
    var shellPath: String
    var blocks: [TerminalBlock]
    var liveOutput: String

    init(
        id: UUID = UUID(),
        title: String,
        workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        shellPath: String = "/bin/zsh",
        blocks: [TerminalBlock] = [],
        liveOutput: String = ""
    ) {
        self.id = id
        self.title = title
        self.workingDirectory = workingDirectory
        self.shellPath = shellPath
        self.blocks = blocks
        self.liveOutput = liveOutput
    }
}

enum SplitAxis: String, Codable, Equatable {
    case horizontal
    case vertical
}

struct PaneGroup: Codable, Equatable {
    var axis: SplitAxis
    var paneIDs: [UUID]
}

struct TerminalSession: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var workingDirectory: String
    var gitBranch: String?
    var panes: [TerminalPane]
    var activePaneID: UUID
    var splitGroup: PaneGroup
    var unreadActivity: Bool

    init(
        id: UUID = UUID(),
        name: String,
        workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        gitBranch: String? = nil
    ) {
        let pane = TerminalPane(title: name, workingDirectory: workingDirectory)
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.gitBranch = gitBranch
        self.panes = [pane]
        self.activePaneID = pane.id
        self.splitGroup = PaneGroup(axis: .horizontal, paneIDs: [pane.id])
        self.unreadActivity = false
    }
}

enum InspectorTab: String, CaseIterable, Identifiable, Codable {
    case ai = "AI"
    case codeReview = "Code Review"
    case mcp = "MCP"

    var id: String { rawValue }
}

enum AIProviderKind: String, CaseIterable, Identifiable, Codable {
    case openAICompatible = "OpenAI Compatible"
    case anthropic = "Anthropic"
    case googleGemini = "Google Gemini"
    case openRouter = "OpenRouter"
    case copilot = "GitHub Copilot"

    var id: String { rawValue }

    var keychainServiceName: String {
        "com.warpclone.\(rawValue.replacingOccurrences(of: " ", with: "-").lowercased())"
    }
}

struct AIModel: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var supportsVision: Bool
    var contextWindow: Int
}

struct AIResponseChunk: Codable, Equatable {
    var text: String
    var isFinal: Bool
}

struct ImageAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var mimeType: String
    var data: Data
    var thumbnailData: Data
    var detectedVisionCompatible: Bool

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        data: Data,
        thumbnailData: Data,
        detectedVisionCompatible: Bool
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
        self.thumbnailData = thumbnailData
        self.detectedVisionCompatible = detectedVisionCompatible
    }
}

struct GitChangedFile: Identifiable, Codable, Equatable {
    var id: String { path }
    var path: String
    var status: String
    var staged: Bool
}

struct MCPServer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var arguments: [String]
    var status: MCPStatus
    var configPath: String
    var descriptorHash: String
    var isApproved: Bool

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        arguments: [String] = [],
        status: MCPStatus = .stopped,
        configPath: String,
        descriptorHash: String = "",
        isApproved: Bool = false
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.arguments = arguments
        self.status = status
        self.configPath = configPath
        self.descriptorHash = descriptorHash
        self.isApproved = isApproved
    }
}

enum MCPStatus: String, Codable, Equatable {
    case discovered
    case running
    case stopped
    case failed
}
