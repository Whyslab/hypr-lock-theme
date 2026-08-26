#!/usr/bin/env bash
# lock-status-ram.sh
# Печатает занятую оперативную память. Используется в hyprlock.conf
# как text = cmd[update:3000] /путь/lock-status-ram.sh
#
# Считаем от MemAvailable, а не от голого "used": MemAvailable учитывает
# вытесняемый кэш, поэтому цифра отражает реальную нехватку памяти,
# а не забитый страничный кэш, который система отдаст по первому требованию.
set -euo pipefail

# LC_ALL=C обязателен: скрипт разбирает числовой вывод сторонних утилит.
# В локали вроде ru_RU.UTF-8 они печатают дробное число через запятую,
# а bash printf %f в той же локали отказывается читать точку — из-за этой
# пары несовместимостей значения молча ломались.
export LC_ALL=C

free -m | awk '
/^Mem:/ {
    total = $2
    avail = $7
    if (total <= 0) { print "󰍛 —"; exit }
    used = total - avail
    printf "󰍛 %.1f/%.1f GiB (%d%%)\n", used/1024, total/1024, int(used * 100 / total)
    exit
}'
