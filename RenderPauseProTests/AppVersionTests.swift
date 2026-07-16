import XCTest
@testable import RenderPausePro

final class AppVersionTests: XCTestCase {
    func testParseStripsVAndPrerelease() {
        XCTAssertEqual(AppVersion.parse("v1.1.0")?.display, "1.1.0")
        XCTAssertEqual(AppVersion.parse("1.0.1-beta")?.display, "1.0.1")
        XCTAssertEqual(AppVersion.parse("2.0")?.display, "2.0.0")
    }

    func testCompareOrdering() {
        let a = AppVersion.parse("1.0.1")!
        let b = AppVersion.parse("v1.1.0")!
        XCTAssertTrue(a < b)
        XCTAssertFalse(b < a)
        XCTAssertEqual(AppVersion.parse("1.1.0"), AppVersion.parse("v1.1.0"))
    }

    func testParseSHA256Line() {
        let line = "b6fe7eee626fb014763aec681393dc4077ba41ef291d449d252188929cb6bed1  RenderPausePro-v1.0.1-macOS-arm64.zip\n"
        let hex = AppVersion.parseSHA256Checksum(line)
        XCTAssertEqual(hex, "b6fe7eee626fb014763aec681393dc4077ba41ef291d449d252188929cb6bed1")
    }
}
