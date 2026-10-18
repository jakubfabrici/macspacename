import XCTest
@testable import MacSpaceNameCore

final class UpdateFeedTests: XCTestCase {
    let json = """
    [
      {"tag_name": "v0.2.0-beta.1", "name": "MacSpaceName 0.2.0-beta.1", "body": "beta notes", "html_url": "https://example.com/r/beta",
       "draft": false, "prerelease": true,
       "assets": [{"name": "MacSpaceName-0.2.0-beta.1.zip", "browser_download_url": "https://example.com/d/beta.zip"},
                  {"name": "MacSpaceName-0.2.0-beta.1.dmg", "browser_download_url": "https://example.com/d/beta.dmg"},
                  {"name": "SHA256SUMS.txt", "browser_download_url": "https://example.com/d/beta-sums"}]},
      {"tag_name": "v0.1.0", "name": "MacSpaceName 0.1.0", "body": "stable", "html_url": "https://example.com/r/stable",
       "draft": false, "prerelease": false,
       "assets": [{"name": "MacSpaceName-0.1.0.zip", "browser_download_url": "https://example.com/d/stable.zip"}]},
      {"tag_name": "v9.9.9", "name": "draft", "body": null, "html_url": "https://example.com/r/draft",
       "draft": true, "prerelease": false, "assets": []},
      {"tag_name": "not-a-version", "name": "junk", "body": "", "html_url": "https://example.com/r/junk",
       "draft": false, "prerelease": false, "assets": []}
    ]
    """

    func testLatestWithAndWithoutPrereleases() throws {
        let data = Data(json.utf8)
        let beta = try XCTUnwrap(UpdateFeed.latest(from: data, includePrereleases: true))
        XCTAssertEqual(beta.version.description, "0.2.0-beta.1")
        XCTAssertEqual(beta.zipName, "MacSpaceName-0.2.0-beta.1.zip")
        XCTAssertEqual(beta.zipURL?.absoluteString, "https://example.com/d/beta.zip")
        XCTAssertEqual(beta.checksumsURL?.absoluteString, "https://example.com/d/beta-sums")
        XCTAssertTrue(beta.isPrerelease)

        let stable = try XCTUnwrap(UpdateFeed.latest(from: data, includePrereleases: false))
        XCTAssertEqual(stable.version.description, "0.1.0")
        XCTAssertNil(stable.checksumsURL)
        XCTAssertEqual(stable.notes, "stable")
    }

    func testDraftsAndInvalidTagsAreIgnored() throws {
        let releases = try UpdateFeed.releases(from: Data(json.utf8))
        XCTAssertEqual(releases.map(\.tag), ["v0.2.0-beta.1", "v0.1.0"])
    }

    func testChecksumParsing() {
        let listing = """
        e4d038e42af347b865504481810683c529e2304110fbd4070a6e5f2548146d05  MacSpaceName-0.1.0-beta.1.dmg
        273649CBA1FB55B9385225D760630BA7278DC5E5B4A1C546018BEC1C3D0E88A6 *MacSpaceName-0.1.0-beta.1.zip
        """
        XCTAssertEqual(UpdateFeed.checksum(forAssetNamed: "MacSpaceName-0.1.0-beta.1.zip", in: listing),
                       "273649cba1fb55b9385225d760630ba7278dc5e5b4a1c546018bec1c3d0e88a6")
        XCTAssertEqual(UpdateFeed.checksum(forAssetNamed: "MacSpaceName-0.1.0-beta.1.dmg", in: listing),
                       "e4d038e42af347b865504481810683c529e2304110fbd4070a6e5f2548146d05")
        XCTAssertNil(UpdateFeed.checksum(forAssetNamed: "other.zip", in: listing))
    }

    func testSHA256() {
        XCTAssertEqual(UpdateFeed.sha256Hex(of: Data("abc".utf8)),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
