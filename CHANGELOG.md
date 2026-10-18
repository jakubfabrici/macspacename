# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0-beta.2] - 2026-10-18

### Fixed
- Opening *Settings → Spaces* or *Settings → Shortcuts* crashed the app. The shortcut recorder of the KeyboardShortcuts library loads its localized strings from a SwiftPM resource bundle that the hand-built `.app` does not contain, so it hit a `fatalError`. MacSpaceName now has its own recorder that needs no resources.

### Added
- Auto-update from GitHub Releases: daily check, release-notes dialog, checksum-verified in-place install and relaunch. *Check for Updates…* in the menu, settings for automatic checks and pre-releases. Users of 0.1.0-beta.1 need to download this version manually once.
- `macspacename://settings/<tab>` opens Settings on a specific tab.
- CI launches the bundled app and opens every Settings tab, failing on any crash.

## [0.1.0-beta.1] - 2026-10-17

First public pre-release. Built and unit-tested on CI; UI features still need real-world testing — please report what misbehaves.

### Added
- Names, icons and colors for Spaces, shown in the menu bar, menu, Quick Switcher and spaces bar.
- Custom names inside Mission Control via Accessibility overlays (experimental).
- Quick Switcher (`⌥ Space`): fuzzy, accent-insensitive search, `1–9` jumps, best-match ranking, jump back on double press, `⇧↩` to move the front window.
- Per-Space hotkeys plus jump back, next, previous, rename and pause-tracking shortcuts.
- Drag to Move (`⇧` + drag) and Space Hover (notch / top edge) spaces bar.
- Move Front Window To… (menu and switcher).
- Notes and checklists per Space.
- On Click action groups (apps, files/folders, URLs, Apple Shortcuts, shell) with run-on-enter.
- Automatic time tracking per Space and app with idle detection, pause/resume, sessions and CSV export.
- Multi-display support, Launch at login, `macspacename://` URL scheme, config export/import.
- Makefile that produces a universal `.app`, CI and release workflows.
