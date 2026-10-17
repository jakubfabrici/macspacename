import Foundation
import MacSpaceNameCore

/// Reads the current spaces from the window server.
@MainActor
final class SpaceProvider {
    var isAvailable: Bool { PrivateAPI.isAvailable }

    func snapshot() -> SpaceSnapshot {
        SpaceParser.parse(
            managedDisplays: PrivateAPI.managedDisplaySpaces(),
            activeDisplayIdentifier: PrivateAPI.activeMenuBarDisplayIdentifier(),
            displayBounds: DisplayInfo.bounds(forIdentifier:)
        )
    }
}
