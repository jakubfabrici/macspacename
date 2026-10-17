import XCTest
@testable import MacSpaceNameCore

final class TimeLogTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(_ string: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: string)!
    }

    func testTodayTotalsClipEntriesAtMidnight() {
        let now = date("2026-10-17T12:00:00Z")
        let entries = [
            // 23:30 yesterday -> 00:30 today: only 30 minutes count for today
            TimeEntry(spaceKey: "a", spaceName: "Work", start: date("2026-10-16T23:30:00Z"), end: date("2026-10-17T00:30:00Z")),
            TimeEntry(spaceKey: "a", spaceName: "Work", start: date("2026-10-17T09:00:00Z"), end: date("2026-10-17T10:00:00Z")),
            TimeEntry(spaceKey: "b", spaceName: "Home", start: date("2026-10-17T10:00:00Z"), end: date("2026-10-17T10:15:00Z")),
        ]
        let totals = TimeAggregator.totals(entries, by: .space, in: .today, now: now, calendar: calendar)
        XCTAssertEqual(totals.map(\.key), ["a", "b"])
        XCTAssertEqual(totals[0].seconds, 90 * 60)
        XCTAssertEqual(totals[0].label, "Work")
        XCTAssertEqual(totals[1].seconds, 15 * 60)
        XCTAssertEqual(TimeAggregator.total(entries, in: .all, now: now, calendar: calendar), 135 * 60)
    }

    func testAppGroupingUsesBundleID() {
        let entries = [
            TimeEntry(spaceKey: "a", spaceName: "Work", appBundleID: "com.apple.Safari", appName: "Safari", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60)),
            TimeEntry(spaceKey: "b", spaceName: "Home", appBundleID: "com.apple.Safari", appName: "Safari", start: Date(timeIntervalSince1970: 60), end: Date(timeIntervalSince1970: 180)),
        ]
        let totals = TimeAggregator.totals(entries, by: .app, in: .all)
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].key, "com.apple.Safari")
        XCTAssertEqual(totals[0].seconds, 180)
    }

    func testFormat() {
        XCTAssertEqual(TimeAggregator.format(0), "0m")
        XCTAssertEqual(TimeAggregator.format(30), "<1m")
        XCTAssertEqual(TimeAggregator.format(45 * 60), "45m")
        XCTAssertEqual(TimeAggregator.format(2 * 3600 + 5 * 60), "2h 05m")
    }

    func testCSVEscaping() {
        let entry = TimeEntry(
            spaceKey: "k",
            spaceName: "Client, \"Acme\"",
            appBundleID: "com.example",
            appName: "Line\nBreak",
            session: nil,
            start: date("2026-10-17T09:00:00Z"),
            end: date("2026-10-17T09:30:00Z")
        )
        let csv = CSVExporter.csv(for: [entry])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines[0], Substring(CSVExporter.header))
        XCTAssertTrue(csv.contains("\"Client, \"\"Acme\"\"\""))
        XCTAssertTrue(csv.contains("\"Line\nBreak\""))
        XCTAssertTrue(csv.contains(",1800,"))
        XCTAssertTrue(csv.hasSuffix("\n"))
    }
}
