import AppKit
import Combine
import KeyboardShortcuts
import MacSpaceNameCore

/// The menu bar item: shows the current space and hosts the main menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private weak var app: AppContainer!
    private var cancellables = Set<AnyCancellable>()

    func attach(to app: AppContainer) {
        self.app = app
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        app.spaces.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateButton() } }
            .store(in: &cancellables)
        app.tracker.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateButton() } }
            .store(in: &cancellables)
        updateButton()
    }

    // MARK: - Button

    func updateButton() {
        guard let button = statusItem?.button else { return }
        let style = app.config.config.settings.menuBarStyle
        guard let active = app.spaces.activeSpace else {
            button.image = nil
            button.imagePosition = .noImage
            button.title = app.spaces.isAvailable ? "Spaces" : "⚠︎ Spaces"
            button.toolTip = app.spaces.isAvailable ? "MacSpaceName" : "The private Spaces API is not available on this macOS."
            return
        }

        let name = app.spaces.name(for: active)
        let icon = app.spaces.icon(for: active)
        let color = app.spaces.color(for: active)

        var text: String
        var showIcon: Bool
        switch style {
        case .iconAndName:
            text = name
            showIcon = true
        case .nameOnly:
            text = name
            showIcon = false
        case .iconOnly:
            text = icon == nil ? name : ""
            showIcon = true
        case .numberAndName:
            text = active.desktopNumber.map { "\($0) · \(name)" } ?? name
            showIcon = true
        }

        var image: NSImage?
        var prefix = ""
        if showIcon, let icon {
            switch icon {
            case .symbol:
                image = icon.nsImage(color: color, pointSize: 13)
            case .text(let value):
                prefix = value
            }
        }
        if !prefix.isEmpty {
            text = text.isEmpty ? prefix : "\(prefix) \(text)"
        }

        let title = NSMutableAttributedString()
        if image == nil, prefix.isEmpty, let color, !text.isEmpty {
            // No icon: show a small colored dot in front of the name.
            title.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: color, .font: NSFont.menuBarFont(ofSize: 0)]))
        }
        title.append(NSAttributedString(string: text, attributes: [.font: NSFont.menuBarFont(ofSize: 0)]))

        button.image = image
        button.imagePosition = image == nil ? .noImage : (text.isEmpty ? .imageOnly : .imageLeading)
        button.attributedTitle = title
        var tooltip = "\(name) — \(app.spaces.subtitle(for: active))"
        if app.tracker.isTracking {
            tooltip += "\nToday: \(TimeAggregator.format(app.tracker.total(in: .today)))"
        }
        button.toolTip = tooltip
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        app.spaces.refresh()
        menu.removeAllItems()

        let spaces = app.spaces
        let snapshot = spaces.snapshot
        let settings = app.config.config.settings

        if !spaces.isAvailable {
            let item = NSMenuItem(title: "Spaces are not readable on this macOS version", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }

        if let active = spaces.activeSpace {
            let header = NSMenuItem(title: "\(spaces.name(for: active)) — \(spaces.subtitle(for: active))", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            if active.isDesktop {
                let rename = NSMenuItem(title: "Rename “\(spaces.name(for: active))”…", action: #selector(renameCurrent), keyEquivalent: "")
                rename.target = self
                rename.setShortcut(for: .renameCurrentSpace)
                menu.addItem(rename)
            }
            menu.addItem(.separator())
        }

        for display in snapshot.displays {
            if snapshot.displays.count > 1 {
                let header = NSMenuItem(title: DisplayInfo.name(forIdentifier: display.identifier), action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)
            }
            for space in display.spaces where settings.showFullscreenSpaces || space.isDesktop {
                menu.addItem(spaceItem(for: space, indent: snapshot.displays.count > 1))
            }
        }
        if snapshot.allSpaces.isEmpty {
            let item = NSMenuItem(title: "No spaces found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let switcher = NSMenuItem(title: "Quick Switcher…", action: #selector(openQuickSwitcher), keyEquivalent: "")
        switcher.target = self
        switcher.setShortcut(for: .quickSwitcher)
        menu.addItem(switcher)

        let backTitle: String
        if let key = spaces.previousSpaceKey, let previous = snapshot.space(key: key) {
            backTitle = "Jump Back to “\(spaces.name(for: previous))”"
        } else {
            backTitle = "Jump Back"
        }
        let back = NSMenuItem(title: backTitle, action: #selector(jumpBack), keyEquivalent: "")
        back.target = self
        back.isEnabled = spaces.previousSpaceKey != nil
        back.setShortcut(for: .jumpBack)
        menu.addItem(back)

        let move = NSMenuItem(title: "Move Front Window To", action: nil, keyEquivalent: "")
        let moveMenu = NSMenu()
        for space in snapshot.desktops where !space.isCurrentOnDisplay || space.displayIdentifier != spaces.activeSpace?.displayIdentifier {
            let item = NSMenuItem(title: spaces.name(for: space), action: #selector(moveWindow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = space.key
            item.image = iconImage(for: space)
            moveMenu.addItem(item)
        }
        if moveMenu.items.isEmpty {
            let none = NSMenuItem(title: "No other desktop", action: nil, keyEquivalent: "")
            none.isEnabled = false
            moveMenu.addItem(none)
        }
        move.submenu = moveMenu
        menu.addItem(move)

        if let active = spaces.activeSpace, active.isDesktop {
            let notes = NSMenuItem(title: "Notes for “\(spaces.name(for: active))”…", action: #selector(openNotes), keyEquivalent: "")
            notes.target = self
            menu.addItem(notes)
        }

        menu.addItem(actionsItem())
        menu.addItem(timeTrackingItem())
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let about = NSMenuItem(title: "About MacSpaceName", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit MacSpaceName", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func spaceItem(for space: SpaceInfo, indent: Bool) -> NSMenuItem {
        let spaces = app.spaces
        let settings = app.config.config.settings
        let name = spaces.name(for: space)
        var title = name
        if settings.showNumbersInMenu, let number = space.desktopNumber {
            title = "\(number)  \(name)"
        }
        let item = NSMenuItem(title: title, action: #selector(switchToSpace(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = space.key
        item.state = space.isCurrentOnDisplay ? .on : .off
        item.image = iconImage(for: space)
        item.indentationLevel = indent ? 1 : 0
        if space.isDesktop {
            item.setShortcut(for: .space(space.key))
        } else {
            item.toolTip = "Full-screen space"
        }
        return item
    }

    private func iconImage(for space: SpaceInfo) -> NSImage? {
        let color = app.spaces.color(for: space)
        if let icon = app.spaces.icon(for: space) {
            return icon.nsImage(color: color, pointSize: 13)
        }
        if space.isFullscreen {
            let image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Full screen")
            image?.isTemplate = true
            return image
        }
        guard let color else { return nil }
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func actionsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Run Actions", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let groups = app.config.config.actionGroups
        if groups.isEmpty {
            let none = NSMenuItem(title: "No action groups yet", action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
        }
        for group in groups {
            let run = NSMenuItem(title: "▶ \(group.name)", action: #selector(runGroup(_:)), keyEquivalent: "")
            run.target = self
            run.representedObject = group.id.uuidString
            submenu.addItem(run)
        }
        submenu.addItem(.separator())
        let edit = NSMenuItem(title: "Edit Actions…", action: #selector(openActionsSettings), keyEquivalent: "")
        edit.target = self
        submenu.addItem(edit)
        item.submenu = submenu
        return item
    }

    private func timeTrackingItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Time Tracking", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let tracker = app.tracker
        let today = NSMenuItem(title: "Today: \(TimeAggregator.format(tracker.total(in: .today)))", action: nil, keyEquivalent: "")
        today.isEnabled = false
        submenu.addItem(today)
        if tracker.isEnabled {
            let status = NSMenuItem(title: tracker.isPaused ? "Resume Tracking" : "Pause Tracking", action: #selector(toggleTracking), keyEquivalent: "")
            status.target = self
            submenu.addItem(status)
        } else {
            let off = NSMenuItem(title: "Tracking is off (enable in Settings)", action: nil, keyEquivalent: "")
            off.isEnabled = false
            submenu.addItem(off)
        }
        submenu.addItem(.separator())
        let open = NSMenuItem(title: "Open Time Tracking…", action: #selector(openTimeTracking), keyEquivalent: "")
        open.target = self
        submenu.addItem(open)
        let export = NSMenuItem(title: "Export CSV…", action: #selector(exportCSV), keyEquivalent: "")
        export.target = self
        submenu.addItem(export)
        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    @objc private func switchToSpace(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        app.spaces.switchTo(key: key)
    }

    @objc private func moveWindow(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let space = app.spaces.snapshot.space(key: key) else { return }
        app.moveFrontWindow(to: space)
    }

    @objc private func renameCurrent() {
        app.renamePrompt()
    }

    @objc private func openQuickSwitcher() {
        app.quickSwitcher.show()
    }

    @objc private func jumpBack() {
        app.spaces.jumpBack()
    }

    @objc private func openNotes() {
        app.notes.show(spaceKey: app.spaces.activeSpace?.key)
    }

    @objc private func runGroup(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw),
              let group = app.config.config.group(id: id) else { return }
        app.actions.run(group)
    }

    @objc private func openActionsSettings() {
        app.settings.show(tab: .actions)
    }

    @objc private func toggleTracking() {
        app.tracker.isPaused.toggle()
    }

    @objc private func openTimeTracking() {
        app.timeWindow.show()
    }

    @objc private func exportCSV() {
        app.tracker.exportCSVWithPanel()
    }

    @objc private func openSettings() {
        app.settings.show()
    }

    @objc private func openAbout() {
        app.settings.show(tab: .about)
    }

    @objc private func checkForUpdates() {
        app.updater.check(userInitiated: true)
    }
}
