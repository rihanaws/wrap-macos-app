import Foundation

@MainActor
final class TerminalRuntimeStore: ObservableObject {
    private var sessions: [UUID: PTYSession] = [:]

    func ensureStarted(
        pane: TerminalPane,
        onOutput: @escaping (String) -> Void,
        onExit: @escaping (Int32) -> Void
    ) {
        guard sessions[pane.id] == nil else { return }
        let pty = PTYSession()
        sessions[pane.id] = pty
        do {
            try pty.spawn(
                shellPath: pane.shellPath,
                workingDirectory: pane.workingDirectory,
                onOutput: { text in
                    DispatchQueue.main.async { onOutput(text) }
                },
                onExit: { code in
                    DispatchQueue.main.async { onExit(code) }
                }
            )
        } catch {
            onOutput(error.localizedDescription)
            sessions[pane.id] = nil
        }
    }

    func send(_ text: String, to paneID: UUID?) {
        guard let paneID else { return }
        sessions[paneID]?.write(text + "\n")
    }

    func resize(paneID: UUID, columns: UInt16, rows: UInt16) {
        sessions[paneID]?.resize(columns: columns, rows: rows)
    }

    func stop(paneID: UUID) {
        sessions[paneID]?.terminate()
        sessions[paneID] = nil
    }
}
