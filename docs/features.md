# Features in detail

A tour of everything MacSpaceName can do, where to find it, and how it compares with SpaceJump.

## Naming Spaces

* **Where:** menu bar → *Rename “…”…*, the *Rename current space* shortcut, the `macspacename://rename` URL, or *Settings → Spaces*.
* Names can be anything, including emoji and diacritics ("Práca", "日本語").
* An empty name restores the default *Desktop N*.
* Names are keyed by the Space's UUID, so they survive restarts, reordering and renumbering. If you delete a Space its entry stays in `config.json` (harmless; you can remove it by importing an edited file).
* Full-screen apps are listed under their app name (e.g. *Safari (Full Screen)*) and cannot be renamed.

## Icons and colors

* **Where:** *Settings → Spaces*.
* The icon field accepts an emoji (💼) or an SF Symbol name (`briefcase.fill`). The menu next to it offers suggestions.
* Colors come from the color picker or the preset palette. A Space with a color but no icon shows a colored dot.
* Icons and colors show in the menu bar, the menu, the Quick Switcher, the spaces bar and the Mission Control labels.

## Menu bar item

* Shows the active Space on the display that owns the menu bar.
* *Settings → General → Menu bar* chooses the style: icon + name, name only, icon only, number + name.
* Hovering the item shows the display and today's tracked time.
* The menu lists every display and its Spaces (✓ marks the current one), with rename, Quick Switcher, Jump Back, Move Front Window To, Notes, Run Actions, Time Tracking, Settings and Quit.

## Names in Mission Control (experimental)

Open Mission Control (F3, `⌃↑` or the trackpad gesture): Spaces with a custom name get a dark pill with the icon and name on the Spaces bar, both in the collapsed state and over the expanded thumbnails. Disable in *Settings → General → Extras*. Needs Accessibility.

## Quick Switcher

* **Default shortcut:** `⌥ Space` (change it in *Settings → Shortcuts*).
* A floating, non-activating panel in the middle of the screen with the pointer.
* Typing filters with a ranked matcher: exact name > prefix > word prefix > substring > fuzzy subsequence. Case and accents are ignored, so `praca` finds *Práca*. Typing a desktop number matches that desktop.
* The top result is labelled **Best match**; the current Space is labelled **current**.
* Keys: `↑ ↓` or `Tab`/`⇧Tab` move, `↩` switches, `⇧↩` moves the front window, `1–9` jumps while the query is empty, `⌘1–9` jumps any time, `Esc` closes. Clicking a row works too.
* Pressing the switcher shortcut while it is open with an empty query **jumps back** to the previous Space.
* A second shortcut opens it directly in *move window* mode.

## Jump back

The app remembers the previously active Space. *Jump Back* in the menu, its own shortcut, the double-press of the switcher shortcut or `macspacename://back` return there.

## Per-Space hotkeys and other shortcuts

Record them in *Settings → Spaces* (per Space) and *Settings → Shortcuts* (switcher, move-window switcher, jump back, next, previous, rename, pause tracking). Shortcuts are global and need no permission.

## Drag to Move

Hold `⇧` while dragging any window. A bar with the Spaces of that display slides down from the top edge; keep the pointer over a Space for a quarter second and macOS carries the window there. Release to finish. Disable in *Settings → General → Extras*.

## Space Hover

Let the pointer rest on the notch (or the top centre of a display without one) for a quarter second and the same bar appears; click a Space to switch. Disable in *Settings → General → Extras*.

## Move the front window

Menu → *Move Front Window To* → Space, or `⇧↩` in the Quick Switcher. See [how it works](how-it-works.md#4-drag-to-move-and-moving-windows). Experimental.

## Notes and checklists

Menu → *Notes for “…”…* (or the Notes… button in *Settings → Spaces*) opens a window with free-form notes and a checklist for the chosen Space. Everything is saved to `config.json` as you type.

## On Click automations

*Settings → Actions* manages **groups** of steps:

| Step | Value | Runs |
|---|---|---|
| Open app | name or path (`Safari`, `/Applications/Safari.app`) | `open -a` |
| Open file or folder | path, `~` allowed | Finder / default app |
| Open URL | `https://…` | default browser / handler |
| Run Apple Shortcut | Shortcut name | `shortcuts run "name"` |
| Run shell command | any command | `/bin/zsh -lc` |

Run a group from the menu (*Run Actions ▸ ▶ name*), the *Run now* button, `macspacename://run?group=name`, or automatically by selecting it as a Space's **On enter** action. On-enter groups run only on real switches, not at launch.

## Time tracking

* On by default; turn off in *Settings → Time*.
* One entry per (Space, frontmost app) interval. Idle time beyond the threshold (1–60 min, default 5) is removed.
* *Time Tracking…* window: totals for today / this week / all time, grouped by Space, app or session; live status (Tracking / Paused / Idle / Off); pause/resume; session name field (tags new entries); CSV export; clear log.
* Menu → *Time Tracking* shows today's total and pause/resume.
* CSV columns: `start,end,duration_seconds,space,space_key,app,app_bundle_id,session`.

## Multiple displays

* With *Displays have separate Spaces* **on**, each display has its own list, headed by the display name in the menu and Settings. The menu bar shows the Space of the display that has the menu bar focus.
* With it **off**, all displays share one list, reported as display "Main".
* Direct switching (*Switch to Desktop N*) works across displays; step switching is limited to the current display.

## Auto-update

* Once a day (first check a minute after launch) the app asks the GitHub Releases API for the newest version; pre-releases are included by default while the project is in beta (*Settings → General → Updates*).
* A newer version shows a dialog with the release notes: **Install and Relaunch**, **Later**, **Skip This Version**, **View on GitHub**.
* Installing downloads `MacSpaceName-<version>.zip`, verifies it against `SHA256SUMS.txt`, extracts it with `ditto`, checks the bundle identifier, moves the running bundle aside, puts the new one at the same path and relaunches once the old process has exited.
* If the app is not running from a writable `.app` location (for example a `swift run` binary), the dialog simply opens the release page instead.
* Menu → **Check for Updates…** runs a manual check and reports "up to date" or errors.

## URL scheme

See [url-scheme.md](url-scheme.md).

## Settings → General

Launch at login, menu bar style, numbers in lists, full-screen apps in lists, switching method (direct or step-only), Accessibility status, the three experimental extras, and config export / import / reveal.

## Feature comparison with SpaceJump

| Feature | SpaceJump | MacSpaceName |
|---|---|---|
| Name / icon / color per Space | ✅ | ✅ |
| Name in menu bar | ✅ | ✅ |
| Name in Mission Control | ✅ | ✅ experimental |
| Quick Switcher (`⌘0` / `⌥Space`), type to filter, 1–9, Best match | ✅ | ✅ |
| Jump back (double press + shortcut) | ✅ | ✅ |
| Per-Space hotkeys | ✅ | ✅ |
| Drag to Move (⇧ + drag) | ✅ | ✅ |
| Space Hover (notch) | ✅ | ✅ |
| Notes & checklists | ✅ | ✅ |
| On Click automations: apps, folders, Shortcuts, scripts | ✅ | ✅ (+ URLs) |
| Automations on entering a Space | ✅ | ✅ |
| Time tracking, idle detection, pause/resume, named sessions, CSV | ✅ | ✅ |
| External / multiple displays | ✅ | ✅ |
| Works offline, no data collection | ✅ | ✅ |
| No SIP change, no Dock injection | ✅ | ✅ |
| Auto-update | ✅ | ✅ (GitHub Releases, checksum-verified) |
| Homebrew install | ✅ | planned |
| Next / previous Space shortcuts | ✗ | ✅ |
| URL scheme for scripting | ✗ | ✅ |
| Config export / import | ✗ | ✅ |
| Open source, free | ✗ | ✅ |
