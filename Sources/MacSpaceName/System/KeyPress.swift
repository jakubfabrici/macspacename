import CoreGraphics

/// Posts synthetic key presses at the HID level (needs the Accessibility permission).
enum KeyPress {
    static func post(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Virtual key codes of the digit keys on a US layout (used only as a fallback).
    static func digitKeyCode(_ digit: Int) -> UInt16? {
        switch digit {
        case 1: return 18
        case 2: return 19
        case 3: return 20
        case 4: return 21
        case 5: return 23
        case 6: return 22
        case 7: return 26
        case 8: return 28
        case 9: return 25
        case 0: return 29
        default: return nil
        }
    }

    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
}
