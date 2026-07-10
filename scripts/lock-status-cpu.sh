#!/usr/bin/env bash
# lock-status-cpu.sh
# Печатает текущую загрузку CPU в процентах. Используется в hyprlock.conf
# как text = cmd[update:2000] /путь/lock-status-cpu.sh
set -euo pipefail

read -r _ u1 n1 s1 i1 w1 irq1 sirq1 _ < /proc/stat
sleep 0.35
read -r _ u2 n2 s2 i2 w2 irq2 sirq2 _ < /proc/stat

idle1=$((i1 + w1))
idle2=$((i2 + w2))
total1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1))
total2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2))

totald=$((total2 - total1))
idled=$((idle2 - idle1))

if (( totald <= 0 )); then
    usage=0
else
    usage=$(( (100 * (totald - idled)) / totald ))
fi

printf '󰻠 %s%%\n' "$usage"
