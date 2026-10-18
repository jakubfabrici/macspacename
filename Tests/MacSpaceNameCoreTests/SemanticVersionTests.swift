import XCTest
@testable import MacSpaceNameCore

final class SemanticVersionTests: XCTestCase {
    func v(_ s: String) -> SemanticVersion { SemanticVersion(s)! }

    func testParsing() {
        XCTAssertEqual(v("v0.1.0-beta.1"), SemanticVersion(major: 0, minor: 1, patch: 0, prerelease: ["beta", "1"]))
        XCTAssertEqual(v("1.2"), SemanticVersion(major: 1, minor: 2, patch: 0))
        XCTAssertEqual(v("2.0.1+build.7").description, "2.0.1")
        XCTAssertNil(SemanticVersion("abc"))
        XCTAssertNil(SemanticVersion("1.2.3.4"))
        XCTAssertNil(SemanticVersion("1.-2.0"))
        XCTAssertNil(SemanticVersion("1.0.0-"))
        XCTAssertEqual(v("0.1.0-beta.2").description, "0.1.0-beta.2")
    }

    func testPrecedence() {
        XCTAssertLessThan(v("0.1.0-beta.1"), v("0.1.0"))
        XCTAssertLessThan(v("0.1.0-beta.1"), v("0.1.0-beta.2"))
        XCTAssertLessThan(v("0.1.0-beta.9"), v("0.1.0-beta.10"))
        XCTAssertLessThan(v("0.1.0-alpha"), v("0.1.0-beta"))
        XCTAssertLessThan(v("0.1.0-beta"), v("0.1.0-beta.1"))
        XCTAssertLessThan(v("0.1.9"), v("0.2.0"))
        XCTAssertLessThan(v("0.9.9"), v("1.0.0"))
        XCTAssertLessThan(v("1.0.0-rc.1"), v("1.0.0"))
        XCTAssertFalse(v("1.0.0") < v("1.0.0"))
        XCTAssertEqual(v("1.0.0"), v("v1.0.0"))
        XCTAssertTrue(v("1.0.0-beta.1").isPrerelease)
        XCTAssertFalse(v("1.0.0").isPrerelease)
    }
}
