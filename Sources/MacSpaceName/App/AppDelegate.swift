import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer()
        self.container = container
        container.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { container?.urlHandler.handle($0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Double-clicking the app in Finder while it is running opens Settings.
        container?.settings.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.shutdown()
    }
}
