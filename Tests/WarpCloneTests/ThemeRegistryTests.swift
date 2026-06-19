import XCTest
@testable import WarpClone

final class ThemeRegistryTests: XCTestCase {
    func testContainsExactlyTwentyOneThemes() {
        XCTAssertEqual(ThemeRegistry.themes.count, 21)
        XCTAssertEqual(Set(ThemeRegistry.themes.map(\.id)).count, 21)
        XCTAssertTrue(ThemeRegistry.themes.allSatisfy { !$0.blockBackground.isEmpty })
    }
}
