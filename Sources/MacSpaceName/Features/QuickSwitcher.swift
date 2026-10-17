import AppKit
import SwiftUI
import MacSpaceNameCore

// MARK: - Model

@MainActor
final class QuickSwitcherModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: String
        let space: SpaceInfo
        let name: String
        let subtitle: String
        let icon: SpaceIcon?
        let color: Color?
        let isCurrent: Bool
        var isBestMatch: Bool = false
    }

    @Published var query = "" {
        didSet { if query != oldValue { recompute() } }
    }
    @Published private(set) var rows: [Row] = []
    @Published var selectedIndex = 0
    @Published var moveWindowMode = false

    private var all: [Row] = []

    func load(from service: SpaceService, includeFullscreen: Bool, previousKey: String?) {
        all = service.snapshot.allSpaces
            .filter { includeFullscreen || $0.isDesktop }
            .map { space in
                Row(
                    id: space.key,
                    space: space,
                    name: service.name(for: space),
                    subtitle: service.subtitle(for: space),
                    icon: service.icon(for: space),
                    color: service.color(for: space).map { Color(nsColor: $0) },
                    isCurrent: space.key == service.activeSpace?.key
                )
            }
        query = ""
        recompute()
        if let previousKey, let index = rows.firstIndex(where: { $0.id == previousKey }) {
            selectedIndex = index
        } else {
            selectedIndex = rows.firstIndex { !$0.isCurrent } ?? 0
        }
    }

    private func recompute() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            rows = all
            selectedIndex = min(selectedIndex, max(0, rows.count - 1))
            return
        }
        let scored = all.compactMap { row -> (Row, Int)? in
            var best = SpaceMatcher.score(query: trimmed, candidate: row.name)
            if let number = row.space.desktopNumber, String(number) == trimmed {
                best = max(best ?? 0, 900)
            }
            if best == nil, let appScore = SpaceMatcher.score(query: trimmed, candidate: row.subtitle) {
                best = appScore / 2
            }
            return best.map { (row, $0) }
        }
        var sorted = scored.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return (all.firstIndex(of: lhs.0) ?? 0) < (all.firstIndex(of: rhs.0) ?? 0)
        }.map(\.0)
        if !sorted.isEmpty { sorted[0].isBestMatch = true }
        rows = sorted
        selectedIndex = 0
    }

    var selectedRow: Row? { rows[safe: selectedIndex] }

    func moveSelection(_ delta: Int) {
        guard !rows.isEmpty else { return }
        let count = rows.count
        selectedIndex = (((selectedIndex + delta) % count) + count) % count
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - View

struct QuickSwitcherView: View {
    @ObservedObject var model: QuickSwitcherModel
    var onActivate: (QuickSwitcherModel.Row) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: model.moveWindowMode ? "macwindow.on.rectangle" : "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                TextField(model.moveWindowMode ? "Move the front window to…" : "Jump to a Space…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($focused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                            QuickSwitcherRowView(
                                row: row,
                                isSelected: index == model.selectedIndex,
                                number: index < 9 ? index + 1 : nil
                            )
                            .id(row.id)
                            .contentShape(Rectangle())
                            .onTapGesture { onActivate(row) }
                            .onHover { inside in if inside { model.selectedIndex = index } }
                        }
                        if model.rows.isEmpty {
                            Text("No matching Space")
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.selectedIndex) { index in
                    if let row = model.rows[safe: index] { proxy.scrollTo(row.id) }
                }
            }

            Divider()

            HStack(spacing: 14) {
                hint("↑↓", "navigate")
                hint("↩", model.moveWindowMode ? "move window" : "switch")
                if !model.moveWindowMode { hint("⇧↩", "move window") }
                hint("1–9", "jump")
                hint("esc", "close")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 540, height: 400)
        .onAppear { focused = true }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption.monospaced())
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
            Text(label)
        }
    }
}

struct QuickSwitcherRowView: View {
    let row: QuickSwitcherModel.Row
    let isSelected: Bool
    let number: Int?

    var body: some View {
        HStack(spacing: 10) {
            SpaceIconView(icon: row.icon, color: row.color, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name).fontWeight(.medium)
                    if row.isCurrent { badge("current", color: .secondary) }
                    if row.isBestMatch { badge("Best match", color: .accentColor) }
                }
                Text(row.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let number {
                Text("\(number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
        )
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

// MARK: - Panel

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Spotlight-like floating panel: type to filter, Enter to switch, Shift+Enter to move the front window.
@MainActor
final class QuickSwitcherController: NSObject, NSWindowDelegate {
    private weak var app: AppContainer!
    private var panel: SwitcherPanel?
    private let model = QuickSwitcherModel()
    private var keyMonitor: Any?

    func attach(to app: AppContainer) {
        self.app = app
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Opens the switcher, or — when it is already open and nothing was typed — jumps back to the previous space.
    func toggle() {
        if isVisible {
            let jumpBack = model.query.isEmpty && !model.moveWindowMode
            hide()
            if jumpBack { app.spaces.jumpBack() }
        } else {
            show()
        }
    }

    func show(moveWindow: Bool = false) {
        app.spaces.refresh()
        model.moveWindowMode = moveWindow
        model.load(
            from: app.spaces,
            includeFullscreen: app.config.config.settings.showFullscreenSpaces && !moveWindow,
            previousKey: app.spaces.previousSpaceKey
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    private func position(_ panel: NSPanel) {
        let screen = DisplayInfo.screen(containing: NSEvent.mouseLocation) ?? NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.minY + frame.height * 0.62 - size.height / 2)
        panel.setFrameOrigin(origin)
    }

    private func makePanel() -> SwitcherPanel {
        let panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 400),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self

        let view = QuickSwitcherView(model: model) { [weak self] row in
            self?.activate(row, moveWindow: nil)
        }
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isVisible else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53: // Escape
            hide()
            return nil
        case 126: // Up
            model.moveSelection(-1)
            return nil
        case 125: // Down
            model.moveSelection(1)
            return nil
        case 48: // Tab
            model.moveSelection(flags.contains(.shift) ? -1 : 1)
            return nil
        case 36, 76: // Return / Enter
            if let row = model.selectedRow { activate(row, moveWindow: flags.contains(.shift)) }
            return nil
        default:
            break
        }
        if let characters = event.charactersIgnoringModifiers, characters.count == 1,
           let digit = Int(characters), (1...9).contains(digit),
           flags.contains(.command) || model.query.isEmpty {
            if let row = model.rows[safe: digit - 1] { activate(row, moveWindow: flags.contains(.shift)) }
            return nil
        }
        return event
    }

    private func activate(_ row: QuickSwitcherModel.Row, moveWindow: Bool?) {
        let move = model.moveWindowMode || (moveWindow ?? false)
        hide()
        if move {
            app.moveFrontWindow(to: row.space)
        } else {
            app.spaces.switchTo(row.space)
        }
    }
}
