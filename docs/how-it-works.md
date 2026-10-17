# How MacSpaceName works

macOS has no public API for Spaces: you cannot list them, name them, or switch to one programmatically. Every Spaces utility therefore leans on a small set of private window-server calls and a few tricks. This document explains each one MacSpaceName uses, why, and what happens if Apple changes it.

Nothing here requires disabling System Integrity Protection, injecting code into the Dock, or any special entitlement. The only permission the app asks for is **Accessibility**.

## 1. Listing Spaces — `CGSCopyManagedDisplaySpaces`

Source: `Sources/MacSpaceName/System/PrivateAPI.swift`, `Sources/MacSpaceNameCore/SpaceParser.swift`

The window server (SkyLight, re-exported by CoreGraphics) exposes the private function

```c
CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);
```

It returns one dictionary per display:

```
{
  "Display Identifier": "Main"            // or the display UUID when "Displays have separate Spaces" is on
  "Current Space":      { "ManagedSpaceID": 4, "id64": 4, "type": 0, "uuid": "9C1D…" }
  "Spaces": [
    { "ManagedSpaceID": 4, "id64": 4, "type": 0, "uuid": "9C1D…" },           // type 0 = desktop
    { "ManagedSpaceID": 9, "id64": 9, "type": 4, "uuid": "…", "pid": 512 }    // type 4 = full-screen / Split View app
  ]
}
```

`SpaceParser` turns this into `SpaceSnapshot` → `DisplaySpaces` → `SpaceInfo`. Desktops are numbered globally in the order Mission Control uses (displays sorted left-to-right by their bounds, full-screen spaces skipped) so that "Desktop N" matches the *Switch to Desktop N* shortcut. The `uuid` of a desktop is stable across reboots, which is what all per-space data is keyed by.

`CGSCopyActiveMenuBarDisplayIdentifier` tells us which display currently owns the menu bar; its current space is "the" active space shown in the menu bar.

All private symbols are resolved at runtime with `dlsym`. If Apple ever removes one, the matching feature turns itself off instead of the app failing to launch.

### Keeping the list fresh

`SpaceMonitor` re-reads the list when any of these fire:

* `NSWorkspace.activeSpaceDidChangeNotification` (the user switched),
* `NSWorkspace.didActivateApplicationNotification` (full-screen apps),
* `NSApplication.didChangeScreenParametersNotification` (displays changed),
* the undocumented `NSWorkspaceActiveDisplayDidChangeNotification`,
* `~/Library/Preferences/com.apple.spaces.plist` being rewritten (adding/removing desktops in Mission Control does not post any notification, but it does rewrite this file),
* a 5-second timer as a safety net.

Reads are cheap (one IPC round trip), and the UI only updates when the snapshot actually changed.

## 2. Switching Spaces — the system's own shortcuts

Source: `Sources/MacSpaceName/Spaces/SpaceSwitcher.swift`

There is no supported way to change the current space. Private calls such as `CGSManagedDisplaySetCurrentSpace` exist, but they leave the Dock and Mission Control confused and have been broken repeatedly. The robust approach, used by WhichSpace, Spaceman and others, is to do what the user would do: press the Mission Control keyboard shortcuts.

macOS identifies these shortcuts by number in `com.apple.symbolichotkeys`:

| ID | Shortcut |
|---|---|
| 79 | Move left a space (`⌃←`) |
| 81 | Move right a space (`⌃→`) |
| 118 … 133 | Switch to Desktop 1 … 16 (`⌃1` …) |

Two problems and their solutions:

1. **The "Switch to Desktop N" shortcuts are disabled by default.** The window server offers `CGSIsSymbolicHotKeyEnabled` / `CGSSetSymbolicHotKeyEnabled`. MacSpaceName enables the needed shortcut, posts the key press, and disables it again 300 ms later. Your keyboard settings end up exactly as they were.
2. **The user may have rebound the keys.** `CGSGetSymbolicHotKeyValue` returns the current key code and modifiers, so the app always presses whatever the user configured. Only if that call is unavailable does it fall back to hard-coded `⌃1`–`⌃0` / `⌃←` / `⌃→`.

The key press itself is a `CGEvent` posted to the HID event tap — this is what needs the Accessibility permission.

Strategy per target:

* **Desktop with a number ≤ 16** → one direct *Switch to Desktop N* press (fast, works across displays).
* **Anything else, or "Step" mode in Settings** → repeated *Move left/right* presses (180 ms apart) on the target's display.
* **Full-screen app space** → `NSRunningApplication.activate()`; macOS brings the app's space forward itself.

## 3. Custom names inside Mission Control — Accessibility overlays

Source: `Sources/MacSpaceName/Features/MissionControlLabels.swift`

While Mission Control (or App Exposé) is open, the Dock process exposes its UI through the Accessibility API:

```
AXApplication (Dock)                     // com.apple.WindowManager on macOS 27+
└── AXGroup  id = "mc"
    └── AXGroup  id = "mc.display"       // one per display, has a frame
        └── AXGroup  id = "mc.spaces"
            ├── AXList  id = "mc.spaces.list"
            │   ├── AXButton  title = "Desktop 1"   // one per space, with position & size
            │   └── AXButton  title = "Desktop 2"
            └── AXButton  id = "mc.spaces.add"
```

(This is the same tree Hammerspoon's `hs.spaces` walks.) The app:

1. notices the Dock / WindowManager becoming the frontmost application (`didActivateApplicationNotification`, plus a cheap 0.5 s check),
2. polls the tree at 10 Hz while Mission Control is up and reads the frame of every space button,
3. matches `mc.display` frames to screens and buttons to `SpaceInfo` by position,
4. places a borderless, click-through `NSPanel` at the assistive-technology window level (above Mission Control) centred on each button that has a custom name, and
5. removes them the moment the tree disappears.

Only spaces with a custom name get an overlay; the others keep the system's "Desktop N" label. The Spaces bar changes size when you hover it (collapsed text ↔ thumbnails), which the 10 Hz polling follows.

This feature is marked **experimental** because the tree is undocumented. Turn it off in *Settings → General → Extras* if it misbehaves.

## 4. Drag to Move and moving windows

Source: `Sources/MacSpaceName/Features/SpacesBar.swift`, `Sources/MacSpaceName/Features/WindowMover.swift`

macOS has a little-known built-in behaviour: if you are holding a window with the mouse and the Space changes (via `⌃←/→` or `⌃N`), the window comes along. MacSpaceName builds on this instead of using the private `SLSMoveWindowsToManagedSpace` family, which Apple has been locking down since macOS 14.5.

* **Drag to Move** — a 15 Hz timer watches `NSEvent.pressedMouseButtons` and `NSEvent.modifierFlags` (no permissions, and it keeps working while the window server is moving a window for you). Left button + `⇧` → the spaces bar drops down from the top of the screen the pointer is on. Hover a pill for 250 ms and the app switches; the window you are holding follows.
* **Move Front Window To… / `⇧↩` in the Quick Switcher** — the app finds the focused window of the frontmost app through Accessibility, synthesises a mouse-down on its title bar, drags a few pixels so the window server starts a move, switches space, waits for the animation, releases, and puts the pointer back. It is a trick, so it is also marked experimental.

## 5. Space Hover

Source: `Sources/MacSpaceName/Features/SpacesBar.swift`

The same 15 Hz timer checks whether the pointer rests on the *hot zone*: on MacBooks with a notch that is exactly the notch area (`NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`); on other displays it is the top 2 px of the centre 30 % of the screen. After 250 ms the spaces bar appears below the menu bar; it hides 400 ms after the pointer leaves it.

## 6. Global shortcuts

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) registers Carbon hot keys, which need no permission. Per-space shortcuts use dynamic names (`space.<uuid>`), so they survive renames and reordering.

## 7. Time tracking and idle detection

Source: `Sources/MacSpaceName/Features/TimeTracker.swift`

Every change of active space or frontmost app closes the current `TimeEntry` and opens a new one. A 15-second timer extends the live entry and checks `CGEventSource.secondsSinceLastEventType` for keyboard/mouse activity. When the idle time passes the threshold (default 5 min) the live entry is cut back to the last input and tracking pauses until you are back. Entries are appended to `timelog.json` (pretty-printed JSON) and summed on demand; the CSV export is RFC 4180-style.

## 8. Data files

| File | Contents |
|---|---|
| `~/Library/Application Support/MacSpaceName/config.json` | names, icons, colors, notes, checklists, action groups, settings |
| `~/Library/Application Support/MacSpaceName/timelog.json` | time-tracking entries |
| `UserDefaults` (`io.github.jakubfabrici.MacSpaceName`) | keyboard shortcuts (managed by KeyboardShortcuts) |

Both JSON files are written atomically and decoded leniently (missing keys fall back to defaults), so upgrading never loses data.

## What could break, and how it fails

| Dependency | If Apple changes it | Effect |
|---|---|---|
| `CGSCopyManagedDisplaySpaces` | symbol missing / format changes | menu shows "Spaces are not readable"; nothing else crashes |
| Symbolic hot key calls | missing | falls back to hard-coded `⌃N` / `⌃arrows`; user must enable them in System Settings |
| Mission Control AX tree | identifiers change | labels simply do not appear |
| Window-follows-drag behaviour | removed | Drag to Move / move window do nothing |

Every private call is isolated in `PrivateAPI.swift`, so adapting to a new macOS release is a one-file change.
