#!/usr/bin/env bash
# uninstall.sh — убирает тему Hyprlock "Monochrome Vivid" и, если найдена
# резервная копия от install.sh, предлагает восстановить старые конфиги.

set -Eeuo pipefail
trap 'log_err "Прервано на строке $LINENO. Ничего больше не удаляется."; exit 1' ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "\n${BLUE}==>${NC} $1"; }

if [[ $EUID -eq 0 ]]; then
    log_err "Не запускай uninstall.sh от root."
    exit 1
fi

CONFIG_DIR="$HOME/.config/hypr"

echo -e "${YELLOW}Это удалит тему Monochrome Vivid: hyprlock.conf, hypridle.conf,${NC}"
echo -e "${YELLOW}colors.conf, скрипты мониторинга, сгенерированные обои и иконки.${NC}"
read -r -p "Продолжить? (y/N): " confirm
if [[ "${confirm,,}" != "y" ]]; then
    echo "Отмена."
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Поиск резервной копии
# ---------------------------------------------------------------------------
log_step "Поиск резервных копий"
mapfile -t BACKUPS < <(find "$CONFIG_DIR" -maxdepth 1 -type d -name 'monochrome-vivid-backup-*' 2>/dev/null | sort -r)

RESTORE_FROM=""
if [[ ${#BACKUPS[@]} -gt 0 ]]; then
    log_info "Найдена резервная копия: ${BACKUPS[0]}"
    read -r -p "Восстановить конфиги из неё после удаления темы? (Y/n): " do_restore
    if [[ "${do_restore,,}" != "n" ]]; then
        RESTORE_FROM="${BACKUPS[0]}"
    fi
else
    log_info "Резервных копий не найдено — после удаления конфиги останутся пустыми, пока не создашь свои."
fi

# ---------------------------------------------------------------------------
# 2. Удаление файлов темы
# ---------------------------------------------------------------------------
log_step "Удаление файлов темы"

# Снимок текущего состояния ПЕРЕД удалением. Раньше uninstall.sh полагался
# только на резервную копию, оставленную install.sh: если ты правил конфиги
# или скрипты уже после установки, эти правки исчезали безвозвратно.
SNAPSHOT="${CONFIG_DIR}/monochrome-vivid-removed-$(date +%Y%m%d_%H%M%S)"
mkdir -p "${SNAPSHOT}/scripts" "${SNAPSHOT}/assets" "${SNAPSHOT}/wallpapers"

snapshot_file() {
    local src="$1" sub="${2:-}"
    [[ -e "$src" ]] || return 0
    cp -a "$src" "${SNAPSHOT}/${sub}" 2>/dev/null || true
}

for f in hyprlock.conf hypridle.conf colors.conf; do
    snapshot_file "${CONFIG_DIR}/${f}"
done
for s_name in cpu ram temp battery wifi; do
    snapshot_file "${CONFIG_DIR}/scripts/lock-status-${s_name}.sh" "scripts/"
done
snapshot_file "${CONFIG_DIR}/scripts/switch-wallpaper.sh" "scripts/"
for f in avatar.png power.png lock.png; do
    snapshot_file "${CONFIG_DIR}/assets/${f}" "assets/"
done
for f in monochrome-01-mesh.png monochrome-02-grain.png monochrome-03-contour.png \
         monochrome-04-glow.png current.png; do
    snapshot_file "${CONFIG_DIR}/wallpapers/${f}" "wallpapers/"
done

# Пустые подкаталоги только мешают — уберём их из снимка.
find "$SNAPSHOT" -type d -empty -delete 2>/dev/null || true

if [[ -d "$SNAPSHOT" ]]; then
    log_info "Снимок текущих файлов сохранён: ${SNAPSHOT}"
    log_info "Если удаление окажется ошибкой — всё лежит там."
else
    log_info "Нечего сохранять: файлов темы на месте не найдено."
fi

rm -f "${CONFIG_DIR}/hyprlock.conf"
rm -f "${CONFIG_DIR}/hypridle.conf"
rm -f "${CONFIG_DIR}/colors.conf"

for s in cpu ram temp battery wifi; do
    rm -f "${CONFIG_DIR}/scripts/lock-status-${s}.sh"
done
rm -f "${CONFIG_DIR}/scripts/switch-wallpaper.sh"

rm -f "${CONFIG_DIR}/wallpapers/monochrome-01-mesh.png"
rm -f "${CONFIG_DIR}/wallpapers/monochrome-02-grain.png"
rm -f "${CONFIG_DIR}/wallpapers/monochrome-03-contour.png"
rm -f "${CONFIG_DIR}/wallpapers/monochrome-04-glow.png"
rm -f "${CONFIG_DIR}/wallpapers/current.png"

rm -f "${CONFIG_DIR}/assets/avatar.png"
rm -f "${CONFIG_DIR}/assets/power.png"
rm -f "${CONFIG_DIR}/assets/lock.png"

log_info "Файлы темы удалены."

# ---------------------------------------------------------------------------
# 3. Убираем добавленную строку exec-once из hyprland.conf
# ---------------------------------------------------------------------------
log_step "Откат изменений в hyprland.conf"
HYPRLAND_CONF="${CONFIG_DIR}/hyprland.conf"
MARKER="# --- добавлено установщиком темы Monochrome Vivid ---"

if [[ -f "$HYPRLAND_CONF" ]] && grep -qF "$MARKER" "$HYPRLAND_CONF"; then
    cp -a "$HYPRLAND_CONF" "${HYPRLAND_CONF}.before-uninstall-$(date +%Y%m%d_%H%M%S)"
    # удаляем строку с маркером и следующую за ней строку (exec-once = hypridle)
    sed -i "/$(printf '%s' "$MARKER" | sed 's/[.[\*^$/]/\\&/g')/,+1d" "$HYPRLAND_CONF"
    log_info "Удалил добавленный 'exec-once = hypridle' из hyprland.conf (бэкап рядом)."
else
    log_info "В hyprland.conf нет наших изменений — трогать нечего."
fi

# ---------------------------------------------------------------------------
# 4. Восстановление из бэкапа (если выбрано)
# ---------------------------------------------------------------------------
if [[ -n "$RESTORE_FROM" ]]; then
    log_step "Восстановление конфигов из $RESTORE_FROM"
    for f in hyprlock.conf hypridle.conf colors.conf; do
        [[ -e "${RESTORE_FROM}/${f}" ]] && cp -a "${RESTORE_FROM}/${f}" "${CONFIG_DIR}/${f}"
    done
    for d in scripts wallpapers assets; do
        [[ -d "${RESTORE_FROM}/${d}" ]] && cp -a "${RESTORE_FROM}/${d}/." "${CONFIG_DIR}/${d}/"
    done
    log_info "Старые конфиги восстановлены."
fi

# ---------------------------------------------------------------------------
# 5. Останавливаем hypridle текущей сессии
# ---------------------------------------------------------------------------
if pidof hypridle >/dev/null 2>&1; then
    pkill hypridle || true
    log_info "hypridle остановлен для текущей сессии."
fi

echo ""
log_info "Удаление завершено."
if [[ -d "${SNAPSHOT:-}" ]]; then
    log_info "Снимок удалённых файлов: ${SNAPSHOT}"
fi
log_warn "Пакеты (hyprlock, hypridle, шрифт и т.д.) НЕ удалены — они могут использоваться"
log_warn "другими темами. Убрать вручную: sudo pacman -Rns hyprlock hypridle ttf-jetbrains-mono-nerd"
