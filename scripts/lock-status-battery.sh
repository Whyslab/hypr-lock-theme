#!/usr/bin/env bash
# lock-status-battery.sh
# Печатает заряд батареи и состояние. Используется в hyprlock.conf
# как text = cmd[update:15000] /путь/lock-status-battery.sh
#
# Предпочитаем агрегат UPower DisplayDevice: на ноутбуках с двумя физическими
# батареями (например ThinkPad с BAT0+BAT1) выбор "первой попавшейся"
# /sys/class/power_supply/BAT* показывает заряд только одной из них.
# Без set -e — фолбэки должны отработать даже если ранний зонд упал.
set -uo pipefail

# LC_ALL=C обязателен: скрипт разбирает числовой вывод сторонних утилит.
# В локали вроде ru_RU.UTF-8 они печатают дробное число через запятую,
# а bash printf %f в той же локали отказывается читать точку — из-за этой
# пары несовместимостей значения молча ломались.
export LC_ALL=C

glyph_for() {
    case "$1" in
        charging|pending-charge) printf '󰂄' ;;
        fully-charged)           printf '󰁹' ;;
        *)
            local p="${2:-0}"
            if   (( p >= 80 )); then printf '󰂁'
            elif (( p >= 50 )); then printf '󰁿'
            elif (( p >= 20 )); then printf '󰁽'
            else                     printf '󰁻'
            fi
            ;;
    esac
}

# 1. UPower — корректно суммирует несколько батарей.
if command -v upower >/dev/null 2>&1; then
    info=$(upower -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null || true)
    if [[ -n "$info" ]]; then
        raw=$(printf '%s\n' "$info" | awk '/percentage:/ {print $2; exit}')
        state=$(printf '%s\n' "$info" | awk '/state:/ {print $2; exit}')
        if [[ -n "$raw" ]]; then
            # Запятая на случай, если утилита всё же локализовала вывод.
            raw="${raw//,/.}"; raw="${raw%\%}"
            # Округляем целочисленно, не полагаясь на printf %f.
            pct=$(awk -v v="$raw" 'BEGIN { printf "%d", int(v + 0.5) }')
            printf '%s %s%%\n' "$(glyph_for "${state:-unknown}" "$pct")" "$pct"
            exit 0
        fi
    fi
fi

# 2. Фолбэк на sysfs: суммируем ёмкости всех найденных батарей.
total=0; count=0; state="unknown"
for bat in /sys/class/power_supply/BAT*; do
    [[ -r "$bat/capacity" ]] || continue
    total=$(( total + $(cat "$bat/capacity") ))
    count=$(( count + 1 ))
    [[ "$state" == "unknown" && -r "$bat/status" ]] && state=$(tr '[:upper:]' '[:lower:]' < "$bat/status")
done

if (( count > 0 )); then
    pct=$(( total / count ))
    printf '%s %s%%\n' "$(glyph_for "$state" "$pct")" "$pct"
    exit 0
fi

# 3. Батареи нет вовсе — настольная машина. Печатаем пустую строку,
#    чтобы виджет на экране блокировки просто не занимал место.
echo ""
