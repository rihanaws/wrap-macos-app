import Foundation
import WarpCLICore
import Darwin

@_silgen_name("fork")
private func c_fork() -> pid_t

final class PTYSession {
    enum PTYError: Error, LocalizedError {
        case openFailed
        case grantFailed
        case unlockFailed
        case missingSlaveName
        case forkFailed

        var errorDescription: String? {
            switch self {
            case .openFailed: "Failed to open pseudo-terminal."
            case .grantFailed: "Failed to grant pseudo-terminal."
            case .unlockFailed: "Failed to unlock pseudo-terminal."
            case .missingSlaveName: "Failed to resolve pseudo-terminal slave name."
            case .forkFailed: "Failed to fork shell process."
            }
        }
    }

    private(set) var masterFD: Int32 = -1
    private(set) var childPID: pid_t = -1
    private let readQueue = DispatchQueue(label: "warpclone.pty.read", qos: .userInitiated)
    private var isReading = false

    func spawn(
        shellPath: String,
        workingDirectory: String,
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) throws {
        masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFD >= 0 else { throw PTYError.openFailed }
        guard grantpt(masterFD) == 0 else { throw PTYError.grantFailed }
        guard unlockpt(masterFD) == 0 else { throw PTYError.unlockFailed }
        guard let slaveNamePointer = ptsname(masterFD) else { throw PTYError.missingSlaveName }
        let slaveName = String(cString: slaveNamePointer)

        childPID = c_fork()
        if childPID < 0 {
            throw PTYError.forkFailed
        }

        if childPID == 0 {
            setsid()
            let slaveFD = open(slaveName, O_RDWR)
            if slaveFD >= 0 {
                dup2(slaveFD, STDIN_FILENO)
                dup2(slaveFD, STDOUT_FILENO)
                dup2(slaveFD, STDERR_FILENO)
                if slaveFD > STDERR_FILENO {
                    close(slaveFD)
                }
            }
            close(masterFD)
            chdir(workingDirectory)
            setenv("TERM", "xterm-256color", 1)
            let shellCString = strdup(shellPath)
            let loginCString = strdup("-l")
            var argv: [UnsafeMutablePointer<CChar>?] = [shellCString, loginCString, nil]
            execv(shellPath, &argv)
            _exit(127)
        }

        beginReadLoop(onOutput: onOutput, onExit: onExit)
    }

    func write(_ text: String) {
        guard masterFD >= 0 else { return }
        let sanitizedText = TerminalInputSanitizer.sanitize(text)
        let bytes = Array(sanitizedText.utf8)
        bytes.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            _ = Darwin.write(masterFD, baseAddress, pointer.count)
        }
    }

    func resize(columns: UInt16, rows: UInt16) {
        guard masterFD >= 0 else { return }
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFD, TIOCSWINSZ, &size)
        if childPID > 0 {
            kill(childPID, SIGWINCH)
        }
    }

    func terminate() {
        if childPID > 0 {
            kill(childPID, SIGHUP)
            childPID = -1
        }
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
        isReading = false
    }

    private func beginReadLoop(
        onOutput: @escaping @Sendable (String) -> Void,
        onExit: @escaping @Sendable (Int32) -> Void
    ) {
        isReading = true
        let fd = masterFD
        let pid = childPID
        readQueue.async { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            while self?.isReading == true {
                let count = Darwin.read(fd, &buffer, buffer.count)
                if count > 0 {
                    let data = Data(buffer[0..<count])
                    if let text = String(data: data, encoding: .utf8) {
                        onOutput(text)
                    }
                } else {
                    break
                }
            }

            var status: Int32 = 0
            waitpid(pid, &status, 0)
            let exitCode: Int32
            if (status & 0x7F) == 0 {
                exitCode = (status >> 8) & 0xFF
            } else {
                exitCode = -1
            }
            onExit(exitCode)
        }
    }

    deinit {
        terminate()
    }
}
