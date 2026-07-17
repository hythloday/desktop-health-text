#!/usr/bin/env bash
# Report the NAS's ZFS raidz-expansion progress as one compact line for the
# desktop-health panel. An SSH round-trip is slow relative to the panel's 5s
# refresh (and would stall the whole redraw if the box is unreachable), so we
# never block on it: this prints a cached answer instantly and, when that answer
# is stale, kicks off a detached background refresh that updates the cache for
# next time. Net effect — the NAS is polled at most once per MAXAGE seconds.
set -u

HOST="root@192.168.10.5"
POOL="datapool"
CACHE="${XDG_RUNTIME_DIR:-/tmp}/raid-expand-status"
LOCK="$CACHE.lock"
MAXAGE=30   # seconds before the cached status is considered stale

do_refresh() {
    # Serialise refreshes so overlapping panel ticks don't fan out SSH calls.
    exec 9>"$LOCK" || exit 0
    flock -n 9 || exit 0

    local raw status l2 pct rate eta
    raw="$(timeout 12 ssh -n -o BatchMode=yes -o ConnectTimeout=6 "$HOST" \
        "zpool status $POOL 2>/dev/null | grep -A1 'expand:'" 2>/dev/null)"

    if [ -z "$raw" ]; then
        # No 'expand:' line (and SSH failure looks the same) — nothing running.
        status="idle"
    elif printf '%s' "$raw" | grep -q 'in progress'; then
        l2="$(printf '%s\n' "$raw" | sed -n '2p')"
        pct="$(grep -oE '[0-9.]+% done' <<<"$l2" | grep -oE '[0-9.]+%')"
        rate="$(grep -oE 'at [0-9.]+[KMGTP]?/s' <<<"$l2" | awk '{print $2}')"
        eta="$(sed -E 's/.*done, (.*) to go.*/\1/' <<<"$l2")"
        status="${pct:-?} · ${rate:-?} · ${eta:-?} left"
    else
        status="complete"
    fi

    # Atomic replace so the panel never reads a half-written line.
    printf '%s\n' "$status" >"$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
}

if [ "${1:-}" = "__refresh" ]; then
    do_refresh
    exit 0
fi

# Refresh in a fully detached session if the cache is missing or stale. setsid
# + redirected fds keep the child off the panel's stdout pipe, so fastfetch sees
# EOF immediately instead of waiting for the SSH call to finish.
now="$(date +%s)"
mtime="$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)"
if [ ! -f "$CACHE" ] || [ "$(( now - mtime ))" -ge "$MAXAGE" ]; then
    setsid -f "$0" __refresh >/dev/null 2>&1 </dev/null || true
fi

if [ -f "$CACHE" ]; then
    cat "$CACHE"
else
    printf '…\n'   # first run, nothing cached yet
fi
