import XCTest
@testable import WarpClone

final class ANSIParserTests: XCTestCase {
    func testParsesSixteenColorAndReset() {
        let spans = ANSIParser().parse("\u{1B}[31mred\u{1B}[0mplain")

        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].text, "red")
        XCTAssertEqual(spans[0].style.foreground, TerminalColor(kind: .palette(1)))
        XCTAssertEqual(spans[1].text, "plain")
        XCTAssertNil(spans[1].style.foreground)
    }

    func testParses256Color() {
        let spans = ANSIParser().parse("\u{1B}[38;5;196mhot")

        XCTAssertEqual(spans[0].style.foreground, TerminalColor(kind: .palette(196)))
    }

    func testParsesTrueColorAndAttributes() {
        let spans = ANSIParser().parse("\u{1B}[1;3;4;38;2;12;34;56mstyled")

        XCTAssertTrue(spans[0].style.bold)
        XCTAssertTrue(spans[0].style.italic)
        XCTAssertTrue(spans[0].style.underline)
        XCTAssertEqual(spans[0].style.foreground, TerminalColor(kind: .rgb(12, 34, 56)))
    }
}
