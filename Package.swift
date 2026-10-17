// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacSpaceName",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacSpaceName", targets: ["MacSpaceName"]),
        .library(name: "MacSpaceNameCore", targets: ["MacSpaceNameCore"]),
    ],
    dependencies: [
        // Global hotkeys + SwiftUI shortcut recorder (MIT).
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        // UI-free logic: models, parsing of the private Spaces data, config, time log.
        .target(name: "MacSpaceNameCore"),
        // The menu bar app itself (AppKit + SwiftUI).
        .executableTarget(
            name: "MacSpaceName",
            dependencies: [
                "MacSpaceNameCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
        .testTarget(name: "MacSpaceNameCoreTests", dependencies: ["MacSpaceNameCore"]),
    ]
)
