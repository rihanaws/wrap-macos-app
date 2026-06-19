import XCTest
@testable import WarpClone

final class CommandPaletteTests: XCTestCase {
    func testFiltersActionsAcrossGroups() {
        let actions = CommandPaletteIndex.actions(
            sessions: [TerminalSession(name: "Backend API")],
            blocks: [TerminalBlock(command: "swift test")],
            files: [GitChangedFile(path: "Sources/App.swift", status: "M", staged: false)],
            mcpServers: [MCPServer(name: "filesystem", command: "/bin/echo", configPath: "/tmp/mcp.json")]
        )

        XCTAssertTrue(CommandPaletteIndex.filter(actions, query: "backend").contains { $0.title == "Backend API" })
        XCTAssertTrue(CommandPaletteIndex.filter(actions, query: "mcp").contains { $0.group == "MCP" })
    }
}
