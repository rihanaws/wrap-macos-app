import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var git: GitService
    @EnvironmentObject private var mcp: MCPManager
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search commands, sessions, files, MCP tools…", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding()
            Divider()
            List(filteredActions) { action in
                Button {
                    dispatch(action)
                } label: {
                    VStack(alignment: .leading) {
                        Text(action.title)
                        Text("\(action.group) • \(action.subtitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredActions: [CommandPaletteAction] {
        let blocks = sessions.selectedSession?.panes.flatMap(\.blocks) ?? []
        let actions = CommandPaletteIndex.actions(
            sessions: sessions.sessions,
            blocks: blocks,
            files: git.changedFiles,
            mcpServers: mcp.servers
        )
        return CommandPaletteIndex.filter(actions, query: query)
    }

    private func dispatch(_ action: CommandPaletteAction) {
        switch action.id {
        case "session.new":
            sessions.newSession(shellPath: "/bin/zsh")
        case "pane.split":
            sessions.splitActivePane(shellPath: "/bin/zsh")
        case "ai.toggle":
            sessions.isAIMode.toggle()
        case "view.inspector":
            NotificationCenter.default.post(name: .toggleWarpCloneInspector, object: nil)
        case "git.refresh":
            if let path = sessions.selectedSession?.workingDirectory {
                git.refresh(repositoryPath: path)
            }
        case "mcp.discover":
            mcp.discover()
        default:
            if action.id.hasPrefix("session."),
               let uuid = UUID(uuidString: action.id.replacingOccurrences(of: "session.", with: "")) {
                sessions.selectedSessionID = uuid
            }
        }
        sessions.commandPaletteVisible = false
        dismiss()
    }
}
