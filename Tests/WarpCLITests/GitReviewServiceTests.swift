import XCTest
@testable import WarpCLICore

final class WarpCLIGitReviewServiceTests: XCTestCase {
    func testParsesPorcelainStatusWithBranchAndStates() {
        let status = """
        ## main...origin/main
         M Sources/App.swift
        A  README.md
        ?? Sources/New.swift
        """

        let parsed = GitReviewService.parseStatus(status)

        XCTAssertEqual(parsed.branch, "main")
        XCTAssertEqual(parsed.files.map(\.path), ["Sources/App.swift", "README.md", "Sources/New.swift"])
        XCTAssertEqual(parsed.files.map(\.indexStatus), [" ", "A", "?"])
        XCTAssertEqual(parsed.files.map(\.workTreeStatus), ["M", " ", "?"])
    }
}
