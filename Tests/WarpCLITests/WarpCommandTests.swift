import XCTest
import ArgumentParser
@testable import WarpCLICore

final class WarpCommandTests: XCTestCase {
    func testRootCommandExposesExpectedSubcommands() {
        let names = Set(WarpCommand.configuration.subcommands.map { $0.configuration.commandName })

        XCTAssertEqual(names, ["ask", "chat", "agent", "review", "mcp", "config"])
        XCTAssertEqual(WarpCommand.configuration.commandName, "warp")
        XCTAssertEqual(WarpCommand.configuration.defaultSubcommand?.configuration.commandName, "chat")
    }

    func testMCPCommandExposesManagementSubcommands() {
        let names = Set(MCPCommand.configuration.subcommands.map { $0.configuration.commandName })

        XCTAssertEqual(names, ["list", "discover", "start", "stop"])
        XCTAssertEqual(MCPCommand.configuration.defaultSubcommand?.configuration.commandName, "list")
    }
}
