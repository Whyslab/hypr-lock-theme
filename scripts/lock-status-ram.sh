#!/usr/bin/env bash
# lock-status-ram.sh
# Печатает текущее использование RAM. Используется в hyprlock.conf
# как text = cmd[update:3000] /путь/lock-status-ram.sh
set -euo pipefail

read -r total used <<< "$(free -m | awk '/^Mem:/ {print $2, $3}')"

if [[ -z "${total:-}" || "$total" -le 0 ]]; then
    echo "󰍛 N/A"
    exit 0
fi

pct=$(( 100 * used / total ))
printf '󰍛 %s%% (%sG/%sG)\n' "$pct" "$(awk -v u="$used" 'BEGIN{printf "%.1f", u/1024}')" "$(awk -v t="$total" 'BEGIN{printf "%.1f", t/1024}')"
