#!/usr/bin/env bash
# lock-status-temp.sh
# Печатает температуру CPU. Используется в hyprlock.conf
# как text = cmd[update:5000] /путь/lock-status-temp.sh
#
# Без set -e: скрипт последовательно пробует несколько источников,
# и неудача раннего зонда не должна прерывать выполнение.
set -uo pipefail

# LC_ALL=C обязателен: скрипт разбирает числовой вывод сторонних утилит.
# В локали вроде ru_RU.UTF-8 они печатают дробное число через запятую,
# а bash printf %f в той же локали отказывается читать точку — из-за этой
# пары несовместимостей значения молча ломались.
export LC_ALL=C

# 1. lm_sensors: сначала общий датчик пакета, затем нулевое ядро.
if command -v sensors >/dev/null 2>&1; then
    out=$(sensors 2>/dev/null || true)

    temp=$(printf '%s\n' "$out" | awk '/Package id 0:/ {gsub(/[+°C]/, "", $4); print $4; exit}')
    [[ -z "$temp" ]] && temp=$(printf '%s\n' "$out" | awk '/^Core 0:/ {gsub(/[+°C]/, "", $3); print $3; exit}')

    if [[ -n "$temp" ]]; then
        printf '󰔏 %d°C\n' "$(awk -v v="$temp" 'BEGIN { printf "%d", int(v + 0.5) }')"
        exit 0
    fi
fi

# 2. Фолбэк для машин без lm_sensors: зона с типом x86_pkg_temp, иначе первая.
for zone in /sys/class/thermal/thermal_zone*; do
    [[ -r "$zone/temp" ]] || continue
    type=$(cat "$zone/type" 2>/dev/null || echo "")
    if [[ "$type" == "x86_pkg_temp" || "$type" == "cpu-thermal" ]]; then
        printf '󰔏 %d°C\n' "$(( $(cat "$zone/temp") / 1000 ))"
        exit 0
    fi
done

for zone in /sys/class/thermal/thermal_zone*; do
    [[ -r "$zone/temp" ]] || continue
    printf '󰔏 %d°C\n' "$(( $(cat "$zone/temp") / 1000 ))"
    exit 0
done

echo "󰔏 —"
