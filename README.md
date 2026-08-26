# Monochrome Vivid — a Hyprlock theme

*[Русская версия](README.ru.md)*

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?style=flat-square&logo=archlinux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58e1ff?style=flat-square&logo=hyprland&logoColor=black)
![Shell](https://img.shields.io/badge/Shell-4eaa25?style=flat-square&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)
[![CI](https://github.com/Whyslab/hypr-lock-theme/actions/workflows/ci.yml/badge.svg)](https://github.com/Whyslab/hypr-lock-theme/actions/workflows/ci.yml)

A minimal lock screen for Hyprland: deep black, greys, white accents. Nothing is coloured — every state (idle input, Caps Lock, wrong password) is signalled through the brightness and opacity of white rather than through hue. A frosted-glass card holds the avatar and password field, the wallpapers are generated procedurally at 4K, and a small system monitor sits on the lock screen itself.

> **Screenshot:** to be added — see [Contributing a screenshot](#contributing-a-screenshot).

## What's in it

- Large clock (`$TIME`) and a date in the system locale
- Circular avatar, `$USER`@hostname
- Keyboard layout indicator
- Password field signalling Caps Lock / Num Lock / failure through brightness, not colour
- Inline monitoring: CPU, RAM, temperature (where sensors exist), battery (on laptops), Wi-Fi
- Clickable power button
- Four procedurally generated monochrome 4K wallpapers plus a switcher script
- A fully configured `hypridle` chain: dim → lock → DPMS off → suspend
- `install.sh` / `update.sh` / `uninstall.sh`, all with backups

## Requirements

- Arch Linux (or a `pacman`-based derivative)
- Hyprland
- A regular user with `sudo` rights — do **not** run the installer as root

Everything else is installed by `install.sh`: `hyprlock`, `hypridle`, `brightnessctl`, `librsvg` (to render the SVG icons), the three Python libraries the wallpaper generator needs, and the JetBrainsMono Nerd Font the glyphs come from.

It installs only what the theme actually uses. `grim` is *not* installed — it is only useful if you want to contribute a screenshot, and that is your call, not the installer's.

## Installation

```bash
git clone https://github.com/Whyslab/hypr-lock-theme.git
cd hypr-lock-theme
chmod +x install.sh
./install.sh
```

The script asks two questions:

1. Whether to update the system first (`pacman -Syu`) — optional.
2. Whether to install `lm_sensors` for CPU temperature, if it isn't already present.

Everything after that is automatic: packages, font, a backup of your existing configs, wallpaper generation, icon rendering, building `hyprlock.conf` from the template, adding `hypridle` to autostart, and restarting `hypridle` for the current session.

At the end the script verifies its own work — configs are non-empty, wallpapers were generated, the monitoring scripts run without error, the `hyprlock` binary is on `PATH` — and prints a report.

**Try it:**

```bash
hyprlock
```

That genuinely locks the current session. Unlock with your normal user password.

## Project layout

```
hypr-lock-theme/
├── install.sh                    # clean install
├── uninstall.sh                  # full removal + optional restore from backup
├── update.sh                     # update an existing installation
├── hypr/
│   ├── hyprlock.conf.template    # hyprlock config template (__X__ placeholders)
│   ├── hypridle.conf             # hypridle config, copied as-is
│   └── colors.conf               # the palette — the only place to change colours
├── scripts/
│   ├── generate_wallpapers.py    # procedural 4K wallpaper generator (PIL/numpy/scipy)
│   ├── switch-wallpaper.sh       # switch between wallpapers
│   ├── lock-status-cpu.sh        # CPU load %
│   ├── lock-status-ram.sh        # RAM used, % and absolute
│   ├── lock-status-temp.sh       # CPU temp (lm_sensors → /sys/class/thermal → empty)
│   ├── lock-status-battery.sh    # battery charge (empty when there is no battery)
│   └── lock-status-wifi.sh       # current Wi-Fi SSID
├── wallpapers/                   # generator output: 4 variants + current.png
├── icons/
│   ├── user.svg                  # default avatar, used when ~/.face is absent
│   ├── power.svg                 # power button
│   └── lock.svg                  # decorative icon above the password field
└── assets/                       # empty in the repo — filled in by install.sh
```

### Where things get installed

| From the project | Installed to |
|---|---|
| `hypr/hyprlock.conf.template` (after path substitution) | `~/.config/hypr/hyprlock.conf` |
| `hypr/hypridle.conf` | `~/.config/hypr/hypridle.conf` |
| `hypr/colors.conf` | `~/.config/hypr/colors.conf` |
| `scripts/*.sh` | `~/.config/hypr/scripts/` |
| wallpapers from `generate_wallpapers.py` | `~/.config/hypr/wallpapers/` |
| `icons/*.svg`, rendered to PNG | `~/.config/hypr/assets/` |

`hyprlock.conf` refers to all of these by absolute path inside `~/.config/hypr/…`, so the project directory is no longer needed after installation — though keeping it around does no harm.

## Configuration

### Colours

All of them live in `~/.config/hypr/colors.conf`. To make the accent slightly dimmer:

```
$c_white = rgba(240, 240, 242, 1.0)   # change it here
```

Save the file — `hyprlock` re-reads its config on the next lock, so nothing needs restarting.

### Wallpapers

```bash
~/.config/hypr/scripts/switch-wallpaper.sh            # list the variants
~/.config/hypr/scripts/switch-wallpaper.sh 3          # pick variant 3
~/.config/hypr/scripts/switch-wallpaper.sh --random   # random
~/.config/hypr/scripts/switch-wallpaper.sh --next     # next in the cycle
```

To add your own, drop a `.png`/`.jpg` into `~/.config/hypr/wallpapers/` — it shows up in the switcher automatically, listed under its filename.

To regenerate the four defaults at a different resolution:

```bash
python3 scripts/generate_wallpapers.py --width 2560 --height 1440
```

### Font

The default is `JetBrainsMono Nerd Font`, needed for the CPU/RAM/battery/Wi-Fi glyphs. To change it:

1. Install the font (`pacman`, the AUR, or manually).
2. In `~/.config/hypr/colors.conf` set:
   ```
   $font = Your Font Nerd Font
   ```

If the replacement is not a Nerd Font, those glyphs render as empty boxes. Browse the options at <https://www.nerdfonts.com>.

### Avatar

`install.sh` uses `~/.face` when it exists, and draws a placeholder otherwise. To set your own photo at any point:

```bash
cp myphoto.png ~/.config/hypr/assets/avatar.png
```

A square image works best — it gets cropped to a circle.

### Idle and suspend timings (hypridle)

All of it sits in the variables at the top of `~/.config/hypr/hypridle.conf`:

```
$dim_timeout     = 150   # dim the backlight
$lock_timeout    = 300   # lock the screen
$dpms_timeout    = 330   # turn the monitor off
$suspend_timeout = 1200  # suspend
```

Values are in seconds. Change and save — `hypridle` picks them up after a restart (`pkill hypridle && setsid hypridle &`, or just log back in).

### Power button

Clicking the power icon runs `systemctl poweroff` by default. To change or remove that, edit `~/.config/hypr/hyprlock.conf`: find the `image` block whose `path` points at `power.png` and change or delete its `onclick` line.

### Keyboard layout

The `$LAYOUT[EN,RU]` indicator in `hyprlock.conf` assumes your `hyprland.conf` lists layouts as `kb_layout = us,ru` — English first. Check with:

```bash
grep kb_layout ~/.config/hypr/hyprland.conf
```

If your order differs, reorder the arguments in `$LAYOUT[…]` to match.

## Updating

After pulling a newer version of the project:

```bash
cd hypr-lock-theme
./update.sh
```

`update.sh` does not touch system packages — it only refreshes configuration files, and it never overwrites something you edited without asking first.

For `colors.conf`, `hypridle.conf` and every script under `scripts/`, it compares your installed copy against the project's. If they match, it moves on. If they differ — meaning you changed something — it says so, asks whether to overwrite, and only if you agree does it write, keeping your version alongside as `<name>.bak-<timestamp>`. It never touches `avatar.png`.

> Earlier versions copied the monitoring scripts over unconditionally, with no backup and no prompt. If you had tuned them for your own hardware, an update silently threw that away. That is fixed — but it is why the first thing this project's own history does is back things up.

## Uninstalling

```bash
./uninstall.sh
```

It asks for confirmation, then — before deleting anything — copies every file it is about to remove into `~/.config/hypr/monochrome-vivid-removed-<timestamp>/`. That snapshot is taken from the current state, so any customisation you made after installing survives even if the original `install.sh` backup is long gone.

It then removes the theme's files, strips the `exec-once = hypridle` line it added to `hyprland.conf` (backing that file up first), and offers to restore your pre-theme configs from `~/.config/hypr/monochrome-vivid-backup-*` if one is found. System packages (`hyprlock`, `hypridle`, the font) are left alone — they are useful outside this theme.

## Restoring a backup by hand

Before its first install, if `install.sh` finds existing configs, it saves them to:

```
~/.config/hypr/monochrome-vivid-backup-<date_time>/
```

To restore manually:

```bash
cp ~/.config/hypr/monochrome-vivid-backup-*/hyprlock.conf ~/.config/hypr/hyprlock.conf
cp ~/.config/hypr/monochrome-vivid-backup-*/hypridle.conf ~/.config/hypr/hypridle.conf
```

Same idea for `scripts/`, `wallpapers/` and `assets/` if you need them.

## Troubleshooting

**`hyprlock` logs complain about an unknown config key (e.g. `grace` or `onclick`)**

Different `hyprlock` versions support slightly different key sets — `onclick` in particular is fairly recent. Open `~/.config/hypr/hyprlock.conf`, find the offending line and delete it; the rest of the config keeps working and you only lose that one feature (a clickable power button, say). While you are there:

```bash
sudo pacman -Syu hyprlock hypridle
```

**No CPU temperature**

Either `lm_sensors` isn't installed, or `sensors-detect` was never run:

```bash
sudo pacman -S lm_sensors
sudo sensors-detect --auto
```

If it is still blank, `lm_sensors` may simply not find a usable sensor on your hardware — that is a hardware/driver limitation, not a theme one.

**No Wi-Fi shown, or always "Offline"**

The script uses `nmcli` (NetworkManager), then falls back to `iw`. On a different network manager (`iwd` directly, `systemd-networkd`, …), edit `~/.config/hypr/scripts/lock-status-wifi.sh` to use your tool.

**Keyboard layout shows the wrong thing, or nothing**

See [Keyboard layout](#keyboard-layout) above — check the `kb_layout` order against the order in `$LAYOUT[…]`.

**Num Lock indicator behaves oddly (sticks, or never updates)**

Num Lock state detection has historically been a little unreliable in some `hyprlock` versions. If it bothers you, set `$c_num_ring` equal to `$c_idle_ring` in `colors.conf` to neutralise the effect, or set `numlock_color = -1` in `hyprlock.conf` to disable the Num Lock reaction entirely.

**The avatar is just a grey circle**

`~/.face` was not found and `install.sh` generated a placeholder. See [Avatar](#avatar) above.

**Changes to `hyprlock.conf` are not applying**

Test the config directly before trusting autostart:

```bash
hyprlock --config ~/.config/hypr/hyprlock.conf
```

On a syntax error `hyprlock` usually warns in the logs (`journalctl --user -b | grep -i hyprlock`, or straight to the terminal when run by hand) but carries on with whatever it managed to parse.

**The screen never locks on its own**

Check that `hypridle` is actually running:

```bash
pidof hypridle || echo "not running"
```

If it isn't, confirm `~/.config/hypr/hyprland.conf` contains `exec-once = hypridle` (installed by `install.sh`) and log back in.

## Continuous integration

Four checks run on every push:

* **Shell** — `bash -n` on every script, then ShellCheck at `style` severity (the strictest level, and currently clean).
* **Python** — `ruff` over the wallpaper generator.
* **Test suite** — `tests/run-tests.sh`, 35 assertions: every monitoring script is executed and checked for a single well-formed line of output, the wallpaper generator is run and its output verified to be strictly grayscale, the declared package list is checked against actual usage, and the whole set is re-run under `ru_RU.UTF-8` as a regression guard (see below).
* **Template placeholders** — `hyprlock.conf.template` carries `__PLACEHOLDER__` tokens that `install.sh` and `update.sh` each substitute from their own list. Add a token to the template and forget it in one of the scripts and you get a config containing a literal `__SCRIPT_WIFI__` path: hyprlock starts, and that one widget silently does nothing. The check asserts both scripts cover exactly the token set the template uses.

The locale test exists because of a real bug. The monitoring scripts parse numbers out of `sensors`, `upower` and `free` — and in a locale like `ru_RU.UTF-8` those tools print `98,6419%` with a comma, while bash's `printf %f` in that same locale refuses to read a dot. The scripts converted comma to dot, `printf` then rejected it, and its `|| echo 0` fallback concatenated onto the partial output: the battery widget displayed `980%`. Every script now pins `LC_ALL=C` before parsing, and the suite runs them under a comma locale to keep it that way.

---

## Contributing a screenshot

`hyprlock` takes over the whole display, so a screenshot has to be taken from a locked session by hand — for example with `grim` from a second TTY, or by photographing the screen. If you run this theme, a screenshot is the most useful thing you can contribute.

## Licence for wallpapers and icons

The wallpapers are generated locally by `generate_wallpapers.py` — original procedural content, nothing downloaded, no licensing questions. The icons in `icons/` are original SVGs drawn for this project.

## Licence

MIT — see [LICENSE](LICENSE).
