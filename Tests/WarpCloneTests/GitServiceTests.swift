import XCTest
@testable import WarpClone

final class GitServiceTests: XCTestCase {
    func testParsesPorcelainStatus() throws {
        let service = GitService()
        let files = try service.parseStatus("""
         M Sources/App.swift
        A  Tests/AppTests.swift
        ?? README.md
        """)

        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].path, "Sources/App.swift")
        XCTAssertEqual(files[0].status, "M")
        XCTAssertFalse(files[0].staged)
        XCTAssertTrue(files[1].staged)
    }
}
