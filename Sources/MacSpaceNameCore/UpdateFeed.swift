import Foundation
import CryptoKit

/// One published version on GitHub Releases.
public struct ReleaseInfo: Equatable {
    public let tag: String
    public let version: SemanticVersion
    public let title: String
    public let notes: String
    public let pageURL: URL
    public let isPrerelease: Bool
    /// The `MacSpaceName-<version>.zip` asset, if present.
    public let zipURL: URL?
    public let zipName: String?
    /// The `SHA256SUMS.txt` asset, if present.
    public let checksumsURL: URL?

    public init(tag: String, version: SemanticVersion, title: String, notes: String, pageURL: URL, isPrerelease: Bool, zipURL: URL?, zipName: String?, checksumsURL: URL?) {
        self.tag = tag
        self.version = version
        self.title = title
        self.notes = notes
        self.pageURL = pageURL
        self.isPrerelease = isPrerelease
        self.zipURL = zipURL
        self.zipName = zipName
        self.checksumsURL = checksumsURL
    }
}

/// Parses the GitHub Releases API (`GET /repos/{owner}/{repo}/releases`) and picks the newest usable version.
public enum UpdateFeed {
    struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let name: String?
        let body: String?
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body, draft, prerelease, assets
            case htmlURL = "html_url"
        }
    }

    public static func releases(from data: Data) throws -> [ReleaseInfo] {
        let decoded = try JSONDecoder().decode([GitHubRelease].self, from: data)
        return decoded.compactMap { release in
            guard !release.draft, let version = SemanticVersion(release.tagName) else { return nil }
            let zip = release.assets.first { $0.name.lowercased().hasSuffix(".zip") }
            let sums = release.assets.first { $0.name == "SHA256SUMS.txt" }
            return ReleaseInfo(
                tag: release.tagName,
                version: version,
                title: release.name ?? release.tagName,
                notes: release.body ?? "",
                pageURL: release.htmlURL,
                isPrerelease: release.prerelease || version.isPrerelease,
                zipURL: zip?.browserDownloadURL,
                zipName: zip?.name,
                checksumsURL: sums?.browserDownloadURL
            )
        }
    }

    /// The highest version that is not a draft and (unless `includePrereleases`) not a pre-release.
    public static func latest(from data: Data, includePrereleases: Bool) throws -> ReleaseInfo? {
        try releases(from: data)
            .filter { includePrereleases || !$0.isPrerelease }
            .max { $0.version < $1.version }
    }

    /// Finds the hex digest for `assetName` in a `shasum -a 256` style listing ("<hex>  <file>").
    public static func checksum(forAssetNamed assetName: String, in listing: String) -> String? {
        for line in listing.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "*" }).map(String.init)
            guard parts.count >= 2, parts[0].count == 64 else { continue }
            if parts[1...].contains(where: { $0 == assetName || $0.hasSuffix("/" + assetName) }) {
                return parts[0].lowercased()
            }
        }
        return nil
    }

    public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
