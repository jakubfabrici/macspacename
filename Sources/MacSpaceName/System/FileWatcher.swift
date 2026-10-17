import Foundation

/// Watches one file for writes/replacements (macOS replaces plists atomically, which shows up as delete/rename).
@MainActor
final class FileWatcher {
    private let path: String
    private let handler: () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(path: String, handler: @escaping () -> Void) {
        self.path = (path as NSString).expandingTildeInPath
        self.handler = handler
        open()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func open() {
        let fd = Darwin.open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self, let current = self.source else { return }
            let flags = current.data
            self.handler()
            if flags.contains(.delete) || flags.contains(.rename) {
                self.reopen()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    private func reopen() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.open()
        }
    }
}
