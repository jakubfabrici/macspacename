import AppKit
import MacSpaceNameCore

/// `macspacename://` URL scheme for scripting (Shortcuts, Raycast, Alfred, shell). See docs/url-scheme.md.
@MainActor
final class URLCommandHandler {
    private weak var app: AppContainer!

    func attach(to app: AppContainer) {
        self.app = app
    }

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "macspacename" else { return }
        let command = (url.host ?? "").lowercased()
        let pathParts = url.pathComponents.filter { $0 != "/" }
        var params: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            params[item.name.lowercased()] = item.value ?? ""
        }
        let argument = pathParts.first

        app.spaces.refresh()
        let spaces = app.spaces

        switch command {
        case "switch", "jump", "goto":
            if let number = Int(params["number"] ?? argument ?? "") {
                spaces.switchToDesktop(number: number)
            } else if let key = params["key"] {
                spaces.switchTo(key: key)
            } else if let name = params["name"] ?? argument {
                _ = spaces.switchTo(name: name)
            }
        case "back":
            spaces.jumpBack()
        case "next":
            spaces.switchRelative(1)
        case "previous", "prev":
            spaces.switchRelative(-1)
        case "rename":
            let target: SpaceInfo?
            if let number = Int(params["number"] ?? "") {
                target = spaces.snapshot.desktop(number: number)
            } else if let key = params["key"] {
                target = spaces.snapshot.space(key: key)
            } else {
                target = spaces.activeSpace
            }
            guard let target else { return }
            if let name = params["name"] ?? params["to"] ?? argument {
                spaces.rename(target, to: name)
            } else {
                app.renamePrompt(for: target)
            }
        case "switcher":
            app.quickSwitcher.show(moveWindow: (argument ?? params["mode"]) == "move")
        case "notes":
            app.notes.show(spaceKey: spaces.activeSpace?.key)
        case "settings":
            app.settings.show(tab: SettingsTab(rawValue: (argument ?? params["tab"] ?? "").lowercased()))
        case "tracking":
            switch (argument ?? params["action"] ?? "toggle").lowercased() {
            case "pause": app.tracker.isPaused = true
            case "resume": app.tracker.isPaused = false
            case "export": app.tracker.exportCSVWithPanel()
            case "show": app.timeWindow.show()
            default: app.tracker.isPaused.toggle()
            }
        case "run":
            guard let name = params["group"] ?? argument else { return }
            let wanted = SpaceMatcher.normalize(name)
            if let group = app.config.config.actionGroups.first(where: { SpaceMatcher.normalize($0.name) == wanted }) {
                app.actions.run(group)
            }
        default:
            break
        }
    }
}
