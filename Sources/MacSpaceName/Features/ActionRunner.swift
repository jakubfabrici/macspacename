import AppKit
import MacSpaceNameCore

/// Executes action groups: open apps, folders, URLs, Apple Shortcuts, shell commands.
@MainActor
final class ActionRunner {
    func run(_ group: ActionGroup) {
        group.items.forEach(run)
    }

    func run(_ item: ActionItem) {
        let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        switch item.kind {
        case .openApp:
            launch("/usr/bin/open", ["-a", value])
        case .openPath:
            let path = (value as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        case .openURL:
            if let url = URL(string: value) { NSWorkspace.shared.open(url) }
        case .runShortcut:
            launch("/usr/bin/shortcuts", ["run", value])
        case .runShell:
            launch("/bin/zsh", ["-lc", value])
        }
    }

    private func launch(_ executable: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("MacSpaceName: could not run \(executable) \(arguments): \(error)")
        }
    }
}
