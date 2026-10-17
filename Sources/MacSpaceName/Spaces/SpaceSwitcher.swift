import AppKit
import MacSpaceNameCore

/// Switches spaces by triggering the system's own Mission Control shortcuts.
///
/// macOS has no public API for switching spaces. The reliable way is to do what the user would do:
/// press "Switch to Desktop N" or "Move left/right a space". Those shortcuts are disabled by default,
/// so we read their key binding from the window server, enable them for a moment, press, and restore.
@MainActor
final class SpaceSwitcher {
    var method: SwitchMethod = .automatic
    var ensureAccessibility: () -> Bool = { Accessibility.ensureTrusted(prompt: true) }

    private var pendingSteps: [Int32] = []
    private var stepTimer: Timer?

    func switchTo(_ target: SpaceInfo, in snapshot: SpaceSnapshot) {
        guard let display = snapshot.display(for: target) else { return }
        if display.currentSpaceID == target.id { return }

        // Full-screen spaces: activating the app that owns it brings its space forward.
        if target.isFullscreen, let pid = target.fullscreenPID,
           let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
            return
        }

        guard ensureAccessibility() else { return }

        if method == .automatic, let number = target.desktopNumber, SymbolicHotKey.desktop(number) != nil {
            switchToDesktop(number: number)
            return
        }

        if let current = display.currentSpace {
            step(by: target.indexOnDisplay - current.indexOnDisplay)
        } else if let number = target.desktopNumber {
            switchToDesktop(number: number)
        }
    }

    /// Presses "Switch to Desktop N".
    func switchToDesktop(number: Int) {
        guard let id = SymbolicHotKey.desktop(number), ensureAccessibility() else { return }
        let fallback = KeyPress.digitKeyCode(number % 10).map { (keyCode: $0, flags: CGEventFlags.maskControl) }
        press(symbolicHotKey: id, fallback: number <= 10 ? fallback : nil)
    }

    /// Presses "Move left/right a space" `abs(delta)` times.
    func step(by delta: Int) {
        guard delta != 0, ensureAccessibility() else { return }
        let id = delta < 0 ? SymbolicHotKey.moveLeft : SymbolicHotKey.moveRight
        pendingSteps.append(contentsOf: Array(repeating: id, count: abs(delta)))
        if stepTimer == nil { fireNextStep() }
    }

    private func fireNextStep() {
        guard !pendingSteps.isEmpty else {
            stepTimer = nil
            return
        }
        let id = pendingSteps.removeFirst()
        let arrow = id == SymbolicHotKey.moveLeft ? KeyPress.leftArrow : KeyPress.rightArrow
        press(symbolicHotKey: id, fallback: (keyCode: arrow, flags: .maskControl))
        stepTimer = Timer.scheduledTimer(timeInterval: 0.18, target: self, selector: #selector(stepTick), userInfo: nil, repeats: false)
    }

    @objc private func stepTick() {
        stepTimer = nil
        fireNextStep()
    }

    private func press(symbolicHotKey id: Int32, fallback: (keyCode: UInt16, flags: CGEventFlags)?) {
        let keyCode: UInt16
        let flags: CGEventFlags
        if let value = PrivateAPI.symbolicHotKeyValue(id) {
            keyCode = value.keyCode
            flags = CGEventFlags(rawValue: UInt64(value.modifiers))
        } else if let fallback {
            keyCode = fallback.keyCode
            flags = fallback.flags
        } else {
            return
        }

        let wasEnabled = PrivateAPI.isSymbolicHotKeyEnabled(id) ?? true
        if !wasEnabled { PrivateAPI.setSymbolicHotKeyEnabled(id, true) }
        KeyPress.post(keyCode: keyCode, flags: flags)
        if !wasEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                PrivateAPI.setSymbolicHotKeyEnabled(id, false)
            }
        }
    }
}
