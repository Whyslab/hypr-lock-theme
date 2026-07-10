#!/usr/bin/env bash
# switch-wallpaper.sh
# Переключает активные обои hyprlock между вариантами, лежащими в
# ~/.config/hypr/wallpapers/. Работает, просто копируя выбранный файл
# поверх current.png — hyprlock.conf всегда смотрит именно на current.png,
# поэтому конфиг менять не нужно.
set -euo pipefail

WALL_DIR="${HYPRLOCK_WALLPAPERS_DIR:-$HOME/.config/hypr/wallpapers}"
CURRENT="${WALL_DIR}/current.png"

mapfile -t WALLPAPERS < <(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -name 'current.png' | sort)

if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
    echo "В ${WALL_DIR} не найдено ни одного файла обоев." >&2
    exit 1
fi

usage() {
    echo "Доступные обои:"
    for i in "${!WALLPAPERS[@]}"; do
        printf '  [%d] %s\n' "$((i + 1))" "$(basename "${WALLPAPERS[$i]}")"
    done
    echo ""
    echo "Использование:"
    echo "  switch-wallpaper.sh <номер>       — выбрать по номеру из списка выше"
    echo "  switch-wallpaper.sh <имя_файла>    — выбрать по имени файла"
    echo "  switch-wallpaper.sh --next         — переключить на следующее по кругу"
    echo "  switch-wallpaper.sh --random       — выбрать случайное"
}

pick_by_index() {
    local idx=$1
    if (( idx < 1 || idx > ${#WALLPAPERS[@]} )); then
        echo "Неверный номер: $idx (доступно 1..${#WALLPAPERS[@]})" >&2
        exit 1
    fi
    echo "${WALLPAPERS[$((idx - 1))]}"
}

apply() {
    local src=$1
    cp -f "$src" "$CURRENT"
    echo "Активные обои: $(basename "$src")"
    # Если hyprlock уже заблокирован в данный момент — попросим его перечитать фон.
    if pidof hyprlock >/dev/null 2>&1; then
        pkill -SIGUSR2 hyprlock 2>/dev/null || true
    fi
}

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

case "$1" in
    --next)
        current_real=$(readlink -f "$CURRENT" 2>/dev/null || echo "")
        next_idx=0
        for i in "${!WALLPAPERS[@]}"; do
            if [[ "$(readlink -f "${WALLPAPERS[$i]}")" == "$current_real" ]]; then
                next_idx=$(( (i + 1) % ${#WALLPAPERS[@]} ))
                break
            fi
        done
        apply "${WALLPAPERS[$next_idx]}"
        ;;
    --random)
        apply "${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"
        ;;
    -h|--help)
        usage
        ;;
    ''|*[!0-9]*)
        # не число — считаем, что это имя файла
        match=""
        for w in "${WALLPAPERS[@]}"; do
            if [[ "$(basename "$w")" == "$1" ]]; then
                match="$w"
                break
            fi
        done
        if [[ -z "$match" ]]; then
            echo "Файл '$1' не найден в ${WALL_DIR}" >&2
            usage
            exit 1
        fi
        apply "$match"
        ;;
    *)
        apply "$(pick_by_index "$1")"
        ;;
esac
