#!/bin/bash
# Launch smoke test for the bundled app.
#
# Starts MacSpaceName.app, opens every Settings tab through the macspacename:// URL scheme and fails
# if the app dies at any point. On failure it prints the newest crash report and the app's log.
#
#   scripts/smoke-test.sh [path/to/MacSpaceName.app]

set -u
APP="${1:-dist/MacSpaceName.app}"
NAME="MacSpaceName"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

alive() { pgrep -x "$NAME" >/dev/null; }

fail() {
  echo "::error::$1"
  echo "----- newest crash report -----"
  latest=$(ls -t "$REPORTS"/"$NAME"* 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    echo "$latest"
    head -c 30000 "$latest"
    echo
  else
    echo "(none found in $REPORTS)"
  fi
  echo "----- app log (last 3 minutes) -----"
  log show --last 3m --style compact --predicate "process == \"$NAME\"" 2>/dev/null | tail -80
  pkill -x "$NAME" 2>/dev/null
  exit 1
}

# Number of normal (layer 0) on-screen windows owned by the app. Owner names need no Screen Recording permission.
window_count() {
  local dir script
  dir=$(mktemp -d)
  script="$dir/windows.swift"
  cat > "$script" <<'SWIFT'
import CoreGraphics
let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let mine = all.filter {
    ($0[kCGWindowOwnerName as String] as? String) == "MacSpaceName" && ($0[kCGWindowLayer as String] as? Int) == 0
}
print(mine.count)
SWIFT
  swift "$script" 2>/dev/null || echo 0
  rm -rf "$dir"
}

[ -d "$APP" ] || { echo "::error::$APP does not exist"; exit 1; }

pkill -x "$NAME" 2>/dev/null
rm -f "$REPORTS"/"$NAME"* 2>/dev/null
# Make sure LaunchServices routes macspacename:// to this copy of the app.
"$LSREGISTER" -f "$APP"

echo "==> launching $APP"
open "$APP" || fail "could not launch $APP"
for _ in $(seq 1 30); do alive && break; sleep 0.5; done
alive || fail "the app did not start"
sleep 3
alive || fail "the app crashed during launch"

for tab in general spaces shortcuts actions time about; do
  echo "==> macspacename://settings/$tab"
  open "macspacename://settings/$tab" || fail "could not open macspacename://settings/$tab"
  sleep 2
  alive || fail "the app crashed after opening Settings → $tab"
done

count=$(window_count)
echo "==> on-screen app windows: $count"
[ "$count" -ge 1 ] || fail "the Settings window never appeared, so the tabs were not really exercised"

echo "==> the app survived launch and every Settings tab"
pkill -x "$NAME" 2>/dev/null
exit 0
