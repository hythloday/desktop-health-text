#!/usr/bin/env bash
# Desktop health monitor: renders the fastfetch health panel on a refresh loop.
# The window title "DesktopHealth" is what the KWin rule matches to pin it.

CONFIG="$HOME/.config/fastfetch/health.jsonc"
INTERVAL="${1:-5}"   # refresh seconds (default 5)

# Set a stable window/tab title so KWin can match this window.
printf '\033]0;DesktopHealth\007'
# Hide the cursor.
printf '\033[?25l'
# Restore cursor on exit.
trap 'printf "\033[?25h"' EXIT

while true; do
    # --pipe false forces colour codes even though our stdout is a pipe (awk),
    # which fastfetch would otherwise treat as non-interactive and render plain.
    raw="$(/usr/bin/fastfetch -c "$CONFIG" --pipe false 2>/dev/null)"
    # For each temperature line, append a status dot (green/amber/red) by
    # threshold; then right-justify every line (pad left so all rows share the
    # same right edge — which places the dots flush at the far right).
    out="$(printf '%s\n' "$raw" | awk '
        BEGIN { esc = sprintf("%c", 27); reset = esc "[0m" }
        # green < warn <= amber < hot <= red
        function dot(t, warn, hot,   c) {
            c = (t < warn) ? "92" : ((t < hot) ? "93" : "91")
            return " " esc "[1m" esc "[" c "m" "●" reset   # bold ●
        }
        {
            raw = $0
            s = $0
            gsub(esc "\\[[0-9;]*m", "", s)        # stripped copy for parsing/width
            add = 0

            # Last temperature value on the line (e.g. 78.8 from "... - 78.8°C").
            tmp = s; val = ""
            while (match(tmp, /[0-9]+(\.[0-9]+)?°C/)) {
                val = substr(tmp, RSTART, RLENGTH)
                tmp = substr(tmp, RSTART + RLENGTH)
            }
            if (val != "") {
                match(val, /[0-9]+(\.[0-9]+)?/); n = substr(val, RSTART, RLENGTH) + 0
                if      (s ~ /CPU/)  { raw = raw dot(n, 65, 80); add = 2 }
                else if (s ~ /GPU/)  { raw = raw dot(n, 65, 80); add = 2 }
                else if (s ~ /NVMe/) { raw = raw dot(n, 55, 70); add = 2 }
                else if (s ~ /WiFi/) { raw = raw dot(n, 60, 72); add = 2 }
            }

            line[NR] = raw
            vis[NR] = length(s) + add              # +2 visible cells for " ●"
            if (vis[NR] > max) max = vis[NR]
        }
        END {
            for (i = 1; i <= NR; i++) {
                pad = max - vis[i]
                p = ""
                while (length(p) < pad) p = p " "
                printf "%s%s\n", p, line[i]
            }
        }
    ')"
    # Home + full-screen clear + frame, in one write (no ghosting, no flicker).
    printf '\033[H\033[2J%s' "$out"
    sleep "$INTERVAL"
done
