#!/usr/bin/env bash
# lock-status-wifi.sh
# Печатает имя текущей Wi-Fi сети (SSID). Используется в hyprlock.conf
# как text = cmd[update:5000] /путь/lock-status-wifi.sh
set -uo pipefail

# 1. NetworkManager (стандарт на большинстве Arch + Hyprland окружений)
if command -v nmcli >/dev/null 2>&1; then
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes" {print $2; exit}')
    if [[ -n "$ssid" ]]; then
        printf '󰤨 %s\n' "$ssid"
        exit 0
    fi
fi

# 2. iw (более низкоуровневый, если NetworkManager не используется)
if command -v iw >/dev/null 2>&1; then
    iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}')
    if [[ -n "$iface" ]]; then
        ssid=$(iw dev "$iface" link 2>/dev/null | awk -F': ' '/SSID/ {print $2; exit}')
        if [[ -n "$ssid" ]]; then
            printf '󰤨 %s\n' "$ssid"
            exit 0
        fi
    fi
fi

echo "󰤭 Offline"
