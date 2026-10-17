import AppKit

@main
enum MacSpaceNameMain {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
            withExtendedLifetime(delegate) {}
        }
    }
}
