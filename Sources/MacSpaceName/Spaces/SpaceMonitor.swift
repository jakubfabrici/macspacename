import AppKit
import MacSpaceNameCore

/// Keeps an up-to-date `SpaceSnapshot` by listening to the system and re-reading on every hint of change.
@MainActor
final class SpaceMonitor {
    private let provider: SpaceProvider
    private(set) var snapshot: SpaceSnapshot = .empty
    var onChange: ((SpaceSnapshot) -> Void)?

    private var plistWatcher: FileWatcher?
    private var pollTimer: Timer?
    private var refreshScheduled = false

    init(provider: SpaceProvider) {
        self.provider = provider
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemChanged(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemChanged(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemChanged(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(systemChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(systemChanged(_:)), name: NSNotification.Name("NSWorkspaceActiveDisplayDidChangeNotification"), object: nil)

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(systemChanged(_:)), name: NSNotification.Name("com.apple.exposeworkspacesdidchange"), object: nil)

        // Adding/removing desktops rewrites this plist; the window server does not post a notification for it.
        plistWatcher = FileWatcher(path: "~/Library/Preferences/com.apple.spaces.plist") { [weak self] in
            self?.scheduleRefresh()
        }

        // Safety net for anything the hooks above miss. Reading the list is cheap.
        pollTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(pollTick), userInfo: nil, repeats: true)

        refresh()
    }

    @objc private func systemChanged(_ notification: Notification) {
        scheduleRefresh()
    }

    @objc private func pollTick() {
        refresh()
    }

    /// Coalesces bursts of notifications into one read on the next run-loop turn.
    func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }

    func refresh() {
        let fresh = provider.snapshot()
        guard fresh != snapshot else { return }
        snapshot = fresh
        onChange?(fresh)
    }
}
