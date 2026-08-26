#!/usr/bin/env bash
# tests/run-tests.sh — набор тестов для темы Monochrome Vivid.
#
# Тесты намеренно не запускают install.sh и не трогают ~/.config: они проверяют
# то, что можно проверить безопасно — что скрипты мониторинга действительно
# печатают ожидаемый формат, что шаблон и подстановки не разъехались, и что
# генератор обоев выдаёт обещанные файлы.
#
# Запуск: bash tests/run-tests.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

ok()   { printf '  \033[0;32mok\033[0m   %s\n' "$1"; PASS=$((PASS+1)); }
nok()  { printf '  \033[0;31mFAIL\033[0m %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; FAIL=$((FAIL+1)); }
group(){ printf '\n\033[0;34m==>\033[0m %s\n' "$1"; }

# --------------------------------------------------------------------------
group "Синтаксис shell-скриптов"
# --------------------------------------------------------------------------
while IFS= read -r f; do
    if bash -n "$f" 2>/dev/null; then ok "bash -n $(basename "$f")"
    else nok "bash -n $(basename "$f")" "$(bash -n "$f" 2>&1 | head -1)"; fi
done < <(find "$ROOT" -name '*.sh' -not -path '*/.git/*' | sort)

# --------------------------------------------------------------------------
group "Скрипты мониторинга печатают ровно одну непустую строку"
# --------------------------------------------------------------------------
for s in cpu ram temp wifi; do
    script="$ROOT/scripts/lock-status-${s}.sh"
    out=$("$script" 2>/dev/null)
    lines=$(printf '%s' "$out" | grep -c '' || true)
    if [[ -n "$out" && "$lines" -eq 1 ]]; then
        ok "lock-status-${s}.sh -> '${out}'"
    else
        nok "lock-status-${s}.sh" "получено ${lines} строк: '${out}'"
    fi
done

# Батарея — особый случай: на настольной машине пустой вывод это правильно.
out=$("$ROOT/scripts/lock-status-battery.sh" 2>/dev/null)
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null || command -v upower >/dev/null 2>&1; then
    if [[ -n "$out" ]]; then ok "lock-status-battery.sh -> '${out}'"
    else nok "lock-status-battery.sh" "батарея есть, но вывод пуст"; fi
else
    if [[ -z "$out" ]]; then ok "lock-status-battery.sh -> пусто (батареи нет, так и надо)"
    else nok "lock-status-battery.sh" "батареи нет, а вывод непустой: '${out}'"; fi
fi

# --------------------------------------------------------------------------
group "Скрипты не ломаются в локали с запятой как разделителем"
# --------------------------------------------------------------------------
# Регрессия: printf %f в ru_RU.UTF-8 отказывается читать '46.0', из-за чего
# температура и заряд молча печатались с мусором ("980%").
for s in cpu ram temp battery wifi; do
    script="$ROOT/scripts/lock-status-${s}.sh"
    err=$(LC_ALL=ru_RU.UTF-8 LANG=ru_RU.UTF-8 "$script" 2>&1 >/dev/null)
    if [[ -z "$err" ]]; then ok "lock-status-${s}.sh без ошибок в ru_RU.UTF-8"
    else nok "lock-status-${s}.sh в ru_RU.UTF-8" "$err"; fi
done

# Числа в выводе не должны содержать мусорных подряд идущих цифр из-за
# сорвавшегося printf: процент обязан быть в диапазоне 0..100.
for s in cpu battery; do
    out=$(LC_ALL=ru_RU.UTF-8 "$ROOT/scripts/lock-status-${s}.sh" 2>/dev/null)
    pct=$(grep -oE '[0-9]+%' <<< "$out" | head -1 | tr -d '%')
    if [[ -z "$pct" ]]; then
        ok "lock-status-${s}.sh: процента нет (допустимо)"
    elif (( pct >= 0 && pct <= 100 )); then
        ok "lock-status-${s}.sh: процент ${pct} в диапазоне 0..100"
    else
        nok "lock-status-${s}.sh" "процент вне диапазона: ${pct} (вывод: '${out}')"
    fi
done

# --------------------------------------------------------------------------
group "Шаблон hyprlock и подстановки не разъехались"
# --------------------------------------------------------------------------
TPL="$ROOT/hypr/hyprlock.conf.template"
tpl_tokens=$(grep -oE '__[A-Z_]+__' "$TPL" | sort -u)
for script in install.sh update.sh; do
    script_tokens=$(grep -oE '__[A-Z_]+__' "$ROOT/$script" | sort -u)
    missing=$(comm -23 <(printf '%s\n' "$tpl_tokens") <(printf '%s\n' "$script_tokens"))
    extra=$(comm -13 <(printf '%s\n' "$tpl_tokens") <(printf '%s\n' "$script_tokens"))
    if [[ -z "$missing" && -z "$extra" ]]; then
        ok "$script подставляет ровно те плейсхолдеры, что есть в шаблоне"
    else
        nok "$script" "не подставляются: ${missing:-—} · лишние: ${extra:-—}"
    fi
done

# После подстановки в шаблоне не должно остаться ни одного __TOKEN__.
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
sed -e 's|__WALLPAPER_CURRENT__|/tmp/w.png|g' -e 's|__AVATAR_PATH__|/tmp/a.png|g' \
    -e 's|__ICON_POWER__|/tmp/p.png|g'        -e 's|__ICON_LOCK__|/tmp/l.png|g' \
    -e 's|__HOSTNAME__|testhost|g'            -e 's|__SCRIPT_CPU__|/tmp/c.sh|g' \
    -e 's|__SCRIPT_RAM__|/tmp/r.sh|g'         -e 's|__SCRIPT_TEMP__|/tmp/t.sh|g' \
    -e 's|__SCRIPT_BATTERY__|/tmp/b.sh|g'     -e 's|__SCRIPT_WIFI__|/tmp/wi.sh|g' \
    "$TPL" > "$tmp"
if leftover=$(grep -oE '__[A-Z_]+__' "$tmp" | sort -u) && [[ -n "$leftover" ]]; then
    nok "в собранном конфиге остались плейсхолдеры" "$leftover"
else
    ok "собранный hyprlock.conf не содержит плейсхолдеров"
fi

# --------------------------------------------------------------------------
group "Пакеты, объявленные в install.sh, действительно используются"
# --------------------------------------------------------------------------
# Регрессия: playerctl, grim, slurp и jq годами стояли в списке зависимостей,
# но не упоминались больше нигде в проекте.
declare -A PKG_PROOF=(
    [hyprlock]='hyprlock'          [hypridle]='hypridle'
    [brightnessctl]='brightnessctl' [librsvg]='rsvg-convert'
    [python-pillow]='PIL|Image'     [python-numpy]='numpy'
    [python-scipy]='scipy'
)
pkgs=$(sed -n '/^CORE_PKGS=(/,/^)/p' "$ROOT/install.sh" | grep -oE '^\s+[a-z0-9-]+' | tr -d ' ')
for pkg in $pkgs; do
    [[ "$pkg" == "pam" ]] && { ok "pam (неявная зависимость hyprlock, проверка пропущена)"; continue; }
    proof="${PKG_PROOF[$pkg]:-$pkg}"
    if grep -rqE "$proof" --include='*.sh' --include='*.conf' --include='*.template' --include='*.py' \
         --exclude='install.sh' "$ROOT" 2>/dev/null; then
        ok "$pkg используется в проекте"
    else
        nok "$pkg объявлен в CORE_PKGS, но нигде не используется"
    fi
done

# --------------------------------------------------------------------------
group "Генератор обоев"
# --------------------------------------------------------------------------
if python3 -c 'import PIL, numpy, scipy' 2>/dev/null; then
    outdir=$(mktemp -d); trap 'rm -rf "$outdir"; rm -f "$tmp"' EXIT
    if python3 "$ROOT/scripts/generate_wallpapers.py" --out "$outdir" --width 320 --height 180 >/dev/null 2>&1; then
        expected=(monochrome-01-mesh.png monochrome-02-grain.png monochrome-03-contour.png monochrome-04-glow.png current.png)
        miss=""
        for f in "${expected[@]}"; do [[ -f "$outdir/$f" ]] || miss+=" $f"; done
        if [[ -z "$miss" ]]; then ok "сгенерированы все 5 файлов"
        else nok "генератор обоев" "не хватает:$miss"; fi

        # Обои обязаны быть строго серыми — это весь смысл темы.
        if python3 - "$outdir" <<'PY' 2>/dev/null
import sys, glob
from PIL import Image
bad = []
for p in glob.glob(sys.argv[1] + "/monochrome-*.png"):
    im = Image.open(p).convert("RGB")
    for r, g, b in im.getdata():
        if r != g or g != b:
            bad.append(p); break
sys.exit(1 if bad else 0)
PY
        then ok "все обои строго монохромны (R==G==B)"
        else nok "обои" "найден цветной пиксель — тема должна быть монохромной"; fi
    else
        nok "генератор обоев" "скрипт завершился с ошибкой"
    fi
else
    printf '  \033[1;33mskip\033[0m Pillow/numpy/scipy не установлены\n'
fi

# --------------------------------------------------------------------------
printf '\n────────────────────────────\n'
printf 'Пройдено: %d · Провалено: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
