#!/usr/bin/env bash
# lock-status-cpu.sh
# Печатает текущую загрузку CPU в процентах. Используется в hyprlock.conf
# как text = cmd[update:2000] /путь/lock-status-cpu.sh
#
# Дельта между вызовами хранится в файле состояния, поэтому в типичном случае
# скрипт не блокируется: hyprlock вызывает его каждые 2 с, и разница берётся
# между соседними вызовами. Только на первом запуске (файла ещё нет) делается
# одно короткое измерение через sleep, чтобы сразу показать реальное число,
# а не прочерк.
set -euo pipefail

# LC_ALL=C обязателен: скрипт разбирает числовой вывод сторонних утилит.
# В локали вроде ru_RU.UTF-8 они печатают дробное число через запятую,
# а bash printf %f в той же локали отказывается читать точку — из-за этой
# пары несовместимостей значения молча ломались.
export LC_ALL=C

STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-lock-theme-cpu.prev"

read_stat() {
    # shellcheck disable=SC2034
    read -r _ user nice sys idle iowait irq softirq _ < /proc/stat
    echo "$user $nice $sys $idle $iowait $irq $softirq"
}

usage_between() {
    local -a a b
    read -r -a a <<< "$1"
    read -r -a b <<< "$2"

    local idle_a=$(( a[3] + a[4] ))
    local idle_b=$(( b[3] + b[4] ))
    local total_a=$(( a[0] + a[1] + a[2] + a[3] + a[4] + a[5] + a[6] ))
    local total_b=$(( b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] ))

    local dtotal=$(( total_b - total_a ))
    local didle=$(( idle_b - idle_a ))

    if (( dtotal <= 0 )); then
        echo 0
        return
    fi

    local pct=$(( (100 * (dtotal - didle)) / dtotal ))
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    echo "$pct"
}

now=$(read_stat)

if [[ -r "$STATE" ]]; then
    prev=$(cat "$STATE")
else
    # Первый запуск: одно измерение на месте, чтобы не показывать прочерк.
    prev="$now"
    sleep 0.35
    now=$(read_stat)
fi

printf '󰻠 %s%%\n' "$(usage_between "$prev" "$now")"

# umask 077 — файл состояния лежит в runtime-каталоге пользователя (0700),
# но на случай фолбэка в /tmp явно закрываем права.
( umask 077; printf '%s\n' "$now" > "$STATE" )
