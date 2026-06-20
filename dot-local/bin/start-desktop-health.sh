#!/usr/bin/env bash
# Launches the health panel in its own Konsole (scoped chrome config) and then
# re-applies KWin rules so the window snaps to its pinned top-right position
# (Konsole's initial placement otherwise wins a race against the position rule).

# Don't start a second copy if one is already running.
if pgrep -f 'desktop-health.sh' >/dev/null 2>&1; then
    exit 0
fi

XDG_CONFIG_HOME="$HOME/.config/konsole-health" \
    setsid konsole --separate --profile Health \
    -e "$HOME/.local/bin/desktop-health.sh" >/dev/null 2>&1 </dev/null &

# Give Konsole time to map, re-apply the pin rule (noborder/keep-below), then
# snap the content-sized window flush into the top-right corner.
sleep 2
qdbus org.kde.KWin /KWin reconfigure 2>/dev/null \
    || dbus-send --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null

SNAP="$HOME/.local/share/desktop-health/snap-topright.js"
sid=$(qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$SNAP" 2>/dev/null)
if [ -n "$sid" ]; then
    qdbus "org.kde.KWin" "/Scripting/Script$sid" org.kde.kwin.Script.run 2>/dev/null
    qdbus "org.kde.KWin" "/Scripting/Script$sid" org.kde.kwin.Script.stop 2>/dev/null
fi
