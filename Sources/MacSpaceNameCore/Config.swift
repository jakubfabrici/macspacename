import Foundation
import Combine

public struct ChecklistItem: Codable, Identifiable, Hashable {
    public var id: UUID
    public var text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String, isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

/// What a single automation step does.
public enum ActionKind: String, Codable, CaseIterable, Hashable {
    case openApp
    case openPath
    case openURL
    case runShortcut
    case runShell

    public var title: String {
        switch self {
        case .openApp: return "Open app"
        case .openPath: return "Open file or folder"
        case .openURL: return "Open URL"
        case .runShortcut: return "Run Apple Shortcut"
        case .runShell: return "Run shell command"
        }
    }

    public var placeholder: String {
        switch self {
        case .openApp: return "Safari or /Applications/Safari.app"
        case .openPath: return "~/Projects/my-project"
        case .openURL: return "https://example.com"
        case .runShortcut: return "Name of the Shortcut"
        case .runShell: return "say \"hello\""
        }
    }
}

public struct ActionItem: Codable, Identifiable, Hashable {
    public var id: UUID
    public var kind: ActionKind
    public var value: String

    public init(id: UUID = UUID(), kind: ActionKind = .openApp, value: String = "") {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

/// A named group of actions ("On Click" group) that can be run from the menu bar or when entering a space.
public struct ActionGroup: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var items: [ActionItem]

    public init(id: UUID = UUID(), name: String, items: [ActionItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

/// Everything the user attaches to one space. Keyed by `SpaceInfo.key`.
public struct SpaceConfig: Codable, Hashable {
    public var name: String?
    /// An emoji (or any short text) or an SF Symbol name.
    public var icon: String?
    /// Hex color like `#FF8800`.
    public var color: String?
    public var notes: String
    public var checklist: [ChecklistItem]
    /// Action group to run automatically when the space becomes active.
    public var onEnterGroupID: UUID?

    public init(
        name: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        notes: String = "",
        checklist: [ChecklistItem] = [],
        onEnterGroupID: UUID? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.notes = notes
        self.checklist = checklist
        self.onEnterGroupID = onEnterGroupID
    }

    enum CodingKeys: String, CodingKey { case name, icon, color, notes, checklist, onEnterGroupID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        checklist = try c.decodeIfPresent([ChecklistItem].self, forKey: .checklist) ?? []
        onEnterGroupID = try c.decodeIfPresent(UUID.self, forKey: .onEnterGroupID)
    }

    /// True when nothing is customised, so the entry can be dropped.
    public var isEmpty: Bool {
        (name ?? "").isEmpty && (icon ?? "").isEmpty && (color ?? "").isEmpty
            && notes.isEmpty && checklist.isEmpty && onEnterGroupID == nil
    }
}

public enum MenuBarStyle: String, Codable, CaseIterable, Hashable {
    case iconAndName
    case nameOnly
    case iconOnly
    case numberAndName

    public var title: String {
        switch self {
        case .iconAndName: return "Icon and name"
        case .nameOnly: return "Name only"
        case .iconOnly: return "Icon only"
        case .numberAndName: return "Number and name"
        }
    }
}

public enum SwitchMethod: String, Codable, CaseIterable, Hashable {
    /// Use "Switch to Desktop N" shortcuts when possible, step with Control+Arrow otherwise.
    case automatic
    /// Always step with Control+Arrow (slower, but works for every space type).
    case stepOnly

    public var title: String {
        switch self {
        case .automatic: return "Direct (Switch to Desktop N)"
        case .stepOnly: return "Step with Control + Arrow keys"
        }
    }
}

public struct AppSettings: Codable, Hashable {
    public var menuBarStyle: MenuBarStyle = .iconAndName
    public var showNumbersInMenu: Bool = true
    public var switchMethod: SwitchMethod = .automatic
    public var missionControlLabels: Bool = true
    public var hoverBar: Bool = true
    public var dragToMove: Bool = true
    public var timeTracking: Bool = true
    public var idleMinutes: Int = 5
    public var showFullscreenSpaces: Bool = true

    public init() {}

    enum CodingKeys: String, CodingKey {
        case menuBarStyle, showNumbersInMenu, switchMethod, missionControlLabels, hoverBar, dragToMove,
             timeTracking, idleMinutes, showFullscreenSpaces
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        menuBarStyle = try c.decodeIfPresent(MenuBarStyle.self, forKey: .menuBarStyle) ?? defaults.menuBarStyle
        showNumbersInMenu = try c.decodeIfPresent(Bool.self, forKey: .showNumbersInMenu) ?? defaults.showNumbersInMenu
        switchMethod = try c.decodeIfPresent(SwitchMethod.self, forKey: .switchMethod) ?? defaults.switchMethod
        missionControlLabels = try c.decodeIfPresent(Bool.self, forKey: .missionControlLabels) ?? defaults.missionControlLabels
        hoverBar = try c.decodeIfPresent(Bool.self, forKey: .hoverBar) ?? defaults.hoverBar
        dragToMove = try c.decodeIfPresent(Bool.self, forKey: .dragToMove) ?? defaults.dragToMove
        timeTracking = try c.decodeIfPresent(Bool.self, forKey: .timeTracking) ?? defaults.timeTracking
        idleMinutes = try c.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? defaults.idleMinutes
        showFullscreenSpaces = try c.decodeIfPresent(Bool.self, forKey: .showFullscreenSpaces) ?? defaults.showFullscreenSpaces
    }
}

/// The whole persisted configuration (one JSON file).
public struct AppConfig: Codable, Hashable {
    public static let currentVersion = 1

    public var version: Int = AppConfig.currentVersion
    public var spaces: [String: SpaceConfig] = [:]
    public var actionGroups: [ActionGroup] = []
    public var settings = AppSettings()

    public init() {}

    enum CodingKeys: String, CodingKey { case version, spaces, actionGroups, settings }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? AppConfig.currentVersion
        spaces = try c.decodeIfPresent([String: SpaceConfig].self, forKey: .spaces) ?? [:]
        actionGroups = try c.decodeIfPresent([ActionGroup].self, forKey: .actionGroups) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }

    public func group(id: UUID?) -> ActionGroup? {
        guard let id else { return nil }
        return actionGroups.first { $0.id == id }
    }
}

/// Loads and saves `AppConfig` as pretty-printed JSON. Saving is debounced.
public final class ConfigStore: ObservableObject {
    @Published public var config: AppConfig {
        didSet { if config != oldValue { scheduleSave() } }
    }

    public let fileURL: URL
    public private(set) var lastError: Error?
    private var pendingSave: DispatchWorkItem?

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.config = (try? ConfigStore.read(from: fileURL)) ?? AppConfig()
    }

    /// `~/Library/Application Support/MacSpaceName/config.json`
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("MacSpaceName", isDirectory: true).appendingPathComponent("config.json")
    }

    public static func read(from url: URL) throws -> AppConfig {
        let data = try Data(contentsOf: url)
        return try decoder.decode(AppConfig.self, from: data)
    }

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public func spaceConfig(for key: String) -> SpaceConfig {
        config.spaces[key] ?? SpaceConfig()
    }

    public func update(_ key: String, _ body: (inout SpaceConfig) -> Void) {
        var entry = spaceConfig(for: key)
        body(&entry)
        if entry.isEmpty {
            config.spaces.removeValue(forKey: key)
        } else {
            config.spaces[key] = entry
        }
    }

    public func customName(for key: String) -> String? {
        let name = config.spaces[key]?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    public func save() throws {
        pendingSave?.cancel()
        pendingSave = nil
        let data = try ConfigStore.encoder.encode(config)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    public func exportData() throws -> Data {
        try ConfigStore.encoder.encode(config)
    }

    public func importData(_ data: Data) throws {
        config = try ConfigStore.decoder.decode(AppConfig.self, from: data)
        try save()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do { try self.save() } catch { self.lastError = error }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
