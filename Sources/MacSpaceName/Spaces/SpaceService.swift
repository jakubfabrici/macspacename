import AppKit
import Combine
import MacSpaceNameCore

/// The one object UI code talks to: current spaces, their names/icons/colors, and switching.
@MainActor
final class SpaceService: ObservableObject {
    let config: ConfigStore
    private let monitor: SpaceMonitor
    private let switcher: SpaceSwitcher

    @Published private(set) var snapshot: SpaceSnapshot = .empty
    @Published private(set) var activeSpace: SpaceInfo?
    @Published private(set) var previousSpaceKey: String?

    /// Called with (previous, current) whenever the user lands on a different space.
    var onActiveSpaceChanged: ((SpaceInfo?, SpaceInfo?) -> Void)?
    /// Called when spaces were added, removed or moved between displays.
    var onSpaceListChanged: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init(config: ConfigStore, monitor: SpaceMonitor, switcher: SpaceSwitcher) {
        self.config = config
        self.monitor = monitor
        self.switcher = switcher
        switcher.method = config.config.settings.switchMethod

        config.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                DispatchQueue.main.async { self?.switcher.method = config.config.settings.switchMethod }
            }
            .store(in: &cancellables)
    }

    var isAvailable: Bool { PrivateAPI.isAvailable }

    func start() {
        monitor.onChange = { [weak self] snapshot in self?.apply(snapshot) }
        monitor.start()
    }

    func refresh() {
        monitor.refresh()
    }

    private func apply(_ fresh: SpaceSnapshot) {
        let previousSnapshot = snapshot
        let previousActive = activeSpace
        snapshot = fresh
        let current = fresh.activeSpace
        activeSpace = current

        if previousActive?.key != current?.key {
            if let previousActive { previousSpaceKey = previousActive.key }
            onActiveSpaceChanged?(previousActive, current)
        }
        if Set(previousSnapshot.allSpaces.map(\.key)) != Set(fresh.allSpaces.map(\.key)) {
            onSpaceListChanged?()
        }
    }

    // MARK: - Names, icons, colors

    func name(for space: SpaceInfo) -> String {
        config.customName(for: space.key) ?? defaultName(for: space)
    }

    func defaultName(for space: SpaceInfo) -> String {
        switch space.kind {
        case .desktop:
            return "Desktop \(space.desktopNumber ?? space.indexOnDisplay)"
        case .fullscreen:
            if let pid = space.fullscreenPID,
               let app = NSRunningApplication(processIdentifier: pid),
               let appName = app.localizedName {
                return "\(appName) (Full Screen)"
            }
            return "Full Screen"
        case .other:
            return "Space \(space.indexOnDisplay)"
        }
    }

    func icon(for space: SpaceInfo) -> SpaceIcon? {
        SpaceIcon(string: config.spaceConfig(for: space.key).icon)
    }

    func color(for space: SpaceInfo) -> NSColor? {
        NSColor(hex: config.spaceConfig(for: space.key).color)
    }

    /// "Desktop 3 · Built-in Display"
    func subtitle(for space: SpaceInfo) -> String {
        let base = space.isDesktop ? "Desktop \(space.desktopNumber ?? space.indexOnDisplay)" : "Full-screen space"
        guard snapshot.displays.count > 1 else { return base }
        return "\(base) · \(DisplayInfo.name(forIdentifier: space.displayIdentifier))"
    }

    func rename(_ space: SpaceInfo, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        config.update(space.key) { $0.name = trimmed.isEmpty ? nil : trimmed }
    }

    /// Spaces shown on `screen` (all spaces when displays share one set of spaces).
    func spaces(on screen: NSScreen) -> DisplaySpaces? {
        if snapshot.displays.count <= 1 { return snapshot.displays.first }
        guard let identifier = DisplayInfo.identifier(for: screen) else { return nil }
        return snapshot.displays.first { $0.identifier == identifier }
    }

    // MARK: - Switching

    func switchTo(_ space: SpaceInfo) {
        switcher.switchTo(space, in: snapshot)
    }

    func switchTo(key: String) {
        guard let space = snapshot.space(key: key) else { return }
        switchTo(space)
    }

    func switchToDesktop(number: Int) {
        guard let space = snapshot.desktop(number: number) else { return }
        switchTo(space)
    }

    /// Finds a space by custom name, default name, or desktop number (case/diacritic-insensitive).
    func switchTo(name: String) -> Bool {
        let wanted = SpaceMatcher.normalize(name)
        guard !wanted.isEmpty else { return false }
        let candidates = snapshot.allSpaces
        let exact = candidates.first {
            SpaceMatcher.normalize(self.name(for: $0)) == wanted || SpaceMatcher.normalize(defaultName(for: $0)) == wanted
        }
        let best = exact ?? candidates
            .compactMap { space -> (SpaceInfo, Int)? in
                SpaceMatcher.score(query: wanted, candidate: self.name(for: space)).map { (space, $0) }
            }
            .max { $0.1 < $1.1 }?.0
        guard let target = best else { return false }
        switchTo(target)
        return true
    }

    func switchRelative(_ offset: Int, wrap: Bool = true) {
        guard let active = activeSpace,
              let target = snapshot.neighbor(of: active, offset: offset, wrap: wrap) else { return }
        switchTo(target)
    }

    func jumpBack() {
        guard let key = previousSpaceKey, let target = snapshot.space(key: key) else { return }
        switchTo(target)
    }
}
