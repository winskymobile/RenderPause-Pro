import XCTest
@testable import RenderPausePro

final class SessionStoreTests: XCTestCase {
    func testDefaultWatched() {
        let s = SessionStore()
        XCTAssertEqual(s.state(for: "x"), .watched)
    }

    func testSetAndClear() {
        let s = SessionStore()
        s.set("x", .optimized)
        XCTAssertEqual(s.state(for: "x"), .optimized)
        s.clear("x")
        XCTAssertEqual(s.state(for: "x"), .watched)
    }

    func testOptimizedBundleIDs() {
        let s = SessionStore()
        s.set("a", .optimized)
        s.set("b", .watched)
        s.set("c", .paused)
        XCTAssertEqual(s.optimizedBundleIDs(), ["a"])
    }
}
