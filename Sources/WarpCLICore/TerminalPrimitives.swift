import Darwin
import Foundation

public enum Screen {
    public enum Direction {
        case up
        case down
        case right
        case left

        var code: String {
            switch self {
            case .up: "A"
            case .down: "B"
            case .right: "C"
            case .left: "D"
            }
        }
    }

    public enum ColorTarget {
        case foreground
        case background

        var code: String {
            switch self {
            case .foreground: "38"
            case .background: "48"
            }
        }
    }

    public static let reset = "\u{001B}[0m"
    public static let hideCursor = "\u{001B}[?25l"
    public static let showCursor = "\u{001B}[?25h"

    public static func move(_ direction: Direction, count: Int = 1) -> String {
        "\u{001B}[\(max(1, count))\(direction.code)"
    }

    public static func clearLine() -> String {
        "\u{001B}[2K\r"
    }

    public static func clearScreen() -> String {
        "\u{001B}[2J\u{001B}[H"
    }

    public static func bold(_ text: String) -> String {
        "\u{001B}[1m\(text)\(reset)"
    }

    public static func dim(_ text: String) -> String {
        "\u{001B}[2m\(text)\(reset)"
    }

    public static func italic(_ text: String) -> String {
        "\u{001B}[3m\(text)\(reset)"
    }

    public static func underline(_ text: String) -> String {
        "\u{001B}[4m\(text)\(reset)"
    }

    public static func color256(_ target: ColorTarget, index: UInt8) -> String {
        "\u{001B}[\(target.code);5;\(index)m"
    }

    public static func trueColor(_ target: ColorTarget, red: UInt8, green: UInt8, blue: UInt8) -> String {
        "\u{001B}[\(target.code);2;\(red);\(green);\(blue)m"
    }

    public static func terminalSize() -> (columns: Int, rows: Int) {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 else {
            return (80, 24)
        }
        return (Int(size.ws_col), Int(size.ws_row))
    }
}

public enum CLIBlockStatus: Equatable {
    case running
    case success
    case failure(Int32)

    var icon: String {
        switch self {
        case .running: "●"
        case .success: "✓"
        case .failure: "✕"
        }
    }

    var color: String {
        switch self {
        case .running: Screen.trueColor(.foreground, red: 64, green: 156, blue: 255)
        case .success: Screen.trueColor(.foreground, red: 48, green: 209, blue: 88)
        case .failure: Screen.trueColor(.foreground, red: 255, green: 69, blue: 58)
        }
    }
}

public struct BlockRenderer {
    public init() {}

    public func render(command: String, output: String, status: CLIBlockStatus, startedAt: Date, duration: TimeInterval) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .none
        let durationText = String(format: "%.2fs", duration)
        let header = "\(status.color)\(status.icon)\(Screen.reset) \(Screen.bold(command)) \(Screen.dim(dateFormatter.string(from: startedAt))) \(Screen.dim(durationText))"
        let body = output.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "│ \($0)" }
            .joined(separator: "\n")
        return """
        \(header)
        \(status.color)│\(Screen.reset)
        \(body)
        \(status.color)│\(Screen.reset) Copy  Share  Bookmark  Delete  Ask AI
        """
    }
}

public final class TerminalRawMode {
    private var original = termios()
    private var enabled = false

    public init() {}

    public func enable() throws {
        guard !enabled else { return }
        guard tcgetattr(STDIN_FILENO, &original) == 0 else {
            throw POSIXError(.EIO)
        }
        var raw = original
        raw.c_lflag &= ~(UInt(ECHO | ICANON | IEXTEN | ISIG))
        raw.c_iflag &= ~(UInt(BRKINT | ICRNL | INPCK | ISTRIP | IXON))
        raw.c_cflag |= UInt(CS8)
        raw.c_oflag &= ~(UInt(OPOST))
        raw.c_cc.16 = 1
        raw.c_cc.17 = 0
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw POSIXError(.EIO)
        }
        enabled = true
    }

    public func disable() {
        guard enabled else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        enabled = false
    }

    deinit {
        disable()
    }
}

public struct InputLine {
    public init() {}

    public func read(prompt: String = "warp> ") -> String? {
        FileHandle.standardOutput.write(Data(prompt.utf8))
        return Swift.readLine()
    }
}

public final class TerminalUI {
    private let input = InputLine()
    private let sessions: CLISessionStore

    public init(sessions: CLISessionStore = CLISessionStore()) {
        self.sessions = sessions
    }

    public func run(resumeSessionId: String?, agentMode: Bool) throws {
        let session: CLISession
        if let resumeSessionId, let loaded = try? sessions.load(id: resumeSessionId) {
            session = loaded
            print("Resumed session \(session.id)")
        } else {
            session = CLISession()
            try sessions.save(session)
            print("Started session \(session.id)")
        }

        print("Type /help for commands, /exit to quit.")
        while let line = input.read(prompt: agentMode ? "warp-agent> " : "warp> ") {
            if line == "/exit" { break }
            if line == "/help" {
                print("/exit, /help, /sessions")
            } else if line == "/sessions" {
                try sessions.list().forEach { print("\($0.id) \($0.updatedAt)") }
            } else {
                try sessions.append(.user(line), to: session.id)
                print(Screen.dim("Captured input. Use `warp ask` for one-shot provider calls."))
            }
        }
    }
}
