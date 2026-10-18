<p align="center">
  <img src="docs/menu-mockup.svg" alt="MacSpaceName in the menu bar" width="720">
</p>

<h1 align="center">MacSpaceName</h1>

<p align="center">
  <strong>Name your macOS Spaces. See the name in the menu bar and in Mission Control. Jump to any Space by name.</strong><br>
  Free, open source, no telemetry. Slovenská verzia: <a href="README.sk.md">README.sk.md</a>
</p>

<p align="center">
  <a href="https://github.com/jakubfabrici/macspacename/actions/workflows/ci.yml"><img src="https://github.com/jakubfabrici/macspacename/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/jakubfabrici/macspacename/releases"><img src="https://img.shields.io/github/v/release/jakubfabrici/macspacename?include_prereleases&label=release" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT"></a>
</p>

---

macOS lets you create as many desktops ("Spaces") as you like, but it only ever calls them *Desktop 1*, *Desktop 2*, *Desktop 3*… MacSpaceName fixes that. It is a small menu bar app that gives every Space a **name, icon and color**, shows the current one where you can see it, and lets you **switch by name** with a Spotlight-style switcher.

It is an open-source take on the ideas behind the commercial [SpaceJump](https://www.getspacejump.com/) app, with every feature of that app and a few extras, built only with techniques that need **no SIP changes and no Dock injection**.

## Features

| | Feature | What it does |
|---|---|---|
| 🏷️ | **Names, icons, colors** | Give each Space a name (any text, diacritics welcome), an emoji or SF Symbol icon and a color. |
| 📍 | **Menu bar** | The current Space's icon and name live in the menu bar. Choose between *icon + name*, *name*, *icon* or *number + name*. |
| 🪟 | **Names in Mission Control** | Your custom names appear right on the Spaces bar in Mission Control — drawn as overlays, no code injected anywhere. *(experimental)* |
| ⚡ | **Quick Switcher** | `⌥ Space` opens a floating switcher. Type to filter (fuzzy, accent-insensitive), `↑ ↓` to move, `↩` to switch, `1–9` to jump, `Esc` to close. The best match is marked. |
| ↩️ | **Jump back** | Press the switcher shortcut twice, or a dedicated shortcut, to return to the previous Space. |
| ⌨️ | **Per-Space hotkeys** | Record a global shortcut for any Space. Plus next / previous / rename / pause-tracking shortcuts. |
| 🖱️ | **Drag to Move** | Hold `⇧ Shift` while dragging a window: a bar of Spaces drops down; hover a Space and the window travels there. |
| 🔔 | **Space Hover** | Rest the pointer on the camera notch (or the top centre of a display without a notch) to reveal all Spaces; click one to switch. |
| 📝 | **Notes & checklists** | Every Space has its own notes and a checklist. |
| ▶️ | **On Click automations** | Groups of actions — open apps, folders, URLs, run Apple Shortcuts or shell commands — from the menu bar or automatically when you enter a Space. |
| ⏱️ | **Time tracking** | Automatic per-Space and per-app timing with idle detection, pause/resume, named sessions and CSV export. All local. |
| 🖥️ | **Multiple displays** | Works with "Displays have separate Spaces" on or off; Spaces are grouped per display and numbered left-to-right like Mission Control does. |
| 🔄 | **Auto-update** *(extra)* | Checks GitHub Releases once a day, downloads the new build, verifies its SHA-256 checksum, swaps the app in place and relaunches. Manual check in the menu. |
| 🔗 | **URL scheme** *(extra)* | `open "macspacename://switch?name=Work"` from Shortcuts, Raycast, Alfred, scripts… |
| 📦 | **Export / import** *(extra)* | Everything lives in one JSON file you can back up or sync. |
| 🔁 | **Next / previous Space shortcuts** *(extra)* | Cycle through Spaces on the current display. |

Names persist across restarts (they are keyed by the Space's stable UUID). Works fully offline and never phones home.

## Install

### Download

1. Grab `MacSpaceName-<version>.dmg` from the [Releases](https://github.com/jakubfabrici/macspacename/releases) page (a `.zip` is there too).
2. Open the image and drag **MacSpaceName** to **Applications**.
3. The app is signed ad hoc, not notarized, so macOS blocks the first launch. Either run
   ```sh
   xattr -dr com.apple.quarantine /Applications/MacSpaceName.app
   ```
   or try to open it once, then go to *System Settings → Privacy & Security* and click **Open Anyway** (on macOS 14 and older, right-click → **Open** also works).
4. Launch it. It lives in the menu bar only (no Dock icon).

### Build from source

Requires Xcode 15+ (Swift 5.9) on macOS 13+.

```sh
git clone https://github.com/jakubfabrici/macspacename.git
cd macspacename
make install        # builds a universal MacSpaceName.app and copies it to /Applications
```

Other targets: `make bundle` (just build into `dist/`), `make run`, `make test`, `make zip`, `make dmg`, `make clean`. You can also open the folder in Xcode (`xed .`) and run the `MacSpaceName` scheme.

## First run

Switching Spaces needs the **Accessibility** permission (MacSpaceName presses the system's own Mission Control shortcuts for you). The first time you switch you will be asked to grant it:

*System Settings → Privacy & Security → Accessibility → enable MacSpaceName.*

Listing and naming Spaces, the menu bar display, notes, actions and time tracking work without it.

## Using it

### Rename a Space

* Click the menu bar item → **Rename “Desktop 2”…**, or
* use the **Rename current space** shortcut (record it in Settings → Shortcuts), or
* open **Settings → Spaces** to edit the name, icon, color, hotkey and automation of every Space at once.

Leave the name empty to go back to the default *Desktop N*.

### Switch Spaces

* Click a Space in the menu.
* `⌥ Space` → type part of the name → `↩`. Numbers work too (`3 ↩`). `⇧ ↩` moves the front window instead of switching.
* Per-Space shortcuts, next/previous shortcuts, Jump back.
* Hover the notch / top edge and click a pill.
* `open "macspacename://switch?name=Work"`.

### Move a window to another Space

* Hold `⇧` while dragging the window and hover a Space in the bar that appears, or
* menu → **Move Front Window To →** *Space*, or
* Quick Switcher with `⇧ ↩` (or the *move window* shortcut).

### Automations

**Settings → Actions**: create a group, add steps (open app, open file/folder, open URL, run Apple Shortcut, run shell command). Run it from the menu (**Run Actions ▸**) or pick it as the **On enter** action of a Space. To toggle a Focus mode when entering a Space, create an Apple Shortcut that sets the Focus and run it from a group.

### Time tracking

Tracking is on by default and fully local. Every change of Space or frontmost app starts a new entry; idle time (default 5 minutes without input) is removed automatically. Open **Time Tracking…** from the menu for totals per Space / app / session for today, this week or all time, pause/resume, name a session, export CSV or clear the log. Turn it off in **Settings → Time**.

### Keyboard shortcuts

| Shortcut | Action | Default |
|---|---|---|
| Open Quick Switcher | floating switcher; press again with an empty query to jump back | `⌥ Space` |
| Open Quick Switcher in *move window* mode | pick where the front window goes | — |
| Jump back | return to the previous Space | — |
| Next / Previous Space | cycle on the current display | — |
| Rename current Space | opens the rename prompt | — |
| Pause / resume tracking | toggles time tracking | — |
| Space “X” | jump straight to that Space (Settings → Spaces) | — |

Inside the Quick Switcher: `↑ ↓ / Tab` navigate · `↩` switch · `⇧ ↩` move window · `1–9` jump · `⌘ 1–9` jump even while typing · `Esc` close.

### Updates

The app checks GitHub Releases once a day (menu → **Check for Updates…** at any time). When a newer version exists you get a dialog with the release notes and **Install and Relaunch**: the zip is downloaded, verified against `SHA256SUMS.txt`, the bundle in `/Applications` is replaced and the app relaunches. Turn automatic checks or pre-releases off in *Settings → General → Updates*. Because builds are only ad-hoc signed, macOS may ask you to grant Accessibility again after an update (see [troubleshooting](docs/troubleshooting.md)).

## How it works (short version)

* **Reading Spaces** — the private `CGSCopyManagedDisplaySpaces` window-server call (the same one WhichSpace and Spaceman use) returns every display with its Spaces, their UUIDs and which one is current. The app re-reads it on space-change notifications, display changes, when `com.apple.spaces.plist` changes and every 5 s as a safety net.
* **Switching** — macOS has no public API for this, so the app triggers the system's own *Switch to Desktop N* / *Move left/right a space* shortcuts. They are disabled by default, so it reads their key binding from the window server, enables them for the instant of the synthetic key press and disables them again. Full-screen apps are reached by activating the app.
* **Mission Control names** — while Mission Control is open, the Dock (or WindowManager on newer systems) exposes the Spaces bar through Accessibility. The app reads the position of every thumbnail and places a small click-through overlay window above it.
* **Drag to Move** — macOS carries a window you are holding along when the Space changes; the app simply switches while you hold it.

The long version, with every private call explained, is in [docs/how-it-works.md](docs/how-it-works.md).

## Project status

Version 0.x. The code builds and its logic is unit-tested on GitHub's macOS runners, and the techniques are the ones proven by other open-source tools. Features marked *experimental* (Mission Control labels, Drag to Move, moving windows) depend on undocumented behaviour that Apple can change at any time. If something misbehaves on your Mac, please [open an issue](https://github.com/jakubfabrici/macspacename/issues) with your macOS version — it is a quick fix most of the time.

## Compared with SpaceJump

| | MacSpaceName | SpaceJump |
|---|---|---|
| Price | free, MIT | $9.99 |
| Source | open | closed |
| Names in menu bar / Mission Control / switcher | ✅ / ✅ (experimental) / ✅ | ✅ / ✅ / ✅ |
| Icons & colors | ✅ | ✅ |
| Quick Switcher, jump back, per-Space hotkeys | ✅ | ✅ |
| Drag to Move, Space Hover | ✅ | ✅ |
| Notes & checklists | ✅ | ✅ |
| On Click automations (apps, folders, Shortcuts, scripts) | ✅ | ✅ |
| Time tracking with idle detection & CSV | ✅ | ✅ |
| Multi-display | ✅ | ✅ |
| Auto-update | ✅ (GitHub Releases) | ✅ |
| URL scheme for scripting | ✅ | ✗ |
| Config export / import | ✅ | ✗ |
| Requires SIP off / Dock injection | no | no |

## Documentation

* [Features in detail](docs/features.md)
* [How it works](docs/how-it-works.md) — the private APIs, the switching trick, Mission Control overlays
* [URL scheme](docs/url-scheme.md)
* [Architecture & code map](docs/architecture.md)
* [Troubleshooting](docs/troubleshooting.md)
* [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

## Privacy

No analytics, no network access, no accounts. Configuration is stored in `~/Library/Application Support/MacSpaceName/config.json`, the time log in `timelog.json` next to it, keyboard shortcuts in the app's `UserDefaults`.

## Credits

* [SpaceJump](https://www.getspacejump.com/) for the feature set that inspired this project.
* [WhichSpace](https://github.com/gechr/WhichSpace) and [Spaceman](https://github.com/Jaysce/Spaceman) for showing how to read Spaces and trigger the system shortcuts.
* [Hammerspoon](https://github.com/Hammerspoon/hammerspoon) for the Mission Control accessibility tree.
* [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus for global hotkeys.

## License

[MIT](LICENSE) © Jakub Fabrici
