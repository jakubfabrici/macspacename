import Foundation

/// One Space (virtual desktop or full-screen app space) as reported by the window server.
public struct SpaceInfo: Identifiable, Hashable, Codable {
    public enum Kind: Hashable, Codable {
        /// A regular user desktop ("Desktop 1", "Desktop 2", ...).
        case desktop
        /// A full-screen or Split View space owned by an application.
        case fullscreen
        /// Anything else macOS may report (reserved types).
        case other(Int)
    }

    /// The window server's managed space ID. Changes across reboots.
    public let id: UInt64
    /// Stable UUID of the space. Desktops keep it across restarts, which is why names are keyed by it.
    public let uuid: String
    public let kind: Kind
    /// PID of the app owning a full-screen space, when macOS reports it.
    public let fullscreenPID: Int32?
    /// `"Main"` when "Displays have separate Spaces" is off, otherwise the display UUID.
    public let displayIdentifier: String
    /// 1-based position of the space on its display, counting full-screen spaces too.
    /// This is the order Control+Arrow steps through.
    public let indexOnDisplay: Int
    /// Global Mission Control desktop number (what "Switch to Desktop N" uses). `nil` for full-screen spaces.
    public let desktopNumber: Int?
    /// Whether this space is the one currently shown on its display.
    public let isCurrentOnDisplay: Bool

    public init(
        id: UInt64,
        uuid: String,
        kind: Kind,
        fullscreenPID: Int32? = nil,
        displayIdentifier: String,
        indexOnDisplay: Int,
        desktopNumber: Int?,
        isCurrentOnDisplay: Bool
    ) {
        self.id = id
        self.uuid = uuid
        self.kind = kind
        self.fullscreenPID = fullscreenPID
        self.displayIdentifier = displayIdentifier
        self.indexOnDisplay = indexOnDisplay
        self.desktopNumber = desktopNumber
        self.isCurrentOnDisplay = isCurrentOnDisplay
    }

    public var isDesktop: Bool { kind == .desktop }
    public var isFullscreen: Bool { kind == .fullscreen }

    /// Key used for persisted per-space data (names, icons, notes...).
    public var key: String { uuid.isEmpty ? "space-\(id)" : uuid }
}

/// The spaces of one display.
public struct DisplaySpaces: Hashable, Codable {
    public let identifier: String
    public let spaces: [SpaceInfo]
    public let currentSpaceID: UInt64?

    public init(identifier: String, spaces: [SpaceInfo], currentSpaceID: UInt64?) {
        self.identifier = identifier
        self.spaces = spaces
        self.currentSpaceID = currentSpaceID
    }

    public var currentSpace: SpaceInfo? {
        spaces.first { $0.id == currentSpaceID } ?? spaces.first { $0.isCurrentOnDisplay }
    }

    public var desktops: [SpaceInfo] { spaces.filter(\.isDesktop) }
}

/// A point-in-time view of every display and its spaces.
public struct SpaceSnapshot: Hashable, Codable {
    public let displays: [DisplaySpaces]
    /// Identifier of the display that currently owns the menu bar (keyboard focus).
    public let activeDisplayIdentifier: String?

    public init(displays: [DisplaySpaces], activeDisplayIdentifier: String?) {
        self.displays = displays
        self.activeDisplayIdentifier = activeDisplayIdentifier
    }

    public static let empty = SpaceSnapshot(displays: [], activeDisplayIdentifier: nil)

    public var allSpaces: [SpaceInfo] { displays.flatMap(\.spaces) }
    public var desktops: [SpaceInfo] { allSpaces.filter(\.isDesktop) }

    public var activeDisplay: DisplaySpaces? {
        if let id = activeDisplayIdentifier, let display = displays.first(where: { $0.identifier == id }) {
            return display
        }
        return displays.first
    }

    /// The space the user is looking at on the active display.
    public var activeSpace: SpaceInfo? { activeDisplay?.currentSpace }

    public func display(for space: SpaceInfo) -> DisplaySpaces? {
        displays.first { $0.identifier == space.displayIdentifier }
    }

    public func space(key: String) -> SpaceInfo? { allSpaces.first { $0.key == key } }
    public func space(id: UInt64) -> SpaceInfo? { allSpaces.first { $0.id == id } }
    public func desktop(number: Int) -> SpaceInfo? { allSpaces.first { $0.desktopNumber == number } }

    /// The space `offset` positions away from `space` on the same display (optionally wrapping around).
    public func neighbor(of space: SpaceInfo, offset: Int, wrap: Bool) -> SpaceInfo? {
        guard let display = display(for: space),
              let index = display.spaces.firstIndex(of: space),
              !display.spaces.isEmpty else { return nil }
        var target = index + offset
        if wrap {
            let count = display.spaces.count
            target = ((target % count) + count) % count
        } else if target < 0 || target >= display.spaces.count {
            return nil
        }
        return display.spaces[target]
    }
}
