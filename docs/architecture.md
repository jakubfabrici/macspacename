# Architecture & code map

MacSpaceName is a Swift Package with two modules and a test target. No Xcode project is checked in; `Package.swift` is the project (open it with `xed .`).

```
Package.swift
Makefile                     build / bundle / install / zip
Resources/Info.plist         bundle metadata (LSUIElement, URL scheme)
Sources/
  MacSpaceNameCore/          UI-free logic, fully unit-tested
    SpaceModels.swift        SpaceInfo, DisplaySpaces, SpaceSnapshot
    SpaceParser.swift        private CGS dictionaries -> SpaceSnapshot
    SpaceMatcher.swift       ranking for the Quick Switcher
    Config.swift             AppConfig / SpaceConfig / ActionGroup / settings + ConfigStore (JSON)
    TimeLog.swift            TimeEntry, aggregation, CSV export
  MacSpaceName/              the app (AppKit + SwiftUI)
    App/                     entry point, AppDelegate, AppContainer (wiring)
    System/                  PrivateAPI (dlsym bridge), KeyPress, Accessibility, FileWatcher, LaunchAtLogin
    Spaces/                  SpaceProvider, SpaceMonitor, SpaceSwitcher, SpaceService, DisplayInfo
    UI/                      StatusItemController (menu), icons, colors, prompts, Settings tabs
    Features/                QuickSwitcher, HotkeyManager, SpacesBar (hover + drag), MissionControlLabels,
                             WindowMover, Notes, ActionRunner, TimeTracker, TimeTrackingWindow, URLCommandHandler
Tests/MacSpaceNameCoreTests/ XCTest suites for the Core module
.github/workflows/           CI (build, test, bundle) and Release (tag -> GitHub release)
```

## Object graph

```
AppDelegate
└── AppContainer ──────────────────────────────────────────────┐
    ├── ConfigStore (Core)            JSON config, debounced saves│
    ├── SpaceService  ◄── SpaceMonitor ◄── SpaceProvider ◄── PrivateAPI
    │        │               │ (notifications, plist watcher, timer)
    │        └── SpaceSwitcher (symbolic hot keys)
    ├── TimeTracker                   idle detection, timelog.json
    ├── ActionRunner                  open / shortcuts / zsh
    ├── StatusItemController          menu bar item + NSMenu
    ├── QuickSwitcherController       NSPanel + SwiftUI
    ├── SpacesBarController           hover bar + drag-to-move (15 Hz poll)
    ├── MissionControlLabelController AX overlays
    ├── WindowMover                   synthetic drag + switch
    ├── HotkeyManager                 KeyboardShortcuts registrations
    ├── Notes / TimeTracking / Settings window controllers
    └── URLCommandHandler             macspacename://
```

`SpaceService` is the façade every UI piece talks to: current snapshot, active space, names/icons/colors (via `ConfigStore`), and all switching operations. It publishes changes through Combine (`ObservableObject`).

## Threading

Everything runs on the main thread. All app classes are `@MainActor`; the Core module is actor-agnostic and has no UI dependencies. Timers and notifications are selector-based to keep the code simple under Swift's concurrency checking.

## Conventions

* Private API usage lives only in `System/PrivateAPI.swift` and `Features/MissionControlLabels.swift` (Accessibility tree). Keep it that way so a macOS update is a one-file fix.
* New persisted fields go into `Config.swift` with a `decodeIfPresent` default so older files keep loading.
* Anything that can be unit-tested without AppKit belongs in `MacSpaceNameCore`.

## Building

```sh
swift build            # debug binary (.build/debug/MacSpaceName) — runs, but without an .app bundle
swift test             # unit tests
make bundle            # universal release .app in dist/
make install           # …and copy to /Applications
```

A bare binary works for development, but the Accessibility grant, Launch at login and the URL scheme need the real `.app` bundle.
