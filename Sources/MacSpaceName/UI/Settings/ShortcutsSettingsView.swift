import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Quick Switcher") {
                KeyboardShortcuts.Recorder("Open Quick Switcher:", name: .quickSwitcher)
                KeyboardShortcuts.Recorder("Open in “move window” mode:", name: .moveWindowSwitcher)
                Text("Inside the switcher: type to filter, ↑↓ to navigate, ↩ to switch, ⇧↩ to move the front window, 1–9 to jump, Esc to close. "
                     + "Pressing the shortcut again while the switcher is open jumps back to the previous space.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Navigation") {
                KeyboardShortcuts.Recorder("Jump back to previous space:", name: .jumpBack)
                KeyboardShortcuts.Recorder("Next space:", name: .nextSpace)
                KeyboardShortcuts.Recorder("Previous space:", name: .previousSpace)
            }
            Section("Other") {
                KeyboardShortcuts.Recorder("Rename current space:", name: .renameCurrentSpace)
                KeyboardShortcuts.Recorder("Pause / resume time tracking:", name: .toggleTracking)
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
