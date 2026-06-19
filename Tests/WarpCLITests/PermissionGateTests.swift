import XCTest
@testable import WarpCLICore

final class PermissionGateTests: XCTestCase {
    func testAllowReadModeAllowsReadOnlyToolsAndBlocksMutation() {
        let gate = PermissionGate(mode: .allowRead)

        XCTAssertTrue(gate.evaluate(.readFile(path: "/tmp/a")).isAllowed)
        XCTAssertTrue(gate.evaluate(.gitDiff(path: "/repo")).isAllowed)
        XCTAssertFalse(gate.evaluate(.shell(command: "rm -rf /tmp/example")).isAllowed)
    }

    func testAllowWriteModeAllowsFileMutationButNotShell() {
        let gate = PermissionGate(mode: .allowWrite)

        XCTAssertTrue(gate.evaluate(.writeFile(path: "/tmp/a", content: "x")).isAllowed)
        XCTAssertTrue(gate.evaluate(.editFile(path: "/tmp/a", replacement: "y")).isAllowed)
        XCTAssertFalse(gate.evaluate(.shell(command: "rm -rf /tmp/example")).isAllowed)
    }

    func testAskModeRequiresApprovalForReadOnlyTools() {
        let gate = PermissionGate(mode: .ask)

        let evaluation = gate.evaluate(.readFile(path: "/tmp/a"))

        XCTAssertFalse(evaluation.isAllowed)
        XCTAssertTrue(evaluation.requiresUserApproval)
        XCTAssertEqual(evaluation.risk, .readOnly)
    }
}
