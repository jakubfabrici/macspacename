import XCTest
@testable import MacSpaceNameCore

final class SpaceParserTests: XCTestCase {
    func space(_ id: Int, type: Int = 0, uuid: String? = nil, pid: Int? = nil) -> [String: Any] {
        var dict: [String: Any] = [
            "ManagedSpaceID": NSNumber(value: id),
            "id64": NSNumber(value: id),
            "type": NSNumber(value: type),
            "uuid": uuid ?? "UUID-\(id)",
        ]
        if let pid { dict["pid"] = NSNumber(value: pid) }
        return dict
    }

    func testSingleDisplayNumbering() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Current Space": space(2),
            "Spaces": [space(1), space(2), space(7, type: 4, pid: 512), space(3)],
        ]]
        let snapshot = SpaceParser.parse(managedDisplays: raw, activeDisplayIdentifier: "Main")

        XCTAssertEqual(snapshot.displays.count, 1)
        let spaces = snapshot.allSpaces
        XCTAssertEqual(spaces.map(\.desktopNumber), [1, 2, nil, 3])
        XCTAssertEqual(spaces.map(\.indexOnDisplay), [1, 2, 3, 4])
        XCTAssertEqual(spaces[2].kind, .fullscreen)
        XCTAssertEqual(spaces[2].fullscreenPID, 512)
        XCTAssertEqual(snapshot.activeSpace?.id, 2)
        XCTAssertTrue(spaces[1].isCurrentOnDisplay)
        XCTAssertEqual(snapshot.desktops.count, 3)
    }

    func testDisplaysAreNumberedLeftToRight() {
        let raw: [[String: Any]] = [
            ["Display Identifier": "RIGHT", "Current Space": space(10), "Spaces": [space(10), space(11)]],
            ["Display Identifier": "LEFT", "Current Space": space(20), "Spaces": [space(20)]],
        ]
        let bounds: [String: CGRect] = [
            "RIGHT": CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            "LEFT": CGRect(x: 0, y: 0, width: 1920, height: 1080),
        ]
        let snapshot = SpaceParser.parse(managedDisplays: raw, activeDisplayIdentifier: "RIGHT") { bounds[$0] }

        XCTAssertEqual(snapshot.displays.map(\.identifier), ["LEFT", "RIGHT"])
        XCTAssertEqual(snapshot.desktop(number: 1)?.id, 20)
        XCTAssertEqual(snapshot.desktop(number: 2)?.id, 10)
        XCTAssertEqual(snapshot.desktop(number: 3)?.id, 11)
        XCTAssertEqual(snapshot.activeDisplay?.identifier, "RIGHT")
        XCTAssertEqual(snapshot.activeSpace?.id, 10)
    }

    func testUnknownBoundsKeepSystemOrder() {
        let raw: [[String: Any]] = [
            ["Display Identifier": "B", "Spaces": [space(1)]],
            ["Display Identifier": "A", "Spaces": [space(2)]],
        ]
        let snapshot = SpaceParser.parse(managedDisplays: raw, activeDisplayIdentifier: nil) { _ in nil }
        XCTAssertEqual(snapshot.displays.map(\.identifier), ["B", "A"])
        XCTAssertEqual(snapshot.activeDisplay?.identifier, "B")
    }

    func testMalformedEntriesAreSkipped() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Spaces": [["uuid": "no-id"], space(5)],
        ]]
        let snapshot = SpaceParser.parse(managedDisplays: raw, activeDisplayIdentifier: nil)
        XCTAssertEqual(snapshot.allSpaces.map(\.id), [5])
        XCTAssertNil(snapshot.displays[0].currentSpaceID)
    }

    func testNeighborWrapping() {
        let raw: [[String: Any]] = [[
            "Display Identifier": "Main",
            "Current Space": space(1),
            "Spaces": [space(1), space(2), space(3)],
        ]]
        let snapshot = SpaceParser.parse(managedDisplays: raw, activeDisplayIdentifier: "Main")
        let first = snapshot.allSpaces[0]
        XCTAssertEqual(snapshot.neighbor(of: first, offset: 1, wrap: false)?.id, 2)
        XCTAssertNil(snapshot.neighbor(of: first, offset: -1, wrap: false))
        XCTAssertEqual(snapshot.neighbor(of: first, offset: -1, wrap: true)?.id, 3)
        XCTAssertEqual(snapshot.neighbor(of: first, offset: 4, wrap: true)?.id, 2)
    }

    func testKeyFallsBackToIDForEmptyUUID() {
        let info = SpaceInfo(id: 42, uuid: "", kind: .fullscreen, displayIdentifier: "Main", indexOnDisplay: 1, desktopNumber: nil, isCurrentOnDisplay: false)
        XCTAssertEqual(info.key, "space-42")
    }
}
