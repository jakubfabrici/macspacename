import Foundation
import CoreGraphics

/// Turns the dictionaries returned by the private `CGSCopyManagedDisplaySpaces` call into `SpaceSnapshot`.
///
/// The raw structure looks like this (one entry per display):
///
/// ```
/// {
///   "Display Identifier": "Main" | "<display UUID>",
///   "Current Space": { "ManagedSpaceID": 4, "id64": 4, "type": 0, "uuid": "..." },
///   "Spaces": [
///     { "ManagedSpaceID": 4, "id64": 4, "type": 0, "uuid": "..." },          // desktop
///     { "ManagedSpaceID": 9, "id64": 9, "type": 4, "uuid": "...", "pid": 512 } // full-screen app
///   ]
/// }
/// ```
public enum SpaceParser {
    public static let desktopType = 0
    public static let fullscreenType = 4

    /// - Parameters:
    ///   - managedDisplays: raw dictionaries from the window server.
    ///   - activeDisplayIdentifier: identifier of the display with the menu bar focus.
    ///   - displayBounds: resolves a display identifier to its global bounds; used to number desktops
    ///     left-to-right like Mission Control does. Return `nil` when unknown.
    public static func parse(
        managedDisplays: [[String: Any]],
        activeDisplayIdentifier: String?,
        displayBounds: (String) -> CGRect? = { _ in nil }
    ) -> SpaceSnapshot {
        var ordered = Array(managedDisplays.enumerated())
        let bounds = managedDisplays.map { displayBounds(identifier(of: $0)) }
        if bounds.count > 1, bounds.allSatisfy({ $0 != nil }) {
            ordered.sort { lhs, rhs in
                let a = bounds[lhs.offset]!, b = bounds[rhs.offset]!
                if a.minX != b.minX { return a.minX < b.minX }
                return a.minY < b.minY
            }
        }

        var desktopNumber = 0
        var displays: [DisplaySpaces] = []
        for (_, dict) in ordered {
            let identifier = identifier(of: dict)
            let currentID = (dict["Current Space"] as? [String: Any]).flatMap(spaceID(of:))
            let rawSpaces = dict["Spaces"] as? [[String: Any]] ?? []
            var spaces: [SpaceInfo] = []
            for (index, raw) in rawSpaces.enumerated() {
                guard let id = spaceID(of: raw) else { continue }
                let type = int(raw["type"]) ?? desktopType
                let kind: SpaceInfo.Kind
                switch type {
                case desktopType: kind = .desktop
                case fullscreenType: kind = .fullscreen
                default: kind = .other(type)
                }
                var number: Int?
                if kind == .desktop {
                    desktopNumber += 1
                    number = desktopNumber
                }
                let pid = int(raw["pid"]).flatMap { Int32(exactly: $0) }
                spaces.append(SpaceInfo(
                    id: id,
                    uuid: raw["uuid"] as? String ?? "",
                    kind: kind,
                    fullscreenPID: pid,
                    displayIdentifier: identifier,
                    indexOnDisplay: index + 1,
                    desktopNumber: number,
                    isCurrentOnDisplay: currentID != nil && id == currentID
                ))
            }
            displays.append(DisplaySpaces(identifier: identifier, spaces: spaces, currentSpaceID: currentID))
        }
        return SpaceSnapshot(displays: displays, activeDisplayIdentifier: activeDisplayIdentifier)
    }

    static func identifier(of display: [String: Any]) -> String {
        display["Display Identifier"] as? String ?? "Main"
    }

    static func spaceID(of space: [String: Any]) -> UInt64? {
        uint64(space["ManagedSpaceID"]) ?? uint64(space["id64"])
    }

    static func uint64(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber { return number.uint64Value }
        if let int = value as? Int, int >= 0 { return UInt64(int) }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return value as? Int
    }
}
