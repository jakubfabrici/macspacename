import XCTest
@testable import MacSpaceNameCore

final class SpaceMatcherTests: XCTestCase {
    func testRankingOrder() {
        let exact = SpaceMatcher.score(query: "work", candidate: "Work")!
        let prefix = SpaceMatcher.score(query: "wor", candidate: "Workspace")!
        let wordPrefix = SpaceMatcher.score(query: "wor", candidate: "Deep Work")!
        let substring = SpaceMatcher.score(query: "ork", candidate: "Network")!
        let fuzzy = SpaceMatcher.score(query: "wk", candidate: "Work")!

        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, wordPrefix)
        XCTAssertGreaterThan(wordPrefix, substring)
        XCTAssertGreaterThan(substring, fuzzy)
    }

    func testNoMatch() {
        XCTAssertNil(SpaceMatcher.score(query: "xyz", candidate: "Work"))
        XCTAssertNil(SpaceMatcher.score(query: "a", candidate: ""))
    }

    func testEmptyQueryMatchesEverything() {
        XCTAssertEqual(SpaceMatcher.score(query: "", candidate: "Anything"), 0)
        XCTAssertEqual(SpaceMatcher.score(query: "   ", candidate: "Anything"), 0)
    }

    func testDiacriticsAndCaseAreIgnored() {
        XCTAssertEqual(SpaceMatcher.score(query: "praca", candidate: "Práca"), 1000)
        XCTAssertEqual(SpaceMatcher.score(query: "PRÁ", candidate: "praca")!, 800 - 2)
    }

    func testCompactFuzzyMatchesScoreHigher() {
        let compact = SpaceMatcher.score(query: "dsg", candidate: "Design")!
        let spread = SpaceMatcher.score(query: "dsg", candidate: "Dashboard sign")!
        XCTAssertGreaterThan(compact, spread)
    }
}
