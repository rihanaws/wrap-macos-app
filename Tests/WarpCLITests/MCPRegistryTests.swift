import XCTest
@testable import WarpCLICore

final class MCPRegistryTests: XCTestCase {
    func testParsesClaudeStyleMCPServerConfig() throws {
        let data = """
        {
          "mcpServers": {
            "filesystem": {
              "command": "npx",
              "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
              "env": { "LOG_LEVEL": "debug" }
            }
          }
        }
        """.data(using: .utf8)!

        let servers = try MCPRegistryParser.parseClaudeJSON(data: data, source: URL(fileURLWithPath: "/tmp/mcp.json"))

        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers[0].name, "filesystem")
        XCTAssertEqual(servers[0].command, "npx")
        XCTAssertEqual(servers[0].args.last, "/tmp")
        XCTAssertEqual(servers[0].environment["LOG_LEVEL"], "debug")
    }
}
