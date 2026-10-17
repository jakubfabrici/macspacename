# Troubleshooting

### "MacSpaceName can't be opened because Apple cannot check it for malicious software"

The app is signed ad hoc, not notarized. Right-click → **Open**, or:

```sh
xattr -d com.apple.quarantine /Applications/MacSpaceName.app
```

### Clicking a Space does nothing

1. Grant **Accessibility**: System Settings → Privacy & Security → Accessibility → MacSpaceName. If it is already listed, toggle it off and on again (macOS sometimes keeps a stale entry after an update).
2. If you built from source and replaced the app, remove and re-add it in the same list — the permission is tied to the signature/path.
3. Switch *Settings → General → Switching* to **Step with Control + Arrow keys** to see whether the direct shortcuts are the problem.
4. Open *System Settings → Keyboard → Keyboard Shortcuts → Mission Control* and check that "Move left/right a space" are not disabled or rebound to something exotic.

### The menu says "Spaces are not readable on this macOS version"

The private `CGSCopyManagedDisplaySpaces` call could not be found. This happens only on a macOS release that removed or renamed it. Please [open an issue](https://github.com/jakubfabrici/macspacename/issues) with your macOS version.

### Names do not appear in Mission Control

* Accessibility must be granted.
* The feature is on by default; check *Settings → General → Extras*.
* Only Spaces with a custom name get a label.
* On a brand-new macOS version the Accessibility tree may have changed. Open an issue with the output of Accessibility Inspector on the Dock (or WindowManager) while Mission Control is open.

### Drag to Move does not appear

Hold `⇧` while the mouse button is down and move a little. The bar appears on the display the pointer is on. If `⇧` is used by the app you are dragging in (e.g. constrained drags in design tools), use *Move Front Window To* from the menu instead.

### Launch at login fails

`SMAppService` only works for apps inside an `.app` bundle outside the build folder. Use `make install` (or move the app to `/Applications`) and try again.

### Time tracking shows 0m

Check that tracking is enabled in *Settings → Time*, not paused (menu → Time Tracking), and that the idle threshold is not too low for the way you work.

### Reset everything

Quit the app and delete:

```sh
rm -rf ~/Library/Application\ Support/MacSpaceName
defaults delete io.github.jakubfabrici.MacSpaceName
```

### Collecting information for a bug report

* macOS version (`sw_vers`), Mac model, number of displays and whether *Displays have separate Spaces* is on.
* The app version (Settings → About).
* `log stream --predicate 'process == "MacSpaceName"'` while reproducing the problem.
