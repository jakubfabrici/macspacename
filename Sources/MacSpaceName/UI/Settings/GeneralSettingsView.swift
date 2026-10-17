import SwiftUI
import UniformTypeIdentifiers
import MacSpaceNameCore

struct GeneralSettingsView: View {
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var spaces: SpaceService
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var accessibilityTrusted = Accessibility.isTrusted
    @State private var message: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in
                        guard value != LaunchAtLogin.isEnabled else { return }
                        do {
                            try LaunchAtLogin.set(value)
                            launchError = nil
                        } catch {
                            launchError = "Could not change login item: \(error.localizedDescription) (the app must run from an .app bundle, e.g. /Applications)."
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Menu bar") {
                Picker("Show in menu bar", selection: config.binding(\.settings.menuBarStyle)) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { Text($0.title) }
                }
                Toggle("Show desktop numbers in lists", isOn: config.binding(\.settings.showNumbersInMenu))
                Toggle("List full-screen apps as spaces", isOn: config.binding(\.settings.showFullscreenSpaces))
            }

            Section("Switching") {
                Picker("Method", selection: config.binding(\.settings.switchMethod)) {
                    ForEach(SwitchMethod.allCases, id: \.self) { Text($0.title) }
                }
                Text("MacSpaceName switches spaces by pressing the system's own Mission Control shortcuts for you. "
                     + "They are enabled only for the instant of the key press, so your keyboard settings stay untouched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityTrusted ? Color.green : Color.orange)
                    Text(accessibilityTrusted ? "Accessibility access granted" : "Accessibility access is needed to switch spaces and to show names in Mission Control")
                    Spacer()
                    Button(accessibilityTrusted ? "Re-check" : "Grant…") {
                        if !accessibilityTrusted {
                            Accessibility.ensureTrusted(prompt: true)
                            Accessibility.openPrivacySettings()
                        }
                        accessibilityTrusted = Accessibility.isTrusted
                    }
                }
            }

            Section("Extras") {
                Toggle("Show custom names inside Mission Control (experimental)", isOn: config.binding(\.settings.missionControlLabels))
                Toggle("Space Hover: reveal the spaces bar when the pointer rests on the notch / top edge", isOn: config.binding(\.settings.hoverBar))
                Toggle("Drag to Move: hold ⇧ Shift while dragging a window to drop it on another space", isOn: config.binding(\.settings.dragToMove))
            }

            Section("Configuration file") {
                HStack {
                    Button("Export…") { exportConfig() }
                    Button("Import…") { importConfig() }
                    Button("Reveal in Finder") {
                        try? config.save()
                        NSWorkspace.shared.activateFileViewerSelecting([config.fileURL])
                    }
                    Spacer()
                }
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Text(config.fileURL.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = Accessibility.isTrusted
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MacSpaceName-config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try config.exportData().write(to: url, options: .atomic)
            message = "Exported to \(url.lastPathComponent)."
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard RenamePrompt.confirm(title: "Replace the current configuration?", message: "Names, icons, notes and action groups will be replaced by the contents of \(url.lastPathComponent).", button: "Replace", destructive: true) else { return }
        do {
            try config.importData(try Data(contentsOf: url))
            message = "Imported \(url.lastPathComponent)."
        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }
}
