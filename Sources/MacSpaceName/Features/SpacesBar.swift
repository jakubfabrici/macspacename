import AppKit
import MacSpaceNameCore

/// A pill-shaped button representing one space inside the floating spaces bar.
final class PillView: NSView {
    let key: String
    let isCurrent: Bool
    var onClick: (() -> Void)?
    private let label = NSTextField(labelWithString: "")
    private var hovered = false { didSet { needsDisplay = true } }

    init(key: String, title: String, image: NSImage?, color: NSColor?, isCurrent: Bool) {
        self.key = key
        self.isCurrent = isCurrent
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8

        let text = NSMutableAttributedString()
        if let image {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -3, width: 14, height: 14)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " "))
        } else if let color {
            text.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: color]))
        }
        text.append(NSAttributedString(string: title))
        text.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: isCurrent ? .semibold : .regular), range: NSRange(location: 0, length: text.length))
        label.attributedStringValue = text
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 30),
            widthAnchor.constraint(lessThanOrEqualToConstant: 220),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        let fill: NSColor
        if isCurrent {
            fill = NSColor.controlAccentColor.withAlphaComponent(hovered ? 0.5 : 0.35)
        } else {
            fill = NSColor.labelColor.withAlphaComponent(hovered ? 0.18 : 0.08)
        }
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
    }

    /// The pill's frame in screen coordinates.
    var screenFrame: NSRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}

/// The floating bar of spaces shown when hovering the notch ("Space Hover") or while Shift-dragging a window ("Drag to Move").
@MainActor
final class SpacesBarController {
    enum Mode { case hidden, hover, drag }

    private weak var app: AppContainer!
    private var panel: NSPanel?
    private var pills: [PillView] = []
    private var timer: Timer?
    private(set) var mode: Mode = .hidden

    private var hoverStarted: Date?
    private var lastInside = Date()
    private var dragHoverKey: String?
    private var dragHoverSince = Date()
    private var dragSwitchedKey: String?

    func attach(to app: AppContainer) {
        self.app = app
    }

    /// Polls the mouse at 15 Hz. Polling (instead of event monitors) needs no permissions and also works
    /// while the window server is moving a window for the user.
    func start() {
        let timer = Timer.scheduledTimer(timeInterval: 1.0 / 15.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.02
        self.timer = timer
    }

    @objc private func tick() {
        let settings = app.config.config.settings
        let location = NSEvent.mouseLocation
        let leftButtonDown = NSEvent.pressedMouseButtons & 1 == 1
        let shift = NSEvent.modifierFlags.contains(.shift)

        if settings.dragToMove, leftButtonDown, shift {
            dragUpdate(at: location)
            return
        }
        if mode == .drag {
            hide()
            return
        }
        if settings.hoverBar {
            hoverUpdate(at: location)
        } else if mode == .hover {
            hide()
        }
    }

    // MARK: - Hover

    /// The region that reveals the bar: the camera notch, or a thin strip at the top centre of screens without one.
    func hotZone(for screen: NSScreen) -> NSRect {
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NSRect(x: left.maxX, y: frame.maxY - screen.safeAreaInsets.top, width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
        }
        let width = frame.width * 0.3
        return NSRect(x: frame.midX - width / 2, y: frame.maxY - 2, width: width, height: 2)
    }

    private func hoverUpdate(at location: NSPoint) {
        guard let screen = DisplayInfo.screen(containing: location) else { return }
        switch mode {
        case .hidden:
            if hotZone(for: screen).contains(location) {
                if let started = hoverStarted {
                    if Date().timeIntervalSince(started) >= 0.25 { show(on: screen, mode: .hover) }
                } else {
                    hoverStarted = Date()
                }
            } else {
                hoverStarted = nil
            }
        case .hover:
            guard let panel else { return }
            let keepArea = panel.frame.union(hotZone(for: screen)).insetBy(dx: -24, dy: -24)
            if keepArea.contains(location) {
                lastInside = Date()
            } else if Date().timeIntervalSince(lastInside) > 0.4 {
                hide()
            }
        case .drag:
            break
        }
    }

    // MARK: - Drag to move

    private func dragUpdate(at location: NSPoint) {
        guard let screen = DisplayInfo.screen(containing: location) else { return }
        if mode != .drag || panel?.screen != screen {
            dragSwitchedKey = nil
            show(on: screen, mode: .drag)
        }
        guard let pill = pills.first(where: { $0.screenFrame?.contains(location) == true }) else {
            dragHoverKey = nil
            return
        }
        if pill.key != dragHoverKey {
            dragHoverKey = pill.key
            dragHoverSince = Date()
            return
        }
        guard Date().timeIntervalSince(dragHoverSince) >= 0.25,
              !pill.isCurrent,
              dragSwitchedKey != pill.key,
              let space = app.spaces.snapshot.space(key: pill.key) else { return }
        dragSwitchedKey = pill.key
        // The user is holding the window, so switching takes the window along.
        app.spaces.switchTo(space)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.mode == .drag, let screen = self.panel?.screen else { return }
            self.show(on: screen, mode: .drag)
        }
    }

    // MARK: - Panel

    private func show(on screen: NSScreen, mode: Mode) {
        app.spaces.refresh()
        let spaces = app.spaces
        let settings = app.config.config.settings
        guard let display = spaces.spaces(on: screen) ?? spaces.snapshot.displays.first else { return }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        pills.forEach { $0.removeFromSuperview() }
        pills = []

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        for space in display.spaces where settings.showFullscreenSpaces || space.isDesktop {
            let title: String
            if settings.showNumbersInMenu, let number = space.desktopNumber {
                title = "\(number) \(spaces.name(for: space))"
            } else {
                title = spaces.name(for: space)
            }
            let color = spaces.color(for: space)
            let image = spaces.icon(for: space)?.nsImage(color: color ?? .labelColor, pointSize: 12)
            let pill = PillView(key: space.key, title: title, image: image, color: color, isCurrent: space.isCurrentOnDisplay)
            pill.onClick = { [weak self] in
                self?.hide()
                self?.app.spaces.switchTo(space)
            }
            stack.addArrangedSubview(pill)
            pills.append(pill)
        }
        guard !pills.isEmpty else { return }

        let container = NSVisualEffectView()
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container

        let size = stack.fittingSize
        let maxWidth = screen.frame.width - 40
        let width = min(size.width, maxWidth)
        let origin = NSPoint(x: screen.frame.midX - width / 2, y: screen.visibleFrame.maxY - size.height - 6)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: size.height)), display: true)
        panel.orderFrontRegardless()

        self.mode = mode
        lastInside = Date()
        hoverStarted = nil
        dragHoverKey = nil
    }

    func hide() {
        panel?.orderOut(nil)
        mode = .hidden
        hoverStarted = nil
        dragHoverKey = nil
        dragSwitchedKey = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 46), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .utilityWindow
        return panel
    }
}
