# Monochrome Vivid — a Hyprlock theme

*[Русская версия](README.ru.md)*

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?style=flat-square&logo=archlinux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58e1ff?style=flat-square&logo=hyprland&logoColor=black)
![Shell](https://img.shields.io/badge/Shell-4eaa25?style=flat-square&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)

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

Everything else (`hyprlock`, `hypridle`, the font, icon rendering, the Python libraries used to generate wallpapers) is installed by `install.sh`.

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

`update.sh` does not touch system packages — it only refreshes configuration files. If `colors.conf` or `hypridle.conf` differ from the project's copies (meaning you edited them), it asks before overwriting and always keeps the old version alongside with a `.bak-<date>` suffix. It never touches `avatar.png`.

## Uninstalling

```bash
./uninstall.sh
```

It asks for confirmation, removes the `exec-once = hypridle` line it added to `hyprland.conf` (backing that file up first), and offers to restore your configs from the backup `install.sh` made, if one is found under `~/.config/hypr/monochrome-vivid-backup-*`. System packages (`hyprlock`, `hypridle`, the font) are left alone — they are useful outside this theme.

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

## Contributing a screenshot

`hyprlock` takes over the whole display, so a screenshot has to be taken from a locked session by hand — for example with `grim` from a second TTY, or by photographing the screen. If you run this theme, a screenshot is the most useful thing you can contribute.

## Licence for wallpapers and icons

The wallpapers are generated locally by `generate_wallpapers.py` — original procedural content, nothing downloaded, no licensing questions. The icons in `icons/` are original SVGs drawn for this project.

## Licence

MIT — see [LICENSE](LICENSE).
