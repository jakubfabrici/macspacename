import AppKit
import ApplicationServices
import MacSpaceNameCore

/// Moves the front window to another space using only public mechanisms:
/// grab the window's title bar with a synthetic mouse-down, switch spaces (macOS carries a dragged window
/// along), then release. Experimental; needs the Accessibility permission.
@MainActor
final class WindowMover {
    private let spaces: SpaceService
    private var busy = false

    init(spaces: SpaceService) {
        self.spaces = spaces
    }

    func moveFrontWindow(to target: SpaceInfo) {
        guard !busy, Accessibility.ensureTrusted(prompt: true) else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        if target.isCurrentOnDisplay, target.displayIdentifier == spaces.activeSpace?.displayIdentifier { return }

        let application = AXUIElementCreateApplication(frontApp.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.5)
        guard let window = AXHelper.element(application, kAXFocusedWindowAttribute)
                ?? AXHelper.elements(application, kAXWindowsAttribute).first,
              let frame = AXHelper.frame(window), frame.width > 40, frame.height > 20,
              let originalLocation = CGEvent(source: nil)?.location else { return }

        busy = true
        let grab = CGPoint(x: frame.midX, y: frame.minY + 12)
        let drag1 = CGPoint(x: grab.x + 4, y: grab.y + 3)
        let drag2 = CGPoint(x: grab.x + 9, y: grab.y + 6)

        let steps: Int
        if let active = spaces.activeSpace, active.displayIdentifier == target.displayIdentifier {
            steps = max(1, abs(target.indexOnDisplay - active.indexOnDisplay))
        } else {
            steps = 1
        }
        let settleDelay = 0.7 + 0.2 * Double(steps - 1)

        WindowMover.postMouse(.mouseMoved, at: grab)
        WindowMover.postMouse(.leftMouseDown, at: grab)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { WindowMover.postMouse(.leftMouseDragged, at: drag1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { WindowMover.postMouse(.leftMouseDragged, at: drag2) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.spaces.switchTo(target)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + settleDelay) { [weak self] in
            WindowMover.postMouse(.leftMouseDragged, at: drag2)
            WindowMover.postMouse(.leftMouseUp, at: drag2)
            CGWarpMouseCursorPosition(originalLocation)
            self?.busy = false
        }
    }

    private static func postMouse(_ type: CGEventType, at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
