import AppKit
import CoreGraphics

/// Maps the window server's display identifiers ("Main" or a UUID) to screens and back.
enum DisplayInfo {
    static func displayID(forIdentifier identifier: String) -> CGDirectDisplayID? {
        if identifier == "Main" { return CGMainDisplayID() }
        guard let uuid = CFUUIDCreateFromString(nil, identifier as CFString) else { return nil }
        let id = CGDisplayGetDisplayIDFromUUID(uuid)
        return id == kCGNullDirectDisplay ? nil : id
    }

    static func bounds(forIdentifier identifier: String) -> CGRect? {
        displayID(forIdentifier: identifier).map { CGDisplayBounds($0) }
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static func screen(forIdentifier identifier: String) -> NSScreen? {
        guard let id = displayID(forIdentifier: identifier) else { return nil }
        return NSScreen.screens.first { displayID(of: $0) == id }
    }

    /// The UUID string the window server uses for `screen`.
    static func identifier(for screen: NSScreen) -> String? {
        guard let id = displayID(of: screen),
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) else { return nil }
        return string as String
    }

    static func name(forIdentifier identifier: String) -> String {
        if let screen = screen(forIdentifier: identifier) { return screen.localizedName }
        return identifier == "Main" ? "Main Display" : "Display"
    }

    /// Converts a rectangle in Quartz coordinates (origin top-left of the main display, y down)
    /// into AppKit coordinates (origin bottom-left of the main display, y up).
    static func cocoaRect(fromQuartz rect: CGRect) -> NSRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? CGFloat(CGDisplayPixelsHigh(CGMainDisplayID()))
        return NSRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func quartzRect(fromCocoa rect: NSRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? CGFloat(CGDisplayPixelsHigh(CGMainDisplayID()))
        return CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}
