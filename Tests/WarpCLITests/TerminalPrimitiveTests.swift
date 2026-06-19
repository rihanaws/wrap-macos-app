import XCTest
@testable import WarpCLICore

final class TerminalPrimitiveTests: XCTestCase {
    func testANSIScreenPrimitives() {
        XCTAssertEqual(Screen.bold("hello"), "\u{001B}[1mhello\u{001B}[0m")
        XCTAssertEqual(Screen.trueColor(.foreground, red: 12, green: 34, blue: 56), "\u{001B}[38;2;12;34;56m")
        XCTAssertEqual(Screen.move(.up, count: 3), "\u{001B}[3A")
        XCTAssertEqual(Screen.clearLine(), "\u{001B}[2K\r")
    }

    func testBlockRendererIncludesStatusDurationAndLeftBorder() {
        let block = BlockRenderer().render(
            command: "git status",
            output: "clean",
            status: .success,
            startedAt: Date(timeIntervalSince1970: 0),
            duration: 1.25
        )

        XCTAssertTrue(block.contains("git status"))
        XCTAssertTrue(block.contains("1.25s"))
        XCTAssertTrue(block.contains("✓"))
        XCTAssertTrue(block.contains("│"))
    }
}
