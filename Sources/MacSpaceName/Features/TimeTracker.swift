import AppKit
import Combine
import UniformTypeIdentifiers
import MacSpaceNameCore

enum IdleDetector {
    /// Seconds since the last keyboard/mouse input (no permission needed).
    static var seconds: TimeInterval {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .flagsChanged, .leftMouseDragged]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
    }
}

/// Automatic per-space / per-app time tracking with idle detection. Everything stays in a local JSON file.
@MainActor
final class TimeTracker: ObservableObject {
    @Published private(set) var log = TimeLog()
    @Published private(set) var current: TimeEntry?
    @Published private(set) var isIdle = false
    @Published var isPaused = false {
        didSet {
            guard isPaused != oldValue else { return }
            if isPaused { closeCurrent() } else { openEntry() }
        }
    }
    @Published var sessionName = "" {
        didSet {
            guard sessionName != oldValue else { return }
            closeCurrent()
            openEntry()
        }
    }

    let fileURL: URL
    private let config: ConfigStore
    private let spaces: SpaceService
    private var tickTimer: Timer?
    private var started = false
    private var dirty = false
    private var lastSave = Date()
    private var cancellables = Set<AnyCancellable>()

    init(fileURL: URL, config: ConfigStore, spaces: SpaceService) {
        self.fileURL = fileURL
        self.config = config
        self.spaces = spaces
        if let data = try? Data(contentsOf: fileURL), let stored = try? ConfigStore.decoder.decode(TimeLog.self, from: data) {
            log = stored
        }
        config.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.settingsChanged() } }
            .store(in: &cancellables)
    }

    static func defaultFileURL() -> URL {
        ConfigStore.defaultFileURL().deletingLastPathComponent().appendingPathComponent("timelog.json")
    }

    var isEnabled: Bool { config.config.settings.timeTracking }
    var isTracking: Bool { isEnabled && !isPaused && !isIdle && current != nil }

    func start() {
        started = true
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        tickTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        openEntry()
    }

    func spaceDidChange(to space: SpaceInfo?) {
        guard started else { return }
        closeCurrent()
        openEntry()
    }

    @objc private func appActivated(_ notification: Notification) {
        guard started, !isIdle else { return }
        closeCurrent()
        openEntry()
    }

    private func settingsChanged() {
        guard started else { return }
        if !isEnabled {
            closeCurrent()
        } else if current == nil, !isPaused, !isIdle {
            openEntry()
        }
    }

    private func openEntry() {
        guard started, isEnabled, !isPaused, !isIdle, let space = spaces.activeSpace else { return }
        let frontApp = NSWorkspace.shared.frontmostApplication
        let now = Date()
        current = TimeEntry(
            spaceKey: space.key,
            spaceName: spaces.name(for: space),
            appBundleID: frontApp?.bundleIdentifier,
            appName: frontApp?.localizedName,
            session: sessionName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sessionName,
            start: now,
            end: now
        )
    }

    private func closeCurrent(at date: Date = Date()) {
        guard var entry = current else { return }
        entry.end = max(entry.start, date)
        current = nil
        if entry.duration >= 1 {
            log.entries.append(entry)
            dirty = true
        }
    }

    @objc private func tick() {
        guard started else { return }
        guard isEnabled, !isPaused else {
            closeCurrent()
            return
        }
        let idle = IdleDetector.seconds
        let threshold = Double(max(1, config.config.settings.idleMinutes)) * 60
        if idle >= threshold {
            if !isIdle {
                isIdle = true
                closeCurrent(at: Date().addingTimeInterval(-idle))
            }
        } else {
            if isIdle {
                isIdle = false
                openEntry()
            } else if current != nil {
                current?.end = Date()
            } else {
                openEntry()
            }
        }
        if dirty, Date().timeIntervalSince(lastSave) > 60 { save() }
    }

    // MARK: - Queries

    var allEntries: [TimeEntry] {
        var entries = log.entries
        if var live = current {
            live.end = Date()
            entries.append(live)
        }
        return entries
    }

    func total(in range: TimeRange) -> TimeInterval {
        TimeAggregator.total(allEntries, in: range)
    }

    func totals(by grouping: TimeAggregator.Grouping, in range: TimeRange) -> [TimeTotal] {
        TimeAggregator.totals(allEntries, by: grouping, in: range)
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try ConfigStore.encoder.encode(log)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            dirty = false
            lastSave = Date()
        } catch {
            NSLog("MacSpaceName: could not save time log: \(error)")
        }
    }

    /// Closes the live entry and writes everything to disk (called when quitting).
    func flush() {
        closeCurrent()
        save()
    }

    func clearLog() {
        closeCurrent()
        log = TimeLog()
        dirty = true
        save()
        openEntry()
    }

    func exportCSVWithPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "MacSpaceName-time-\(formatter.string(from: Date())).csv"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try CSVExporter.csv(for: allEntries).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            RenamePrompt.info(title: "Export failed", message: error.localizedDescription)
        }
    }
}
