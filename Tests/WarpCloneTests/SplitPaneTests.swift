import XCTest
@testable import WarpClone

@MainActor
final class SplitPaneTests: XCTestCase {
    func testSplitAndClosePaneUpdatesFocus() {
        let store = SessionStore()
        let originalPane = store.activePaneID

        store.splitActivePane(shellPath: "/bin/zsh")

        XCTAssertEqual(store.selectedSession?.panes.count, 2)
        XCTAssertNotEqual(store.activePaneID, originalPane)

        store.closeActivePane()

        XCTAssertEqual(store.selectedSession?.panes.count, 1)
        XCTAssertEqual(store.activePaneID, originalPane)
    }
}
