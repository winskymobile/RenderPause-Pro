import CoreGraphics
import XCTest
@testable import RenderPausePro

final class OcclusionDetectorTests: XCTestCase {
    func testUncoveredWindowIsFullyVisible() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let fraction = OcclusionDetector.residualVisibleFraction(of: rect, coveredBy: [])
        XCTAssertEqual(fraction, 1, accuracy: 0.001)
        XCTAssertTrue(OcclusionDetector.hasSignificantResidual(of: rect, coveredBy: []))
    }

    func testFullyCoveredWindowHasNearZeroResidual() {
        let target = CGRect(x: 100, y: 100, width: 800, height: 600)
        let cover = CGRect(x: 50, y: 50, width: 1000, height: 800)
        let fraction = OcclusionDetector.residualVisibleFraction(of: target, coveredBy: [cover])
        XCTAssertLessThanOrEqual(fraction, OcclusionDetector.residualVisibleThreshold)
        XCTAssertFalse(OcclusionDetector.hasSignificantResidual(of: target, coveredBy: [cover]))
    }

    func testPartialPeekLeavesResidualAboveThreshold() {
        let target = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // Covers left 90% only — right 10% peeks.
        let cover = CGRect(x: 0, y: 0, width: 900, height: 800)
        let fraction = OcclusionDetector.residualVisibleFraction(of: target, coveredBy: [cover])
        XCTAssertGreaterThan(fraction, OcclusionDetector.residualVisibleThreshold)
        XCTAssertEqual(fraction, 0.1, accuracy: 0.02)
        XCTAssertTrue(OcclusionDetector.hasSignificantResidual(of: target, coveredBy: [cover]))
    }

    func testThinPeekStillProtectsViaMinArea() {
        // 20pt strip on a 1000x800 window = 2% of width = 16_000 area, above 2500.
        let target = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let cover = CGRect(x: 0, y: 0, width: 980, height: 800)
        XCTAssertTrue(OcclusionDetector.hasSignificantResidual(of: target, coveredBy: [cover]))
    }

    func testMultiCoverStackCanFullyOcclude() {
        let target = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let left = CGRect(x: 0, y: 0, width: 500, height: 800)
        let right = CGRect(x: 500, y: 0, width: 500, height: 800)
        XCTAssertFalse(OcclusionDetector.hasSignificantResidual(of: target, coveredBy: [left, right]))
    }

    func testIsPartiallyVisibleWhenFrontWindowDoesNotFullyCover() {
        let front = SplitViewDetector.WindowRect(
            bundleID: "com.front.app",
            bounds: CGRect(x: 0, y: 0, width: 700, height: 800),
            layer: 0
        )
        let back = SplitViewDetector.WindowRect(
            bundleID: "com.back.app",
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            layer: 0
        )
        let windows = [front, back]
        XCTAssertTrue(OcclusionDetector.isPartiallyVisible(bundleID: "com.back.app", windows: windows))
        XCTAssertTrue(OcclusionDetector.isPartiallyVisible(bundleID: "com.front.app", windows: windows))
    }

    func testIsNotPartiallyVisibleWhenFullyCovered() {
        let front = SplitViewDetector.WindowRect(
            bundleID: "com.front.app",
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 900),
            layer: 0
        )
        let back = SplitViewDetector.WindowRect(
            bundleID: "com.back.app",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            layer: 0
        )
        let windows = [front, back]
        XCTAssertFalse(OcclusionDetector.isPartiallyVisible(bundleID: "com.back.app", windows: windows))
    }

    func testDockFullScreenLayerDoesNotForceFullOcclusion() {
        // Regression: Dock reports a huge layer-20 region that used to mark every
        // background app as fully occluded even when still peeking.
        let dock = SplitViewDetector.WindowRect(
            bundleID: "com.apple.dock",
            bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            layer: 20
        )
        let front = SplitViewDetector.WindowRect(
            bundleID: "com.front.app",
            bounds: CGRect(x: 0, y: 40, width: 700, height: 900),
            layer: 0
        )
        let back = SplitViewDetector.WindowRect(
            bundleID: "com.back.app",
            bounds: CGRect(x: 0, y: 40, width: 1000, height: 900),
            layer: 0
        )
        let windows = [dock, front, back]
        XCTAssertTrue(
            OcclusionDetector.isPartiallyVisible(bundleID: "com.back.app", windows: windows),
            "Peeking app must stay protected even when Dock precedes it in the window list"
        )
    }

    func testEmptyTargetWindowsNotPartiallyVisible() {
        let front = SplitViewDetector.WindowRect(
            bundleID: "com.front.app",
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 900),
            layer: 0
        )
        XCTAssertFalse(OcclusionDetector.isPartiallyVisible(bundleID: "com.missing.app", windows: [front]))
    }

    func testSubtractProducesNonOverlappingParts() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let cut = CGRect(x: 25, y: 25, width: 50, height: 50)
        let parts = OcclusionDetector.subtract(rect, minus: cut)
        let area = parts.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
        XCTAssertEqual(area, 100 * 100 - 50 * 50, accuracy: 1)
        XCTAssertFalse(parts.isEmpty)
    }
}
