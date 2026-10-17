import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let quickSwitcher = Self("quickSwitcher", default: .init(.space, modifiers: [.option]))
    static let moveWindowSwitcher = Self("moveWindowSwitcher")
    static let jumpBack = Self("jumpBack")
    static let nextSpace = Self("nextSpace")
    static let previousSpace = Self("previousSpace")
    static let renameCurrentSpace = Self("renameCurrentSpace")
    static let toggleTracking = Self("toggleTracking")

    /// Per-space "jump straight to this space" shortcut.
    static func space(_ key: String) -> Self { Self("space.\(key)") }
}

/// Registers global keyboard shortcuts. Shortcuts themselves are recorded in Settings and stored by KeyboardShortcuts.
@MainActor
final class HotkeyManager {
    private weak var app: AppContainer!

    func attach(to app: AppContainer) {
        self.app = app
    }

    /// (Re)registers every handler. Called at launch and whenever the set of spaces changes.
    func registerAll() {
        KeyboardShortcuts.removeAllHandlers()

        KeyboardShortcuts.onKeyDown(for: .quickSwitcher) { [weak self] in
            self?.app.quickSwitcher.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .moveWindowSwitcher) { [weak self] in
            self?.app.quickSwitcher.show(moveWindow: true)
        }
        KeyboardShortcuts.onKeyDown(for: .jumpBack) { [weak self] in
            self?.app.spaces.jumpBack()
        }
        KeyboardShortcuts.onKeyDown(for: .nextSpace) { [weak self] in
            self?.app.spaces.switchRelative(1)
        }
        KeyboardShortcuts.onKeyDown(for: .previousSpace) { [weak self] in
            self?.app.spaces.switchRelative(-1)
        }
        KeyboardShortcuts.onKeyDown(for: .renameCurrentSpace) { [weak self] in
            self?.app.renamePrompt()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleTracking) { [weak self] in
            self?.app.tracker.isPaused.toggle()
        }

        for space in app.spaces.snapshot.desktops {
            let key = space.key
            KeyboardShortcuts.onKeyDown(for: .space(key)) { [weak self] in
                self?.app.spaces.switchTo(key: key)
            }
        }
    }
}
