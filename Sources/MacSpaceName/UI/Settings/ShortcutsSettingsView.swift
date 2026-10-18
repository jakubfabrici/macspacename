import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Quick Switcher") {
                ShortcutRecorder("Open Quick Switcher:", name: .quickSwitcher)
                ShortcutRecorder("Open in “move window” mode:", name: .moveWindowSwitcher)
                Text("Inside the switcher: type to filter, ↑↓ to navigate, ↩ to switch, ⇧↩ to move the front window, 1–9 to jump, Esc to close. "
                     + "Pressing the shortcut again while the switcher is open jumps back to the previous space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Navigation") {
                ShortcutRecorder("Jump back to previous space:", name: .jumpBack)
                ShortcutRecorder("Next space:", name: .nextSpace)
                ShortcutRecorder("Previous space:", name: .previousSpace)
            }
            Section("Other") {
                ShortcutRecorder("Rename current space:", name: .renameCurrentSpace)
                ShortcutRecorder("Pause / resume time tracking:", name: .toggleTracking)
            }
            Section {
                Text("Per-space shortcuts (jump straight to a specific space) are recorded in the Spaces tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
