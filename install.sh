#!/usr/bin/env bash
# install.sh — устанавливает тему Hyprlock "Monochrome Vivid"
#
# Запускать ОТ ОБЫЧНОГО ПОЛЬЗОВАТЕЛЯ (не от root). Скрипт сам спросит sudo,
# когда потребуется поставить системные пакеты.

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Цвета/логи — в том же стиле, что и другие твои проекты
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "\n${BLUE}==>${NC} $1"; }

trap 'log_err "Установка прервана на строке $LINENO (код $?)."; exit 1' ERR

# ---------------------------------------------------------------------------
# 0. Проверки
# ---------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    log_err "Не запускай install.sh от root. Запусти от обычного пользователя: ./install.sh"
    log_err "Sudo-пароль скрипт спросит сам, когда потребуется ставить пакеты."
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    log_err "pacman не найден. Этот установщик рассчитан на Arch Linux (и производные)."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/hypr"
SCRIPTS_DIR="${CONFIG_DIR}/scripts"
WALLPAPERS_DIR="${CONFIG_DIR}/wallpapers"
ASSETS_DIR="${CONFIG_DIR}/assets"
BACKUP_DIR="${CONFIG_DIR}/monochrome-vivid-backup-$(date +%Y%m%d_%H%M%S)"
HOSTNAME_VAL="${HOSTNAME:-$(cat /etc/hostname 2>/dev/null || hostnamectl hostname 2>/dev/null || echo unknown-host)}"

echo -e "${BLUE}"
cat <<'BANNER'
 __  __                       _                       __      ___     _     _
|  \/  | ___  _ __   ___   ___| |__  _ __ ___  _ __ ___\ \    / (_)_ _(_) __| |
| |\/| |/ _ \| '_ \ / _ \ / __| '_ \| '__/ _ \| '_ ` _ \\ \  / /| \ \ / |/ _` |
| |  | | (_) | | | | (_) | (__| | | | | | (_) | | | | | |\ \/ / | |\ V /| | (_| |
|_|  |_|\___/|_| |_|\___/ \___|_| |_|_|  \___/|_| |_| |_| \__/  |_| \_/ |_|\__,_|

                      Hyprlock theme installer
BANNER
echo -e "${NC}"

log_info "Каталог проекта:      $PROJECT_DIR"
log_info "Каталог установки:    $CONFIG_DIR"
log_info "Хост:                 $HOSTNAME_VAL"

# ---------------------------------------------------------------------------
# 1. Обновление системы (по желанию)
# ---------------------------------------------------------------------------
log_step "Обновление системы"
read -r -p "Выполнить полное обновление системы перед установкой? (y/N): " do_update
if [[ "${do_update,,}" == "y" ]]; then
    sudo pacman -Syu
else
    log_info "Пропускаю полное обновление (можно сделать вручную: sudo pacman -Syu)."
fi

# ---------------------------------------------------------------------------
# 2. Зависимости
# ---------------------------------------------------------------------------
log_step "Проверка и установка зависимостей"

# Только то, без чего тема не работает. grim/slurp/jq раньше стояли здесь,
# но нигде не использовались: grim нужен лишь тому, кто хочет прислать
# скриншот (см. README), а slurp и jq не упоминались в проекте вообще.
CORE_PKGS=(
    hyprlock          # сам экран блокировки
    hypridle          # демон простоя, который его вызывает
    brightnessctl     # приглушение подсветки в hypridle.conf
    pam               # аутентификация по системному паролю
    librsvg           # rsvg-convert: SVG-иконки → PNG при установке
    python-pillow     # генератор обоев
    python-numpy      # генератор обоев
    python-scipy      # генератор обоев (contour-вариант)
)

log_info "Пакеты: ${CORE_PKGS[*]}"
sudo pacman -S --needed --noconfirm "${CORE_PKGS[@]}"

# lm_sensors — опционально, только для показателя температуры в мини-мониторинге
if ! command -v sensors >/dev/null 2>&1; then
    read -r -p "Установить lm_sensors для отображения температуры CPU? (Y/n): " want_sensors
    if [[ "${want_sensors,,}" != "n" ]]; then
        sudo pacman -S --needed --noconfirm lm_sensors
        log_warn "Чтобы датчики реально заработали, один раз выполни: sudo sensors-detect --auto"
    fi
else
    log_info "lm_sensors уже установлен."
fi

# Nerd Font — сначала проверяем, вдруг уже стоит
log_step "Шрифт JetBrainsMono Nerd Font"
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    log_info "Шрифт уже установлен, пропускаю."
else
    if pacman -Si ttf-jetbrains-mono-nerd >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd
    elif command -v yay >/dev/null 2>&1; then
        log_info "Пакета нет в официальных репозиториях, ставлю через yay (AUR)..."
        yay -S --needed --noconfirm ttf-jetbrains-mono-nerd
    elif command -v paru >/dev/null 2>&1; then
        log_info "Пакета нет в официальных репозиториях, ставлю через paru (AUR)..."
        paru -S --needed --noconfirm ttf-jetbrains-mono-nerd
    else
        log_warn "Не нашёл ttf-jetbrains-mono-nerd в pacman и не нашёл yay/paru для AUR."
        log_warn "Поставь шрифт вручную: https://www.nerdfonts.com/font-downloads (JetBrains Mono)"
    fi
    fc-cache -f >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 3. Резервная копия существующих конфигов
# ---------------------------------------------------------------------------
log_step "Резервное копирование текущих конфигов"
NEED_BACKUP=false
for f in hyprlock.conf hypridle.conf colors.conf; do
    [[ -e "${CONFIG_DIR}/${f}" ]] && NEED_BACKUP=true
done
for d in scripts wallpapers assets; do
    [[ -d "${CONFIG_DIR}/${d}" ]] && NEED_BACKUP=true
done

if [[ "$NEED_BACKUP" == true ]]; then
    mkdir -p "$BACKUP_DIR"
    for f in hyprlock.conf hypridle.conf colors.conf; do
        [[ -e "${CONFIG_DIR}/${f}" ]] && cp -a "${CONFIG_DIR}/${f}" "$BACKUP_DIR/"
    done
    for d in scripts wallpapers assets; do
        [[ -d "${CONFIG_DIR}/${d}" ]] && cp -a "${CONFIG_DIR}/${d}" "$BACKUP_DIR/"
    done
    log_info "Старые файлы сохранены в: $BACKUP_DIR"
else
    log_info "Существующих конфигов не найдено, резервная копия не нужна."
fi

# ---------------------------------------------------------------------------
# 4. Каталоги установки
# ---------------------------------------------------------------------------
log_step "Создание структуры каталогов"
mkdir -p "$CONFIG_DIR" "$SCRIPTS_DIR" "$WALLPAPERS_DIR" "$ASSETS_DIR"
log_info "OK"

# ---------------------------------------------------------------------------
# 5. Обои — генерируем процедурно (никаких внешних скачиваний и мёртвых ссылок)
# ---------------------------------------------------------------------------
log_step "Генерация обоев Monochrome Vivid (4K, 4 варианта)"
python3 "${PROJECT_DIR}/scripts/generate_wallpapers.py" --out "$WALLPAPERS_DIR" --width 3840 --height 2160
log_info "Обои сгенерированы в: $WALLPAPERS_DIR"

# ---------------------------------------------------------------------------
# 6. Иконки — рендерим SVG -> PNG нужных размеров
# ---------------------------------------------------------------------------
log_step "Подготовка иконок"

if [[ -f "$HOME/.face" ]]; then
    log_info "Найден ~/.face — использую его как аватар."
    cp -f "$HOME/.face" "${ASSETS_DIR}/avatar.png"
else
    rsvg-convert -w 300 -h 300 "${PROJECT_DIR}/icons/user.svg" -o "${ASSETS_DIR}/avatar.png"
    log_info "Аватар по умолчанию сгенерирован. Чтобы заменить на своё фото:"
    log_info "  cp твоё_фото.png ${ASSETS_DIR}/avatar.png"
fi

rsvg-convert -w 200 -h 200 "${PROJECT_DIR}/icons/power.svg" -o "${ASSETS_DIR}/power.png"
rsvg-convert -w 120 -h 120 "${PROJECT_DIR}/icons/lock.svg"  -o "${ASSETS_DIR}/lock.png"
log_info "Иконки power/lock отрендерены в PNG."

# ---------------------------------------------------------------------------
# 7. Копирование скриптов мини-мониторинга и смены обоев
# ---------------------------------------------------------------------------
log_step "Установка скриптов"
cp -f "${PROJECT_DIR}"/scripts/lock-status-*.sh "$SCRIPTS_DIR/"
cp -f "${PROJECT_DIR}/scripts/switch-wallpaper.sh" "$SCRIPTS_DIR/"
chmod +x "${SCRIPTS_DIR}"/*.sh
log_info "Скрипты скопированы в: $SCRIPTS_DIR"

# ---------------------------------------------------------------------------
# 8. Палитра и hypridle.conf — копируются как есть
# ---------------------------------------------------------------------------
log_step "Установка палитры и hypridle"
cp -f "${PROJECT_DIR}/hypr/colors.conf" "${CONFIG_DIR}/colors.conf"
cp -f "${PROJECT_DIR}/hypr/hypridle.conf" "${CONFIG_DIR}/hypridle.conf"
log_info "colors.conf и hypridle.conf установлены."

# ---------------------------------------------------------------------------
# 9. hyprlock.conf — подставляем реальные пути в шаблон
# ---------------------------------------------------------------------------
log_step "Генерация hyprlock.conf из шаблона"

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

log_info "hyprlock.conf записан: ${CONFIG_DIR}/hyprlock.conf"

# ---------------------------------------------------------------------------
# 10. Автозапуск hypridle через hyprland.conf (только если ещё не настроен)
# ---------------------------------------------------------------------------
log_step "Автозапуск hypridle"
HYPRLAND_CONF="${CONFIG_DIR}/hyprland.conf"
if [[ -f "$HYPRLAND_CONF" ]]; then
    if grep -q "hypridle" "$HYPRLAND_CONF"; then
        log_info "hypridle уже упоминается в hyprland.conf, ничего не трогаю."
    else
        cp -a "$HYPRLAND_CONF" "${HYPRLAND_CONF}.monochrome-vivid-backup-$(date +%Y%m%d_%H%M%S)"
        {
            echo ""
            echo "# --- добавлено установщиком темы Monochrome Vivid ---"
            echo "exec-once = hypridle"
        } >> "$HYPRLAND_CONF"
        log_info "Добавил 'exec-once = hypridle' в конец hyprland.conf (бэкап сделан рядом)."
    fi
else
    log_warn "Не нашёл ${HYPRLAND_CONF} — добавь 'exec-once = hypridle' в свой конфиг Hyprland вручную."
fi

# Перезапускаем hypridle прямо сейчас, чтобы не ждать перелогина
if pidof hypridle >/dev/null 2>&1; then
    pkill hypridle || true
    sleep 0.3
fi
setsid hypridle >/dev/null 2>&1 &
disown
log_info "hypridle перезапущен для текущей сессии."

# ---------------------------------------------------------------------------
# 11. Проверка работоспособности
# ---------------------------------------------------------------------------
log_step "Проверка"

CHECK_OK=true

[[ -s "${CONFIG_DIR}/hyprlock.conf" ]] || { log_err "hyprlock.conf пустой или отсутствует!"; CHECK_OK=false; }
[[ -s "${CONFIG_DIR}/hypridle.conf" ]] || { log_err "hypridle.conf пустой или отсутствует!"; CHECK_OK=false; }
[[ -f "${WALLPAPERS_DIR}/current.png" ]] || { log_err "Обои не сгенерировались!"; CHECK_OK=false; }
[[ -f "${ASSETS_DIR}/avatar.png" ]] || { log_err "Аватар не создан!"; CHECK_OK=false; }

for s in cpu ram temp battery wifi; do
    script_path="${SCRIPTS_DIR}/lock-status-${s}.sh"
    if [[ -x "$script_path" ]]; then
        bash "$script_path" >/dev/null 2>&1 || log_warn "Скрипт lock-status-${s}.sh завершился с ошибкой (не критично, label будет пустым)."
    else
        log_err "Не найден или не исполняемый: $script_path"
        CHECK_OK=false
    fi
done

if command -v hyprlock >/dev/null 2>&1; then
    log_info "Бинарник hyprlock найден: $(command -v hyprlock)"
else
    log_err "hyprlock не найден в PATH после установки — что-то пошло не так с pacman."
    CHECK_OK=false
fi

echo ""
if [[ "$CHECK_OK" == true ]]; then
    log_info "Установка завершена успешно."
else
    log_warn "Установка завершена, но проверка нашла проблемы (см. выше)."
fi

echo -e "
${GREEN}Готово.${NC}

Проверить экран блокировки прямо сейчас (заблокирует текущую сессию,
разблокируется твоим обычным паролем):

    hyprlock

Сменить обои:
    ${SCRIPTS_DIR}/switch-wallpaper.sh          — список вариантов
    ${SCRIPTS_DIR}/switch-wallpaper.sh 3        — выбрать вариант №3
    ${SCRIPTS_DIR}/switch-wallpaper.sh --random — случайный вариант

Изменить цвета:  ${CONFIG_DIR}/colors.conf
Изменить тайминги простоя/сна: ${CONFIG_DIR}/hypridle.conf
Подробности:     README.md в каталоге проекта
"
