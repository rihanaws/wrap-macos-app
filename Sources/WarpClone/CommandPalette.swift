import Foundation

struct CommandPaletteAction: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var group: String
}

enum CommandPaletteIndex {
    static func actions(
        sessions: [TerminalSession],
        blocks: [TerminalBlock],
        files: [GitChangedFile],
        mcpServers: [MCPServer]
    ) -> [CommandPaletteAction] {
        var result: [CommandPaletteAction] = [
            .init(id: "session.new", title: "New Session", subtitle: "Create a terminal session", group: "Session"),
            .init(id: "pane.split", title: "Split Pane", subtitle: "Split the active terminal pane", group: "Session"),
            .init(id: "ai.toggle", title: "Toggle AI Mode", subtitle: "Switch # editor mode", group: "AI"),
            .init(id: "view.inspector", title: "Toggle Inspector", subtitle: "Show or hide metadata inspector", group: "View"),
            .init(id: "git.refresh", title: "Refresh Git Review", subtitle: "Reload changed files", group: "Code Review"),
            .init(id: "mcp.discover", title: "Discover MCP Servers", subtitle: "Scan local config files", group: "MCP")
        ]
        result += sessions.map { .init(id: "session.\($0.id)", title: $0.name, subtitle: $0.workingDirectory, group: "Sessions") }
        result += blocks.map { .init(id: "block.\($0.id)", title: $0.command, subtitle: $0.status.rawValue, group: "Blocks") }
        result += files.map { .init(id: "file.\($0.path)", title: $0.path, subtitle: $0.status, group: "Code Review") }
        result += mcpServers.map { .init(id: "mcp.\($0.id)", title: $0.name, subtitle: $0.status.rawValue, group: "MCP") }
        return result
    }

    static func filter(_ actions: [CommandPaletteAction], query: String) -> [CommandPaletteAction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return actions }
        return actions.filter {
            $0.title.lowercased().contains(trimmed) ||
            $0.subtitle.lowercased().contains(trimmed) ||
            $0.group.lowercased().contains(trimmed)
        }
    }
}
