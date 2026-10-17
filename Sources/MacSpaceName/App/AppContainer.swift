import AppKit
import MacSpaceNameCore

/// Owns every long-lived object and wires them together.
@MainActor
final class AppContainer {
    let config: ConfigStore
    let spaces: SpaceService
    let tracker: TimeTracker
    let actions: ActionRunner
    let statusItem: StatusItemController
    let quickSwitcher: QuickSwitcherController
    let settings: SettingsWindowController
    let notes: NotesWindowController
    let timeWindow: TimeTrackingWindowController
    let hotkeys: HotkeyManager
    let spacesBar: SpacesBarController
    let missionControl: MissionControlLabelController
    let windowMover: WindowMover
    let urlHandler: URLCommandHandler

    init() {
        let config = ConfigStore(fileURL: ConfigStore.defaultFileURL())
        self.config = config

        let monitor = SpaceMonitor(provider: SpaceProvider())
        let switcher = SpaceSwitcher()
        let spaces = SpaceService(config: config, monitor: monitor, switcher: switcher)
        self.spaces = spaces

        tracker = TimeTracker(fileURL: TimeTracker.defaultFileURL(), config: config, spaces: spaces)
        actions = ActionRunner()
        windowMover = WindowMover(spaces: spaces)

        statusItem = StatusItemController()
        quickSwitcher = QuickSwitcherController()
        settings = SettingsWindowController()
        notes = NotesWindowController()
        timeWindow = TimeTrackingWindowController()
        hotkeys = HotkeyManager()
        spacesBar = SpacesBarController()
        missionControl = MissionControlLabelController()
        urlHandler = URLCommandHandler()

        statusItem.attach(to: self)
        quickSwitcher.attach(to: self)
        settings.attach(to: self)
        notes.attach(to: self)
        timeWindow.attach(to: self)
        hotkeys.attach(to: self)
        spacesBar.attach(to: self)
        missionControl.attach(to: self)
        urlHandler.attach(to: self)
    }

    func start() {
        spaces.start()
        statusItem.install()
        hotkeys.registerAll()
        tracker.start()
        spacesBar.start()
        missionControl.start()

        spaces.onActiveSpaceChanged = { [weak self] previous, current in
            self?.activeSpaceDidChange(from: previous, to: current)
        }
        spaces.onSpaceListChanged = { [weak self] in
            self?.hotkeys.registerAll()
        }
    }

    func shutdown() {
        tracker.flush()
        try? config.save()
    }

    // MARK: - Reactions

    private func activeSpaceDidChange(from previous: SpaceInfo?, to current: SpaceInfo?) {
        tracker.spaceDidChange(to: current)
        // No automations for the first snapshot at launch, only for real switches.
        guard previous != nil, let current,
              let groupID = config.spaceConfig(for: current.key).onEnterGroupID,
              let group = config.config.group(id: groupID) else { return }
        actions.run(group)
    }

    // MARK: - User-facing operations shared by menu, hotkeys, URL scheme

    /// Prompts for a new name of `space` (defaults to the active space).
    func renamePrompt(for space: SpaceInfo? = nil) {
        guard let target = space ?? spaces.activeSpace else { return }
        let current = config.customName(for: target.key) ?? ""
        let defaultName = spaces.defaultName(for: target)
        guard let name = RenamePrompt.ask(
            title: "Rename “\(spaces.name(for: target))”",
            message: "Leave the field empty to go back to the default name (\(defaultName)).",
            current: current,
            placeholder: defaultName
        ) else { return }
        spaces.rename(target, to: name)
    }

    func moveFrontWindow(to space: SpaceInfo) {
        windowMover.moveFrontWindow(to: space)
    }
}
