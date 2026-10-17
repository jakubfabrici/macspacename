import AppKit
import ApplicationServices
import MacSpaceNameCore

// MARK: - Accessibility helpers

enum AXHelper {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return result == .success ? value : nil
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        guard let value = attribute(element, name), CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return unsafeBitCast(value, to: CFString.self) as String
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        guard let value = attribute(element, name), CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        let array = unsafeBitCast(value, to: CFArray.self)
        let count = CFArrayGetCount(array)
        var result: [AXUIElement] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            guard let pointer = CFArrayGetValueAtIndex(array, index) else { continue }
            let object = Unmanaged<CFTypeRef>.fromOpaque(pointer).takeUnretainedValue()
            guard CFGetTypeID(object) == AXUIElementGetTypeID() else { continue }
            result.append(unsafeBitCast(object, to: AXUIElement.self))
        }
        return result
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        elements(element, kAXChildrenAttribute)
    }

    /// Frame in Quartz coordinates (origin top-left of the main display).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let positionValue = attribute(element, kAXPositionAttribute), CFGetTypeID(positionValue) == AXValueGetTypeID(),
              let sizeValue = attribute(element, kAXSizeAttribute), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(positionValue, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    /// Breadth-first search for elements whose `AXIdentifier` equals `identifier`, at most `maxDepth` levels below `root`.
    static func findElements(in root: AXUIElement, identifier: String, maxDepth: Int) -> [AXUIElement] {
        var found: [AXUIElement] = []
        var frontier = [root]
        for _ in 0..<maxDepth {
            var next: [AXUIElement] = []
            for element in frontier {
                for child in children(element) {
                    if string(child, kAXIdentifierAttribute) == identifier {
                        found.append(child)
                    } else {
                        next.append(child)
                    }
                }
            }
            if !found.isEmpty || next.isEmpty { break }
            frontier = next
        }
        return found
    }
}

// MARK: - Reading the Mission Control spaces bar

struct MissionControlSpaceButton {
    let title: String
    let frame: CGRect
}

struct MissionControlSpacesBar {
    let displayFrame: CGRect?
    let buttons: [MissionControlSpaceButton]
}

enum MissionControlAX {
    /// Processes that expose the Mission Control UI through Accessibility: the Dock, and WindowManager on newer systems.
    static let hostBundleIDs = ["com.apple.dock", "com.apple.WindowManager"]

    static func isHost(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return hostBundleIDs.contains(bundleID)
    }

    /// Reads the Spaces bar(s) if Mission Control (or App Exposé) is currently open.
    static func readSpacesBars() -> [MissionControlSpacesBar] {
        for bundleID in hostBundleIDs {
            for host in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                let root = AXUIElementCreateApplication(host.processIdentifier)
                AXUIElementSetMessagingTimeout(root, 0.25)
                let displays = AXHelper.findElements(in: root, identifier: "mc.display", maxDepth: 3)
                if displays.isEmpty { continue }
                var bars: [MissionControlSpacesBar] = []
                for display in displays {
                    guard let spaces = AXHelper.findElements(in: display, identifier: "mc.spaces", maxDepth: 2).first,
                          let list = AXHelper.findElements(in: spaces, identifier: "mc.spaces.list", maxDepth: 2).first else { continue }
                    let buttons = AXHelper.children(list).compactMap { element -> MissionControlSpaceButton? in
                        guard AXHelper.string(element, kAXRoleAttribute) == kAXButtonRole,
                              let frame = AXHelper.frame(element) else { return nil }
                        let title = AXHelper.string(element, kAXTitleAttribute)
                            ?? AXHelper.string(element, kAXDescriptionAttribute) ?? ""
                        return MissionControlSpaceButton(title: title, frame: frame)
                    }
                    bars.append(MissionControlSpacesBar(displayFrame: AXHelper.frame(display), buttons: buttons))
                }
                if !bars.isEmpty { return bars }
            }
        }
        return []
    }
}

// MARK: - Overlay window

/// A tiny always-on-top, click-through window that shows one space name above its Mission Control thumbnail.
final class LabelPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private let container = NSView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Assistive-technology level draws above Mission Control itself.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.78).cgColor
        container.layer?.cornerRadius = 7
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        container.addSubview(label)
        contentView = container
    }

    func configure(text: NSAttributedString) {
        label.attributedStringValue = text
        let size = text.size()
        let width = min(ceil(size.width) + 20, 240)
        let height = ceil(size.height) + 8
        label.frame = NSRect(x: 10, y: 4, width: width - 20, height: height - 8)
        container.frame = NSRect(x: 0, y: 0, width: width, height: height)
        setContentSize(NSSize(width: width, height: height))
    }
}

/// Shows custom space names inside Mission Control by overlaying labels on the Spaces bar.
///
/// Experimental: it relies on the Accessibility tree of the Dock, which Apple can change at any time.
@MainActor
final class MissionControlLabelController {
    private weak var app: AppContainer!
    private var watching = false
    private var everFound = false
    private var deadline = Date.distantPast
    private var pollTimer: Timer?
    private var checkTimer: Timer?
    private var panels: [LabelPanel] = []

    func attach(to app: AppContainer) {
        self.app = app
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        // Cheap fallback in case the activation notification is missed (gesture-triggered Mission Control).
        checkTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(checkFrontmost), userInfo: nil, repeats: true)
    }

    private var isEnabled: Bool {
        app.config.config.settings.missionControlLabels && Accessibility.isTrusted
    }

    @objc private func appActivated(_ notification: Notification) {
        guard isEnabled,
              let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              MissionControlAX.isHost(application.bundleIdentifier) else { return }
        beginWatching()
    }

    @objc private func checkFrontmost() {
        guard isEnabled, !watching,
              MissionControlAX.isHost(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else { return }
        beginWatching()
    }

    private func beginWatching() {
        guard !watching else { return }
        watching = true
        everFound = false
        deadline = Date().addingTimeInterval(2.5)
        pollTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
        poll()
    }

    private func stopWatching() {
        pollTimer?.invalidate()
        pollTimer = nil
        watching = false
        hideAll()
    }

    @objc private func poll() {
        guard isEnabled else {
            stopWatching()
            return
        }
        let bars = MissionControlAX.readSpacesBars()
        if bars.isEmpty {
            if everFound || Date() > deadline { stopWatching() } else { hideAll() }
            return
        }
        everFound = true
        layout(bars)
    }

    private func layout(_ bars: [MissionControlSpacesBar]) {
        let spaces = app.spaces
        let snapshot = spaces.snapshot
        var used = 0

        for bar in bars {
            guard let display = display(for: bar, in: snapshot) else { continue }
            let count = min(display.spaces.count, bar.buttons.count)
            guard count > 0 else { continue }
            for index in 0..<count {
                let space = display.spaces[index]
                let button = bar.buttons[index]
                // Only spaces with a custom name get a label; the system already shows "Desktop N" for the rest.
                guard space.isDesktop, let name = app.config.customName(for: space.key) else { continue }
                let panel = panel(at: used)
                used += 1
                panel.configure(text: attributedTitle(name: name, space: space))
                let buttonFrame = DisplayInfo.cocoaRect(fromQuartz: button.frame)
                let size = panel.frame.size
                let x = buttonFrame.midX - size.width / 2
                let y: CGFloat
                if buttonFrame.height < 60 {
                    // Collapsed bar: the button is just the text label; cover it.
                    y = buttonFrame.midY - size.height / 2
                } else {
                    // Expanded thumbnails: sit at the top edge of the thumbnail.
                    y = buttonFrame.maxY - size.height - 6
                }
                panel.setFrameOrigin(NSPoint(x: x, y: y))
                panel.orderFrontRegardless()
            }
        }
        for panel in panels.dropFirst(used) { panel.orderOut(nil) }
    }

    private func display(for bar: MissionControlSpacesBar, in snapshot: SpaceSnapshot) -> DisplaySpaces? {
        if snapshot.displays.count <= 1 { return snapshot.displays.first }
        guard let frame = bar.displayFrame else { return nil }
        let screen = NSScreen.screens.min { lhs, rhs in
            distance(frame, DisplayInfo.quartzRect(fromCocoa: lhs.frame)) < distance(frame, DisplayInfo.quartzRect(fromCocoa: rhs.frame))
        }
        guard let screen, let identifier = DisplayInfo.identifier(for: screen) else { return nil }
        return snapshot.displays.first { $0.identifier == identifier }
    }

    private func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX - b.minX) + abs(a.minY - b.minY)
    }

    private func attributedTitle(name: String, space: SpaceInfo) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        if let icon = app.spaces.icon(for: space) {
            switch icon {
            case .text(let value):
                text.append(NSAttributedString(string: "\(value) ", attributes: [.font: font]))
            case .symbol:
                if let image = icon.nsImage(color: .white, pointSize: 11) {
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    attachment.bounds = CGRect(x: 0, y: -2, width: 13, height: 13)
                    text.append(NSAttributedString(attachment: attachment))
                    text.append(NSAttributedString(string: " ", attributes: [.font: font]))
                }
            }
        } else if let color = app.spaces.color(for: space) {
            text.append(NSAttributedString(string: "● ", attributes: [.font: font, .foregroundColor: color]))
        }
        text.append(NSAttributedString(string: name, attributes: [.font: font, .foregroundColor: NSColor.white]))
        return text
    }

    private func panel(at index: Int) -> LabelPanel {
        while panels.count <= index { panels.append(LabelPanel()) }
        return panels[index]
    }

    private func hideAll() {
        panels.forEach { $0.orderOut(nil) }
    }
}
