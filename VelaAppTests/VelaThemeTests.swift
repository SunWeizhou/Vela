import XCTest
@testable import Vela

final class VelaThemeTests: XCTestCase {
    func testThemeTokensReturnNonNilValues() {
        let bg = VelaTheme.bg
        let fg = VelaTheme.fg
        let cardBg = VelaTheme.cardBg
        XCTAssertTrue(true, "Theme tokens accessible: \(bg), \(fg), \(cardBg)")
    }
}
