#!/usr/bin/env python3
"""Готує малюнки для гри з папки з оригіналами (за замовчуванням /workspace/spohady-art-incoming).

Оригінали (великі JPG/WEBP) у репозиторії не лежать. Скрипт бере ТІЛЬКИ вибрані варіанти,
обрізає, прибирає світле тло, зменшує й зберігає PNG у art/.
Запуск:  python3 tools/prepare_art.py [папка_з_оригіналами]
Потрібно: Pillow, numpy, scipy.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = Path(sys.argv[1] if len(sys.argv) > 1 else "/workspace/spohady-art-incoming")
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art"

# Напис на портреті Велеса (864x1152): закінчується приблизно на y=250, роги починаються ~y=258.
VELES_CROP_TOP = 254

BLESSINGS = {
    "perun": "perun.webp", "stribog": "stribog.webp", "dazhbog": "dazhbog.webp",
    "mokosh": "mokosh.webp", "svarog": "svarog.webp", "veles": "veles_v2.jpg",
}
CLASSES = {
    "druzhynnyk": "class_druzhynnyk_v2.jpg", "strilets": "class_strilets_v1.jpg",
    "volkhv": "class_volkhv_v2.jpg",
}
SKILLS = {
    "power_strike": "skill_power_strike_v2.jpg",
    "arrow_volley": "skill_arrow_volley_v2.jpg",
    "stribog_dash": "skill_whirlwind_v1.jpg",
    # «Хвиля стихії» залежить від благословення
    "element_wave_perun": "skill_lightning_v1.jpg",
    "element_wave_svarog": "skill_fire_v1.jpg",
    "element_wave_veles": "skill_veles_v2.jpg",
    "element_wave_dazhbog": "skill_sun_v1.jpg",
    "element_wave_mokosh": "skill_fate_v1.jpg",
}
PERKS = {
    "region_str": "perk_s3_v1.jpg", "region_agi": "perk_a3_v2.jpg",
    "region_faith": "perk_f3_v3.jpg", "core": "perk_core_v1.jpg",
}
ENEMIES = {"novice": "acolyte_v1.jpg", "werewolf": "werewolf.jpg", "wraith": "spectre.jpg"}


def find(name):
    for p in SRC.rglob(name):
        return p
    raise FileNotFoundError(name)


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    print("  ", path.relative_to(ROOT), im.size, path.stat().st_size // 1024, "KB")


def fit_width(im, w):
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def circle_icon(im, size):
    """Кругла іконка: чорне тло за медальйоном стає прозорим."""
    im = im.convert("RGB").resize((size * 2, size * 2), Image.LANCZOS)
    s = size * 2
    yy, xx = np.mgrid[0:s, 0:s]
    d = np.hypot(xx - s / 2 + 0.5, yy - s / 2 + 0.5) / (s / 2)
    a = np.clip((0.975 - d) / 0.03, 0, 1)
    rgba = np.dstack([np.array(im), (a * 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA").resize((size, size), Image.LANCZOS)


def band(im, rows):
    y0, y1 = rows[0] + 12, rows[1] - 12  # зрізаємо білі поля по краях
    b = im.crop((0, y0, im.width, y1 + 1))
    return fit_width(b, 1024).convert("RGBA")


def main():
    print("Портрети богів")
    for bid, fn in BLESSINGS.items():
        im = Image.open(find(fn)).convert("RGB")
        if bid == "veles":
            im = im.crop((0, VELES_CROP_TOP, im.width, im.height))
        save(fit_width(im, 512), OUT / "portraits" / f"blessing_{bid}.png")
    print("Портрети класів")
    for cid, fn in CLASSES.items():
        im = Image.open(find(fn)).convert("RGB")
        save(im.resize((512, 512), Image.LANCZOS), OUT / "portraits" / f"class_{cid}.png")
        save(im.resize((256, 256), Image.LANCZOS), OUT / "portraits" / f"hero_{cid}.png")
    print("Значки навичок")
    for k, fn in SKILLS.items():
        save(circle_icon(Image.open(find(fn)), 256), OUT / "icons" / "skills" / f"{k}.png")
    print("Значки перків")
    for k, fn in PERKS.items():
        save(circle_icon(Image.open(find(fn)), 128), OUT / "icons" / "perks" / f"{k}.png")
    print("Вороги")
    for k, fn in ENEMIES.items():
        im = Image.open(find(fn)).convert("RGB")
        save(im.resize((240, 320), Image.LANCZOS), OUT / "enemies" / f"{k}.png")

    print("Вишита смужка")
    b = Image.open(find("border_vyshyvanka.webp")).convert("RGB")
    save(band(b, (97, 307)), OUT / "ui" / "band_top.png")
    save(band(b, (1228, 1435)), OUT / "ui" / "band_bottom.png")

    print("Дерев'яна рамка")
    f = np.array(Image.open(find("frame_wood.webp")).convert("RGB")).astype(np.float32)
    h, w, _ = f.shape
    mx, mn = f.max(axis=2), f.min(axis=2)
    lum = f.mean(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    cream = (sat < 0.30) & (lum > 52)
    lab, _ = ndimage.label(cream)
    inner = lab == lab[h // 2, w // 2]
    inner = ndimage.binary_dilation(inner, iterations=3)
    # зовнішнє біле тло (кути) -> прозоре
    white = (lum > 150) & (sat < 0.22)
    lab2, _ = ndimage.label(white)
    outer = np.zeros_like(white)
    border_labels = set(np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]]))) - {0}
    for lb in border_labels:
        outer |= lab2 == lb
    outer = ndimage.binary_dilation(outer, iterations=4)
    # внутрішність -> темна тепла панель із м'якою внутрішньою тінню
    panel = np.array([42, 34, 34], np.float32)
    shade = np.clip(lum / 230.0, 0.45, 1.0)[..., None]
    out = f.copy()
    out[inner] = (panel * shade)[inner]
    alpha = np.full((h, w), 255, np.float32)
    alpha[inner] = 245
    alpha[outer] = 0
    rgba = np.dstack([out, alpha]).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    save(im.resize((384, 384), Image.LANCZOS), OUT / "ui" / "frame_wood.png")


if __name__ == "__main__":
    main()
