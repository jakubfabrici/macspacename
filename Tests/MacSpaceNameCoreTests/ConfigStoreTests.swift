import XCTest
@testable import MacSpaceNameCore

final class ConfigStoreTests: XCTestCase {
    func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("macspacename-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    func testRoundTrip() throws {
        let url = temporaryFile()
        let store = ConfigStore(fileURL: url)
        store.update("uuid-1") { $0.name = "Work"; $0.icon = "💼"; $0.color = "#FF8800" }
        store.config.actionGroups = [ActionGroup(name: "Setup", items: [ActionItem(kind: .openApp, value: "Safari")])]
        store.config.settings.idleMinutes = 9
        try store.save()

        let reloaded = ConfigStore(fileURL: url)
        XCTAssertEqual(reloaded.config, store.config)
        XCTAssertEqual(reloaded.customName(for: "uuid-1"), "Work")
        XCTAssertEqual(reloaded.config.settings.idleMinutes, 9)
        XCTAssertEqual(reloaded.config.actionGroups.first?.items.first?.kind, .openApp)
    }

    func testEmptyEntriesAreRemoved() {
        let store = ConfigStore(fileURL: temporaryFile())
        store.update("uuid-1") { $0.name = "Work" }
        XCTAssertNotNil(store.config.spaces["uuid-1"])
        store.update("uuid-1") { $0.name = "" }
        XCTAssertNil(store.config.spaces["uuid-1"])
        XCTAssertNil(store.customName(for: "uuid-1"))
    }

    func testDecodingToleratesMissingKeys() throws {
        let json = """
        {"spaces": {"abc": {"name": "Focus"}}, "settings": {"hoverBar": false}}
        """
        let config = try ConfigStore.decoder.decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.version, AppConfig.currentVersion)
        XCTAssertEqual(config.spaces["abc"]?.name, "Focus")
        XCTAssertEqual(config.spaces["abc"]?.notes, "")
        XCTAssertFalse(config.settings.hoverBar)
        XCTAssertTrue(config.settings.timeTracking)
        XCTAssertEqual(config.settings.idleMinutes, 5)
    }

    func testImportReplacesConfig() throws {
        let store = ConfigStore(fileURL: temporaryFile())
        store.update("x") { $0.name = "Old" }
        let json = Data("""
        {"version": 1, "spaces": {"y": {"name": "New"}}, "actionGroups": [], "settings": {}}
        """.utf8)
        try store.importData(json)
        XCTAssertNil(store.config.spaces["x"])
        XCTAssertEqual(store.config.spaces["y"]?.name, "New")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
