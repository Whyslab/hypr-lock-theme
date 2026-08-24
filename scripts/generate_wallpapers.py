#!/usr/bin/env python3
"""
generate_wallpapers.py

Процедурная генерация 4K обоев в стиле "Monochrome Vivid" для темы hyprlock.
Никаких внешних скачиваний, никаких лицензионных вопросов — все изображения
рендерятся локально с нуля средствами PIL/numpy/scipy. Это даёт 100% гарантию,
что install.sh не сломается из-за мёртвой ссылки или недоступного хоста.

Использование:
    python3 generate_wallpapers.py [--out DIR] [--width W] [--height H]

Зависимости: pillow, numpy, scipy (ставятся install.sh через pip --break-system-packages).
"""

import argparse
import os

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, zoom

SEED = 1337


def _clip01(arr):
    return np.clip(arr, 0.0, 1.0)


def _to_gray_rgb(arr01):
    """arr01: 2D массив float в [0,1] -> RGB uint8 (строго монохромный, R=G=B)."""
    v = (_clip01(arr01) * 255.0).astype(np.uint8)
    return np.stack([v, v, v], axis=-1)


def _vignette(w, h, strength=0.55, power=2.2):
    """Мягкое затемнение к краям, 0 в центре..strength по углам."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2.0, h / 2.0
    dx = (x - cx) / (w / 2.0)
    dy = (y - cy) / (h / 2.0)
    dist = np.sqrt(dx ** 2 + dy ** 2)
    dist = np.clip(dist / dist.max(), 0.0, 1.0)
    return strength * (dist ** power)


def _film_grain(w, h, rng, amount=0.035, blur_radius=0.6):
    noise = rng.normal(0.0, 1.0, size=(h, w)).astype(np.float32)
    noise = gaussian_filter(noise, sigma=blur_radius)
    noise = noise / (np.abs(noise).max() + 1e-6)
    return noise * amount


def wallpaper_mesh_gradient(w, h, rng):
    """01: Мягкий mesh-градиент — несколько размытых пятен разной яркости на глубоком чёрном."""
    canvas = np.zeros((h, w), dtype=np.float32)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    for _ in range(6):
        r = rng.uniform(0.16, 0.32) * max(w, h)
        cx = rng.uniform(0.1, 0.9) * w
        cy = rng.uniform(0.1, 0.9) * h
        intensity = rng.uniform(0.10, 0.26)
        dist2 = (x - cx) ** 2 + (y - cy) ** 2
        blob = intensity * np.exp(-dist2 / (2 * (r * 0.55) ** 2))
        canvas = np.maximum(canvas, blob)
    result = np.full((h, w), 0.05, dtype=np.float32) + canvas
    result -= _vignette(w, h, strength=0.35)
    result += _film_grain(w, h, rng, amount=0.02)
    return _to_gray_rgb(result)


def wallpaper_film_grain(w, h, rng):
    """02: Глубокий чёрный с плёночным зерном и очень мягким верхним светом — минимализм."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    top_light = _clip01(1.0 - (y / h)) ** 3 * 0.10
    result = np.full((h, w), 0.035, dtype=np.float32) + top_light
    result += _film_grain(w, h, rng, amount=0.045, blur_radius=0.5)
    result -= _vignette(w, h, strength=0.30, power=2.6)
    return _to_gray_rgb(result)


def wallpaper_contour_lines(w, h, rng):
    """03: Абстрактные тонкие контурные линии, как топографические изолинии — на чёрном фоне."""
    small_w, small_h = max(8, w // 64), max(8, h // 64)
    field = rng.uniform(0.0, 1.0, size=(small_h, small_w)).astype(np.float32)
    zy, zx = h / small_h, w / small_w
    field = zoom(field, (zy, zx), order=3)
    field = field[:h, :w]
    if field.shape != (h, w):
        field = np.pad(
            field,
            ((0, max(0, h - field.shape[0])), (0, max(0, w - field.shape[1]))),
            mode="edge",
        )[:h, :w]
    field = gaussian_filter(field, sigma=w * 0.012)
    field = (field - field.min()) / (np.ptp(field) + 1e-6)

    canvas = np.zeros((h, w), dtype=np.float32)
    levels = np.linspace(0.15, 0.85, 14)
    band = 0.010
    for lvl in levels:
        canvas += np.exp(-((field - lvl) ** 2) / (2 * band ** 2))
    canvas = _clip01(canvas) * 0.55

    result = np.full((h, w), 0.04, dtype=np.float32) + canvas
    result -= _vignette(w, h, strength=0.40)
    result += _film_grain(w, h, rng, amount=0.015)
    return _to_gray_rgb(result)


def wallpaper_corner_glow(w, h, rng):
    """04: Мягкое editorial-свечение из верхнего угла, стекающее в глубокий чёрный."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * 0.82, h * 0.12
    dx = (x - cx) / w
    dy = (y - cy) / h
    dist = np.sqrt(dx ** 2 + dy ** 2)
    glow = np.exp(-(dist ** 2) / (2 * 0.42 ** 2)) * 0.42
    result = np.full((h, w), 0.03, dtype=np.float32) + glow
    result -= _vignette(w, h, strength=0.25, power=3.0)
    result += _film_grain(w, h, rng, amount=0.02)
    return _to_gray_rgb(result)


GENERATORS = {
    "monochrome-01-mesh.png": wallpaper_mesh_gradient,
    "monochrome-02-grain.png": wallpaper_film_grain,
    "monochrome-03-contour.png": wallpaper_contour_lines,
    "monochrome-04-glow.png": wallpaper_corner_glow,
}


def main():
    parser = argparse.ArgumentParser(description="Генератор Monochrome Vivid обоев")
    default_out = os.path.join(os.path.dirname(__file__), "..", "wallpapers")
    parser.add_argument("--out", default=default_out)
    parser.add_argument("--width", type=int, default=3840)
    parser.add_argument("--height", type=int, default=2160)
    args = parser.parse_args()

    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)

    for i, (name, fn) in enumerate(GENERATORS.items()):
        rng = np.random.default_rng(SEED + i)
        rgb = fn(args.width, args.height, rng)
        img = Image.fromarray(rgb, mode="RGB")
        path = os.path.join(out_dir, name)
        img.save(path, format="PNG", optimize=True)
        print(f"[ok] {name} -> {path} ({img.size[0]}x{img.size[1]})")

    default_src = os.path.join(out_dir, "monochrome-01-mesh.png")
    default_dst = os.path.join(out_dir, "current.png")
    if os.path.islink(default_dst) or os.path.exists(default_dst):
        os.remove(default_dst)
    with Image.open(default_src) as im:
        im.save(default_dst, format="PNG")
    print(f"[ok] current.png -> копия {os.path.basename(default_src)} (обои по умолчанию)")


if __name__ == "__main__":
    main()
