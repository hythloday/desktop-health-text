# desktop-health-text

A transparent, borderless PC-health readout pinned to the top-right corner of the
KDE Plasma (Wayland) desktop. It renders [`fastfetch`](https://github.com/fastfetch-cli/fastfetch)
output — CPU/GPU/NVMe/PSU/WiFi sensors plus RAM, disk, load and uptime — inside a
chrome-less [Konsole](https://konsole.kde.org/) window, right-justified, with each
temperature — and a status dot beside it — coloured green / amber / red by threshold.

It's essentially a Conky-style overlay, but built from tools that work natively on
Wayland (no XWayland, no extra daemons) and styled to match Bazzite's `fastfetch`
aesthetic.

```
                              james@desktop
   CPU  AMD Ryzen 9 3950X (32) @ 4.76 GHz - 59.1°C  ●
   GPU  NVIDIA GeForce RTX 2080 Ti - 53.0°C [Discrete]  ●
                              NVMe sys   +64.8°C  ●
                              NVMe data  +29.9°C  ●
                                 PSU 12V  12.04 V
                                    WiFi  +65.0°C  ●
                  RAM   17.6 GiB / 62.7 GiB (28%)
        Disk  88.2 GiB / 3.64 TiB (2%) - btrfs
                        Load  0.28, 0.74, 0.87
                Uptime  1 day, 12 hours, 33 mins
       RAID  0.15% · 467M/s · 2 days 06:36:01 left
                              ● ● ● ● ● ● ● ●
```

## How it works

- **`desktop-health.sh`** — the refresh loop. Runs `fastfetch` (with `--pipe false`
  so colour is kept even though output is piped), pipes it through `awk` to, for each
  temperature line, colour the temperature **text** and append a status dot — both
  green/amber/red by the same per-sensor threshold — then right-justifies every row
  (so the dots line up at the far right) and redraws the frame every few seconds.
  Doing the colouring here is what lets `command`-based sensors (NVMe, WiFi) get the
  same treatment as the built-in CPU/GPU modules.
- **`health.jsonc`** — the `fastfetch` config: which modules/sensors are shown
  (logo disabled).
- **`raid-expand.sh`** — the `RAID` line's data source: reports a NAS's ZFS
  raidz-expansion progress (`zpool status` over SSH) as one compact
  `percent · rate · ETA` line. Because an SSH round-trip is slow relative to the
  5s refresh — and would stall the redraw if the box were down — it never blocks:
  it prints a cached answer instantly and, when stale, kicks off a detached
  background refresh, so the NAS is polled at most once every ~30s. Shows `idle`
  when no expansion is running and `complete` when one finishes. Drop this
  `command` module (and script) if you have no such pool to watch.
- **`Health.profile` + `HealthTransparent.colorscheme`** — a dedicated Konsole
  profile: Anonymice Nerd Font Mono, fully transparent background, no scrollbar.
- **`konsole-health/konsolerc`** — Konsole settings scoped to *this* window only
  (via a private `XDG_CONFIG_HOME`), so your normal Konsole keeps its menubar/tabbar.
- **`kwinrulesrc`** — a KWin window rule matching the window title `DesktopHealth`:
  borderless, keep-below, no taskbar/pager/switcher entry.
- **`snap-topright.js`** — a KWin script that snaps the content-sized window flush
  into the top-right corner of the work area.
- **`start-desktop-health.sh`** — launcher: opens the Konsole with the scoped config,
  then runs the snap script. Invoked at login by `desktop-health.desktop`.

## Requirements

- KDE Plasma 6 (Wayland) — KWin + Konsole
- `fastfetch`
- `lm_sensors` (`sensors`) — run `sudo sensors-detect` once if needed
- `gawk` (multibyte `length()` is required for correct alignment)
- `qdbus` (Qt 6) — used to drive KWin scripting
- `liquidctl` (in `~/.local/bin`) — only for the Coolant sensor (Corsair AIO liquid temp); drop that `command` module if you have no liquid cooler
- passwordless SSH (key-based, `BatchMode`) to the NAS — only for the `RAID` expansion line; drop that `command` module if you don't run a ZFS box
- NVIDIA driver if you want GPU temperature (read via `fastfetch`)
- **Anonymice Nerd Font** — installed separately (see below)

### Install the font

```sh
mkdir -p ~/.local/share/fonts/AnonymicePro
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/AnonymousPro.tar.xz \
  | tar -xJ -C ~/.local/share/fonts/AnonymicePro
fc-cache -f ~/.local/share/fonts
```

Profile font family: `AnonymicePro Nerd Font Mono`.

## Install

This repo uses the GNU Stow `--dotfiles` layout (`dot-config/` → `~/.config/`,
`dot-local/` → `~/.local/`).

```sh
cd ~/Projects/desktop-health-text
stow --dotfiles -t "$HOME" .
```

Then start it (or just log out and back in — `desktop-health.desktop` autostarts it):

```sh
~/.local/bin/start-desktop-health.sh
```

No Stow? Copy/symlink each file to the matching path under `~` manually — the repo
tree mirrors the destination layout (with `dot-` standing in for `.`).

## Customising

| Want to change… | Where |
|---|---|
| Which sensors are shown | `health.jsonc` |
| Refresh interval (default 5s) | `INTERVAL` in `desktop-health.sh` |
| Temperature colour/dot thresholds | the per-sensor `warn`/`hot` values in `desktop-health.sh` |
| Window position / corner | `snap-topright.js` |
| Right-edge margin | `TerminalColumns` in `Health.profile` (content width + margin) |
| Transparency | `Opacity` in `HealthTransparent.colorscheme` (0 = invisible, 1 = solid) |
| Borderless / keep-below / etc. | `kwinrulesrc` |

### Restarting it to see changes

```
pkill -f '/desktop-health.sh'
~/.local/bin/start-desktop-health.sh
```

### Temperature thresholds (default)

These colour both the temperature text and its dot.


| Sensor | green | amber | red |
|---|---|---|---|
| CPU / GPU | < 65°C | 65–80°C | ≥ 80°C |
| Coolant | < 50°C | 50–58°C | ≥ 58°C |
| NVMe | < 55°C | 55–70°C | ≥ 70°C |
| WiFi | < 60°C | 60–72°C | ≥ 72°C |

## Caveats

- **Hardware-specific sensors.** `health.jsonc` references chip names from *this*
  machine (`nvme-pci-0100`, `nvme-pci-0400`, `corsaircpro-hid-3-3`, `iwlwifi_1`).
  Run `sensors` on your own system and edit the `command` modules to match.
- **KDE may rewrite some files.** `kwinrulesrc` and `konsole-health/konsolerc` are
  KDE-managed; changing related settings via a KDE GUI rewrites the file with an
  atomic rename, which breaks a hardlink and replaces a Stow symlink. `kwinrulesrc`
  in particular is shared — if you add other window rules later, reconcile by hand.
- **Single virtual desktop.** The panel lives on the desktop it was launched on; it
  does not follow you across virtual desktops.
