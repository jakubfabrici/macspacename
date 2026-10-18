import AppKit
import MacSpaceNameCore

enum UpdateError: LocalizedError {
    case badResponse
    case notBundled
    case notWritable(String)
    case checksumMismatch
    case noAppInArchive
    case wrongBundle
    case toolFailed(String, Int32)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "GitHub returned an unexpected response."
        case .notBundled: return "This copy of MacSpaceName is not running from an .app bundle, so it cannot update itself."
        case .notWritable(let path): return "The folder \(path) is not writable, so the app cannot be replaced."
        case .checksumMismatch: return "The downloaded archive does not match the published SHA-256 checksum."
        case .noAppInArchive: return "The downloaded archive does not contain MacSpaceName.app."
        case .wrongBundle: return "The downloaded app has a different bundle identifier."
        case .toolFailed(let tool, let code): return "\(tool) failed with exit code \(code)."
        }
    }
}

/// Self-updater backed by GitHub Releases: checks daily, downloads the zip, verifies the checksum,
/// swaps the app bundle in place and relaunches. No third-party framework, no signing keys.
@MainActor
final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case downloading
        case installing
        case failed(String)
    }

    static let repository = "jakubfabrici/macspacename"
    static let releasesAPI = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=20")!
    static let releasesPage = URL(string: "https://github.com/\(repository)/releases")!

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastCheck: Date?

    private let config: ConfigStore
    private let defaults = UserDefaults.standard
    private let lastCheckKey = "updates.lastCheck"
    private let skippedVersionKey = "updates.skippedVersion"
    private var timer: Timer?

    init(config: ConfigStore) {
        self.config = config
        lastCheck = defaults.object(forKey: lastCheckKey) as? Date
    }

    static var currentVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var currentVersion: SemanticVersion? { SemanticVersion(Self.currentVersionString) }

    /// True when running from a real `.app` (not `swift run`), which is required for in-place updates.
    var isBundled: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    func start() {
        timer = Timer.scheduledTimer(timeInterval: 3600, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.tick() }
    }

    @objc private func tick() {
        guard config.config.settings.automaticUpdates, isBundled else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 20 * 3600 { return }
        check(userInitiated: false)
    }

    // MARK: - Checking

    func check(userInitiated: Bool) {
        switch status {
        case .checking, .downloading, .installing: return
        default: break
        }
        status = .checking
        var request = URLRequest(url: Self.releasesAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacSpaceName/\(Self.currentVersionString)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleCheckResult(data: data, response: response, error: error, userInitiated: userInitiated)
            }
        }.resume()
    }

    private func handleCheckResult(data: Data?, response: URLResponse?, error: Error?, userInitiated: Bool) {
        lastCheck = Date()
        defaults.set(lastCheck, forKey: lastCheckKey)

        if let error {
            fail(error.localizedDescription, userInitiated: userInitiated)
            return
        }
        guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            fail(UpdateError.badResponse.localizedDescription, userInitiated: userInitiated)
            return
        }
        do {
            let include = config.config.settings.includePrereleases
            guard let release = try UpdateFeed.latest(from: data, includePrereleases: include),
                  let current = currentVersion, release.version > current else {
                status = .upToDate
                if userInitiated {
                    RenamePrompt.info(title: "You're up to date", message: "MacSpaceName \(Self.currentVersionString) is the newest version available.")
                }
                return
            }
            status = .available(release.version.description)
            if !userInitiated, defaults.string(forKey: skippedVersionKey) == release.version.description { return }
            offer(release)
        } catch {
            fail(error.localizedDescription, userInitiated: userInitiated)
        }
    }

    private func fail(_ message: String, userInitiated: Bool) {
        status = .failed(message)
        if userInitiated {
            RenamePrompt.info(title: "Could not check for updates", message: message)
        }
    }

    private func offer(_ release: ReleaseInfo) {
        let alert = NSAlert()
        alert.messageText = "MacSpaceName \(release.version) is available"
        var notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.count > 1200 { notes = String(notes.prefix(1200)) + "…" }
        alert.informativeText = "You have \(Self.currentVersionString). The update is downloaded from GitHub, verified and installed in place; the app then relaunches."
            + (notes.isEmpty ? "" : "\n\n\(notes)")
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "View on GitHub")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            install(release)
        case .alertThirdButtonReturn:
            defaults.set(release.version.description, forKey: skippedVersionKey)
        case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1):
            NSWorkspace.shared.open(release.pageURL)
        default:
            break
        }
    }

    // MARK: - Installing

    func install(_ release: ReleaseInfo) {
        guard isBundled, let zipURL = release.zipURL else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        status = .downloading
        download(zipURL) { [weak self] zipResult in
            guard let self else { return }
            switch zipResult {
            case .failure(let error):
                self.installFailed(error)
            case .success(let zipFile):
                guard let sumsURL = release.checksumsURL else {
                    self.finishInstall(release, zipFile: zipFile, checksums: nil)
                    return
                }
                self.download(sumsURL) { [weak self] sumsResult in
                    guard let self else { return }
                    switch sumsResult {
                    case .failure(let error):
                        self.installFailed(error)
                    case .success(let sumsFile):
                        let listing = (try? String(contentsOf: sumsFile, encoding: .utf8)) ?? ""
                        self.finishInstall(release, zipFile: zipFile, checksums: listing)
                    }
                }
            }
        }
    }

    /// Downloads `url` into our own temporary folder and calls back on the main queue.
    private func download(_ url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let destination = Self.workingDirectory().appendingPathComponent(url.lastPathComponent)
        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            let result: Result<URL, Error>
            if let error {
                result = .failure(error)
            } else if let tempURL, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                do {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    result = .success(destination)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(UpdateError.badResponse)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func workingDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MacSpaceName-update", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func finishInstall(_ release: ReleaseInfo, zipFile: URL, checksums: String?) {
        status = .installing
        do {
            if let checksums {
                // A published checksum list must cover the archive; never install an unverifiable download.
                guard let zipName = release.zipName,
                      let expected = UpdateFeed.checksum(forAssetNamed: zipName, in: checksums),
                      UpdateFeed.sha256Hex(of: try Data(contentsOf: zipFile)) == expected else {
                    throw UpdateError.checksumMismatch
                }
            }

            let extractDirectory = Self.workingDirectory().appendingPathComponent("extract-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", ["-x", "-k", zipFile.path, extractDirectory.path])

            let contents = try FileManager.default.contentsOfDirectory(at: extractDirectory, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else { throw UpdateError.noAppInArchive }
            guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else { throw UpdateError.wrongBundle }
            // Our own download is not quarantined, but be explicit so Gatekeeper never blocks the relaunch.
            try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            try replaceBundle(with: newApp)
            try? FileManager.default.removeItem(at: Self.workingDirectory())
            status = .idle
            relaunch()
        } catch {
            installFailed(error)
        }
    }

    private func installFailed(_ error: Error) {
        status = .failed(error.localizedDescription)
        RenamePrompt.info(
            title: "Update failed",
            message: "\(error.localizedDescription)\n\nYou can download the new version manually from the GitHub Releases page."
        )
    }

    /// Moves the running bundle aside and puts the new one at the same path.
    private func replaceBundle(with newApp: URL) throws {
        guard isBundled else { throw UpdateError.notBundled }
        let current = Bundle.main.bundleURL
        let parent = current.deletingLastPathComponent()
        let fileManager = FileManager.default
        guard fileManager.isWritableFile(atPath: parent.path) else { throw UpdateError.notWritable(parent.path) }

        let holding = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: current, create: true)
        let backup = holding.appendingPathComponent(current.lastPathComponent)
        try fileManager.moveItem(at: current, to: backup)
        do {
            try fileManager.moveItem(at: newApp, to: current)
        } catch {
            try? fileManager.moveItem(at: backup, to: current)
            throw error
        }
        // The running executable stays mapped in memory; the old bundle can go.
        try? fileManager.removeItem(at: holding)
    }

    private func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$MSN_APP_PATH\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.environment = ["MSN_APP_PATH": Bundle.main.bundleURL.path, "PATH": "/usr/bin:/bin"]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.toolFailed(executable, process.terminationStatus) }
    }
}
