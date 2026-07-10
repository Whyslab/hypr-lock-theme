#!/usr/bin/env bash
# lock-status-temp.sh
# Печатает температуру CPU, если её можно получить. Используется в hyprlock.conf
# как text = cmd[update:5000] /путь/lock-status-temp.sh
# Пытается lm_sensors, затем /sys/class/thermal, иначе тихо ничего не печатает
# (label в hyprlock просто останется пустым, что уместно для машин без датчиков).
set -uo pipefail

# 1. lm_sensors (samый точный источник, если установлен пакет lm_sensors и sensors-detect был запущен)
if command -v sensors >/dev/null 2>&1; then
    t=$(sensors 2>/dev/null | grep -m1 -Eo '\+[0-9]+\.[0-9]+°C' | head -n1 | tr -d '+')
    if [[ -n "$t" ]]; then
        printf '󰔏 %s\n' "$t"
        exit 0
    fi
fi

# 2. /sys/class/thermal (почти всегда доступно, но зона 0 не всегда это CPU package)
if [[ -d /sys/class/thermal ]]; then
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [[ -f "$zone" ]] || continue
        raw=$(cat "$zone" 2>/dev/null || echo "")
        [[ "$raw" =~ ^[0-9]+$ ]] || continue
        printf '󰔏 %s°C\n' "$(( raw / 1000 ))"
        exit 0
    done
fi

# 3. Ничего не нашли — просто пусто, без ошибок и мусора на экране
echo ""
