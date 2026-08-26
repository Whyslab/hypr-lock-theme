#!/usr/bin/env bash
# lock-status-wifi.sh
# Печатает имя активной Wi-Fi сети и уровень сигнала. Используется в
# hyprlock.conf как text = cmd[update:8000] /путь/lock-status-wifi.sh
#
# Важно: --rescan no — опция подкоманды "device wifi list", а не глобальный
# флаг nmcli, поэтому обязана идти ПОСЛЕ неё. Обратный порядок — синтаксическая
# ошибка nmcli, из-за которой уровень сигнала молча не отображался.
# Без set -e: перебираем источники по очереди.
set -uo pipefail

# LC_ALL=C обязателен: скрипт разбирает числовой вывод сторонних утилит.
# В локали вроде ru_RU.UTF-8 они печатают дробное число через запятую,
# а bash printf %f в той же локали отказывается читать точку — из-за этой
# пары несовместимостей значения молча ломались.
export LC_ALL=C

# 1. NetworkManager — стандарт на большинстве Arch + Hyprland систем.
if command -v nmcli >/dev/null 2>&1; then
    ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | awk -F: '$2=="802-11-wireless" {print $1; exit}')

    if [[ -n "$ssid" ]]; then
        signal=$(nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null \
            | awk -F: '$1=="*" {print $2; exit}')
        if [[ -n "$signal" ]]; then
            printf '󰤨 %s (%s%%)\n' "$ssid" "$signal"
        else
            printf '󰤨 %s\n' "$ssid"
        fi
        exit 0
    fi
fi

# 2. iw — если NetworkManager не используется.
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
