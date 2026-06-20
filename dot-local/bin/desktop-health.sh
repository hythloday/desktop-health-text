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
    # For each temperature line: colour the temperature TEXT and append a status
    # dot, both green/amber/red by the same per-sensor threshold (fastfetch only
    # colours temps on built-in modules, and not consistently, so we do it here
    # uniformly). Then right-justify every line so all rows — and the dots —
    # share the same right edge.
    out="$(printf '%s\n' "$raw" | awk '
        BEGIN { esc = sprintf("%c", 27); reset = esc "[0m" }
        # green < warn <= amber < hot <= red
        function colour(t, warn, hot) {
            return (t < warn) ? "92" : ((t < hot) ? "93" : "91")
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

            warn = 0; hot = 0; has = 0
            if (val != "") {
                if      (s ~ /CPU/)  { warn = 65; hot = 80; has = 1 }
                else if (s ~ /GPU/)  { warn = 65; hot = 80; has = 1 }
                else if (s ~ /NVMe/) { warn = 55; hot = 70; has = 1 }
                else if (s ~ /WiFi/) { warn = 60; hot = 72; has = 1 }
            }

            if (has) {
                match(val, /[0-9]+(\.[0-9]+)?/); n = substr(val, RSTART, RLENGTH) + 0
                c = colour(n, warn, hot)
                # Recolour the temperature text: match any existing colour codes
                # right before the number (fastfetch may have coloured it), the
                # value and the degree unit; replace with our colour.
                re = "(" esc "\\[[0-9;]*m)*[+]?[0-9]+(\\.[0-9]+)?°C"
                if (match(raw, re)) {
                    before = substr(raw, 1, RSTART - 1)
                    mt     = substr(raw, RSTART, RLENGTH)
                    after  = substr(raw, RSTART + RLENGTH)
                    plain  = mt; gsub(esc "\\[[0-9;]*m", "", plain)
                    raw = before esc "[" c "m" plain reset after
                }
                raw = raw " " esc "[1m" esc "[" c "m" "●" reset   # bold dot, same colour
                add = 2
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
