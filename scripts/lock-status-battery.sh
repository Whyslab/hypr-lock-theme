#!/usr/bin/env bash
# lock-status-battery.sh
# Печатает уровень заряда батареи с иконкой, отражающей состояние.
# Если батареи нет (десктоп) — печатает пустую строку, label в hyprlock.conf
# просто не будет виден (hideOnEmpty-подобное поведение обеспечивается
# самим hyprlock: пустой text = пустой label).
set -uo pipefail

bat_path=""
for cand in /sys/class/power_supply/BAT*; do
    [[ -d "$cand" ]] || continue
    bat_path="$cand"
    break
done

if [[ -z "$bat_path" ]]; then
    echo ""
    exit 0
fi

capacity=$(cat "${bat_path}/capacity" 2>/dev/null || echo "")
status=$(cat "${bat_path}/status" 2>/dev/null || echo "Unknown")

[[ "$capacity" =~ ^[0-9]+$ ]] || { echo ""; exit 0; }

icon="󰁹"
if [[ "$status" == "Charging" ]]; then
    icon="󰂄"
elif (( capacity <= 15 )); then
    icon="󰁺"
elif (( capacity <= 40 )); then
    icon="󰁽"
elif (( capacity <= 70 )); then
    icon="󰂀"
fi

printf '%s %s%%\n' "$icon" "$capacity"
