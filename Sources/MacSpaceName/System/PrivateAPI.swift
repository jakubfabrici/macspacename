import Foundation
import CoreGraphics

/// Thin, runtime-resolved bridge to the private window server (CGS / SkyLight) functions this app needs.
///
/// Every symbol is looked up with `dlsym` at first use. If Apple removes one, the related feature
/// degrades instead of the app failing to launch. See docs/how-it-works.md for what each call does.
enum PrivateAPI {
    typealias ConnectionID = Int32

    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyActiveMenuBarDisplayFn = @convention(c) (Int32) -> Unmanaged<CFString>?
    private typealias GetSymbolicHotKeyValueFn = @convention(c) (
        Int32, UnsafeMutablePointer<UInt16>?, UnsafeMutablePointer<UInt16>?, UnsafeMutablePointer<UInt32>?
    ) -> Int32
    private typealias IsSymbolicHotKeyEnabledFn = @convention(c) (Int32) -> Bool
    private typealias SetSymbolicHotKeyEnabledFn = @convention(c) (Int32, Bool) -> Int32

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle = UnsafeMutableRawPointer(bitPattern: -2), // RTLD_DEFAULT
              let address = dlsym(handle, name) else { return nil }
        return unsafeBitCast(address, to: type)
    }

    private static let mainConnection = symbol("CGSMainConnectionID", as: MainConnectionFn.self)
        ?? symbol("_CGSDefaultConnection", as: MainConnectionFn.self)
    private static let copyManagedDisplaySpaces = symbol("CGSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpacesFn.self)
    private static let copyActiveMenuBarDisplay = symbol("CGSCopyActiveMenuBarDisplayIdentifier", as: CopyActiveMenuBarDisplayFn.self)
    private static let getSymbolicHotKeyValue = symbol("CGSGetSymbolicHotKeyValue", as: GetSymbolicHotKeyValueFn.self)
    private static let isSymbolicHotKeyEnabledFn = symbol("CGSIsSymbolicHotKeyEnabled", as: IsSymbolicHotKeyEnabledFn.self)
    private static let setSymbolicHotKeyEnabledFn = symbol("CGSSetSymbolicHotKeyEnabled", as: SetSymbolicHotKeyEnabledFn.self)

    /// Whether the calls needed to list spaces are available on this system.
    static var isAvailable: Bool { mainConnection != nil && copyManagedDisplaySpaces != nil }

    static var connectionID: ConnectionID? { mainConnection?() }

    /// Raw per-display dictionaries describing every space. See `SpaceParser`.
    static func managedDisplaySpaces() -> [[String: Any]] {
        guard let cid = connectionID, let fn = copyManagedDisplaySpaces,
              let array = fn(cid)?.takeRetainedValue() else { return [] }
        return (array as NSArray) as? [[String: Any]] ?? []
    }

    /// Identifier of the display whose menu bar is active ("Main" or a display UUID).
    static func activeMenuBarDisplayIdentifier() -> String? {
        guard let cid = connectionID, let fn = copyActiveMenuBarDisplay,
              let string = fn(cid)?.takeRetainedValue() else { return nil }
        return string as String
    }

    // MARK: - Symbolic hot keys (System Settings > Keyboard > Shortcuts > Mission Control)

    struct HotKeyValue {
        let keyCode: UInt16
        let modifiers: UInt32
    }

    static func symbolicHotKeyValue(_ id: Int32) -> HotKeyValue? {
        guard let fn = getSymbolicHotKeyValue else { return nil }
        var keyEquivalent: UInt16 = 0
        var keyCode: UInt16 = 0
        var modifiers: UInt32 = 0
        guard fn(id, &keyEquivalent, &keyCode, &modifiers) == 0 else { return nil }
        return HotKeyValue(keyCode: keyCode, modifiers: modifiers)
    }

    static func isSymbolicHotKeyEnabled(_ id: Int32) -> Bool? {
        isSymbolicHotKeyEnabledFn?(id)
    }

    @discardableResult
    static func setSymbolicHotKeyEnabled(_ id: Int32, _ enabled: Bool) -> Bool {
        guard let fn = setSymbolicHotKeyEnabledFn else { return false }
        return fn(id, enabled) == 0
    }
}

/// IDs of the Mission Control shortcuts in `com.apple.symbolichotkeys`.
enum SymbolicHotKey {
    /// "Move left a space" (Control + Left Arrow)
    static let moveLeft: Int32 = 79
    /// "Move right a space" (Control + Right Arrow)
    static let moveRight: Int32 = 81
    /// "Switch to Desktop 1"; desktops 2–16 follow consecutively.
    static let desktop1: Int32 = 118
    static let maxDesktop = 16

    static func desktop(_ number: Int) -> Int32? {
        guard (1...maxDesktop).contains(number) else { return nil }
        return desktop1 + Int32(number - 1)
    }
}
