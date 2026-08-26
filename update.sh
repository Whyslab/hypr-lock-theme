#!/usr/bin/env bash
# update.sh — обновляет уже установленную тему Monochrome Vivid новой версией
# файлов из этого каталога проекта, БЕЗ повторной установки системных пакетов.
# Используй после `git pull` / скачивания новой версии проекта.

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "\n${BLUE}==>${NC} $1"; }

trap 'log_err "Обновление прервано на строке $LINENO (код $?)."; exit 1' ERR

if [[ $EUID -eq 0 ]]; then
    log_err "Не запускай update.sh от root."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/hypr"
SCRIPTS_DIR="${CONFIG_DIR}/scripts"
WALLPAPERS_DIR="${CONFIG_DIR}/wallpapers"
ASSETS_DIR="${CONFIG_DIR}/assets"
HOSTNAME_VAL="$(hostname)"

if [[ ! -f "${CONFIG_DIR}/hyprlock.conf" ]]; then
    log_warn "Не вижу установленной темы (${CONFIG_DIR}/hyprlock.conf отсутствует)."
    log_warn "Похоже, тема ещё не установлена — используй ./install.sh вместо update.sh."
    exit 1
fi

mkdir -p "$SCRIPTS_DIR" "$WALLPAPERS_DIR" "$ASSETS_DIR"

# ---------------------------------------------------------------------------
# 1. colors.conf — не перезаписываем молча, если пользователь его менял
# ---------------------------------------------------------------------------
log_step "Палитра"
if ! diff -q "${PROJECT_DIR}/hypr/colors.conf" "${CONFIG_DIR}/colors.conf" >/dev/null 2>&1; then
    log_warn "Твой colors.conf отличается от версии в проекте (похоже, ты его менял)."
    read -r -p "Перезаписать твой colors.conf версией по умолчанию из проекта? (y/N): " overwrite_colors
    if [[ "${overwrite_colors,,}" == "y" ]]; then
        cp -f "${CONFIG_DIR}/colors.conf" "${CONFIG_DIR}/colors.conf.bak-$(date +%Y%m%d_%H%M%S)"
        cp -f "${PROJECT_DIR}/hypr/colors.conf" "${CONFIG_DIR}/colors.conf"
        log_info "colors.conf обновлён (старый сохранён рядом с .bak-*)."
    else
        log_info "Оставляю твой colors.conf как есть."
    fi
else
    log_info "colors.conf не менялся, обновление не требуется."
fi

# ---------------------------------------------------------------------------
# 2. hypridle.conf
# ---------------------------------------------------------------------------
log_step "hypridle.conf"
# Тайминги простоя — вопрос личного вкуса: кто-то блокирует экран через 5 минут,
# кто-то через час. Поэтому спрашиваем, а не переписываем молча.
if ! diff -q "${PROJECT_DIR}/hypr/hypridle.conf" "${CONFIG_DIR}/hypridle.conf" >/dev/null 2>&1; then
    log_warn "Твой hypridle.conf отличается от версии в проекте (похоже, ты правил тайминги)."
    read -r -p "Перезаписать его версией по умолчанию из проекта? (y/N): " overwrite_idle
    if [[ "${overwrite_idle,,}" == "y" ]]; then
        cp -f "${CONFIG_DIR}/hypridle.conf" "${CONFIG_DIR}/hypridle.conf.bak-$(date +%Y%m%d_%H%M%S)"
        cp -f "${PROJECT_DIR}/hypr/hypridle.conf" "${CONFIG_DIR}/hypridle.conf"
        log_info "hypridle.conf обновлён (старый сохранён рядом с .bak-*)."
    else
        log_info "Оставляю твои тайминги как есть."
    fi
else
    log_info "hypridle.conf не менялся, обновление не требуется."
fi

# ---------------------------------------------------------------------------
# 3. Скрипты мониторинга
# ---------------------------------------------------------------------------
log_step "Скрипты"
# Раньше здесь стоял безусловный `cp -f`: любые твои правки в скриптах
# мониторинга затирались молча и без резервной копии. Теперь каждый скрипт
# сверяется с версией из проекта, и переписывается только с твоего согласия —
# со снимком старой версии рядом.
SCRIPTS_TS="$(date +%Y%m%d_%H%M%S)"
scripts_changed=0
scripts_kept=0

for src in "${PROJECT_DIR}"/scripts/lock-status-*.sh "${PROJECT_DIR}/scripts/switch-wallpaper.sh"; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    dst="${SCRIPTS_DIR}/${name}"

    if [[ ! -e "$dst" ]]; then
        cp -f "$src" "$dst"
        chmod +x "$dst"
        log_info "${name}: новый скрипт, установлен."
        continue
    fi

    if diff -q "$src" "$dst" >/dev/null 2>&1; then
        continue
    fi

    log_warn "${name} отличается от версии в проекте (похоже, ты его менял)."
    read -r -p "  Перезаписать ${name} версией из проекта? (y/N): " ov
    if [[ "${ov,,}" == "y" ]]; then
        cp -f "$dst" "${dst}.bak-${SCRIPTS_TS}"
        cp -f "$src" "$dst"
        chmod +x "$dst"
        log_info "  ${name} обновлён (старая версия — ${name}.bak-${SCRIPTS_TS})."
        scripts_changed=$((scripts_changed + 1))
    else
        log_info "  Оставляю твой ${name} как есть."
        scripts_kept=$((scripts_kept + 1))
    fi
done

log_info "Скрипты: обновлено ${scripts_changed}, оставлено без изменений ${scripts_kept}."

# ---------------------------------------------------------------------------
# 4. Обои — регенерируем именованные варианты (не трогает твои личные, если
#    ты добавлял свои файлы в wallpapers/ вручную — они останутся на месте)
# ---------------------------------------------------------------------------
log_step "Обои"
read -r -p "Перегенерировать 4 стандартных обоев темы? (текущие свои файлы не тронет) (y/N): " regen_wall
if [[ "${regen_wall,,}" == "y" ]]; then
    python3 "${PROJECT_DIR}/scripts/generate_wallpapers.py" --out "$WALLPAPERS_DIR" --width 3840 --height 2160
    log_info "Обои перегенерированы."
else
    log_info "Пропускаю регенерацию обоев."
fi

# ---------------------------------------------------------------------------
# 5. Иконки
# ---------------------------------------------------------------------------
log_step "Иконки"
rsvg-convert -w 200 -h 200 "${PROJECT_DIR}/icons/power.svg" -o "${ASSETS_DIR}/power.png"
rsvg-convert -w 120 -h 120 "${PROJECT_DIR}/icons/lock.svg"  -o "${ASSETS_DIR}/lock.png"
log_info "power.png / lock.png обновлены (avatar.png не трогаю — это твоя фотография)."

# ---------------------------------------------------------------------------
# 6. hyprlock.conf — пересобираем из свежего шаблона
# ---------------------------------------------------------------------------
log_step "hyprlock.conf"
cp -f "${CONFIG_DIR}/hyprlock.conf" "${CONFIG_DIR}/hyprlock.conf.bak-$(date +%Y%m%d_%H%M%S)"

sed \
    -e "s#__WALLPAPER_CURRENT__#${WALLPAPERS_DIR}/current.png#g" \
    -e "s#__AVATAR_PATH__#${ASSETS_DIR}/avatar.png#g" \
    -e "s#__ICON_POWER__#${ASSETS_DIR}/power.png#g" \
    -e "s#__ICON_LOCK__#${ASSETS_DIR}/lock.png#g" \
    -e "s#__HOSTNAME__#${HOSTNAME_VAL}#g" \
    -e "s#__SCRIPT_CPU__#${SCRIPTS_DIR}/lock-status-cpu.sh#g" \
    -e "s#__SCRIPT_RAM__#${SCRIPTS_DIR}/lock-status-ram.sh#g" \
    -e "s#__SCRIPT_TEMP__#${SCRIPTS_DIR}/lock-status-temp.sh#g" \
    -e "s#__SCRIPT_BATTERY__#${SCRIPTS_DIR}/lock-status-battery.sh#g" \
    -e "s#__SCRIPT_WIFI__#${SCRIPTS_DIR}/lock-status-wifi.sh#g" \
    "${PROJECT_DIR}/hypr/hyprlock.conf.template" > "${CONFIG_DIR}/hyprlock.conf"

log_info "hyprlock.conf пересобран (старый сохранён рядом с .bak-*)."

# ---------------------------------------------------------------------------
# 7. Перезапуск hypridle
# ---------------------------------------------------------------------------
log_step "Перезапуск hypridle"
if pidof hypridle >/dev/null 2>&1; then
    pkill hypridle || true
    sleep 0.3
fi
setsid hypridle >/dev/null 2>&1 &
disown
log_info "hypridle перезапущен."

echo ""
log_info "Обновление завершено. Проверить: hyprlock"
