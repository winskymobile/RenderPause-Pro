import XCTest
@testable import RenderPausePro

final class SplitViewDetectorTests: XCTestCase {
    func testSideBySideLargeWindowsLookLikeSplit() {
        let left = CGRect(x: 0, y: 0, width: 700, height: 900)
        let right = CGRect(x: 700, y: 0, width: 740, height: 900)
        XCTAssertTrue(
            SplitViewDetector.looksLikeSplitPair(left, right, screenWidth: 1440, screenHeight: 900)
        )
    }

    func testStackedOrCoveringWindowsDoNotLookLikeSplit() {
        let full = CGRect(x: 0, y: 0, width: 1400, height: 900)
        let covered = CGRect(x: 100, y: 100, width: 1200, height: 700)
        XCTAssertFalse(
            SplitViewDetector.looksLikeSplitPair(full, covered, screenWidth: 1440, screenHeight: 900)
        )
    }

    func testTinyFloatingWindowsDoNotLookLikeSplit() {
        let a = CGRect(x: 0, y: 0, width: 120, height: 120)
        let b = CGRect(x: 200, y: 0, width: 120, height: 120)
        XCTAssertFalse(
            SplitViewDetector.looksLikeSplitPair(a, b, screenWidth: 1440, screenHeight: 900)
        )
    }
}
