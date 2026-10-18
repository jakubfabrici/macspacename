import AppKit
import SwiftUI
import MacSpaceNameCore

/// Raw values are the names used by `macspacename://settings/<tab>`.
enum SettingsTab: String, Hashable, CaseIterable {
    case general, spaces, shortcuts, actions, time, about
}

@MainActor
final class SettingsTabSelection: ObservableObject {
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @EnvironmentObject var tabs: SettingsTabSelection

    var body: some View {
        TabView(selection: $tabs.tab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            SpacesSettingsView()
                .tabItem { Label("Spaces", systemImage: "rectangle.3.group") }
                .tag(SettingsTab.spaces)
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(SettingsTab.shortcuts)
            ActionsSettingsView()
                .tabItem { Label("Actions", systemImage: "play.rectangle") }
                .tag(SettingsTab.actions)
            TimeTrackingSettingsView()
                .tabItem { Label("Time", systemImage: "clock") }
                .tag(SettingsTab.time)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 640, height: 540)
    }
}

@MainActor
final class SettingsWindowController {
    private weak var app: AppContainer!
    private var window: NSWindow?
    private let tabs = SettingsTabSelection()

    func attach(to app: AppContainer) {
        self.app = app
    }

    func show(tab: SettingsTab? = nil) {
        if let tab { tabs.tab = tab }
        let window = self.window ?? makeWindow()
        self.window = window
        WindowFactory.present(window)
    }

    private func makeWindow() -> NSWindow {
        let actions = AppActions(
            openNotes: { [weak self] key in self?.app.notes.show(spaceKey: key) },
            runGroup: { [weak self] group in self?.app.actions.run(group) },
            openTimeTracking: { [weak self] in self?.app.timeWindow.show() },
            exportCSV: { [weak self] in self?.app.tracker.exportCSVWithPanel() },
            clearTimeLog: { [weak self] in self?.app.tracker.clearLog() },
            openQuickSwitcher: { [weak self] in self?.app.quickSwitcher.show() }
        )
        let root = SettingsView()
            .environmentObject(tabs)
            .environmentObject(app.config)
            .environmentObject(app.spaces)
            .environmentObject(app.tracker)
            .environment(\.appActions, actions)
        return WindowFactory.make(title: "MacSpaceName Settings", size: NSSize(width: 640, height: 540), resizable: false, content: root)
    }
}
