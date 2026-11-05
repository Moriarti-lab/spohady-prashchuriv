#!/usr/bin/env python3
"""Overview PNG of perk_tree.json — Yggdrasil silhouette check."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "data" / "perk_tree.json").read_text())
META = json.loads((ROOT / "data" / "perk_tree_meta.json").read_text())
OUT = Path("/workspace/spohady-tree-v4-full.png")

W, H = 1600, 1600
PAD = 60
nodes = {n["id"]: n for n in DATA["nodes"]}
xs = [n["x"] for n in nodes.values()]
ys = [n["y"] for n in nodes.values()]
xmin, xmax = min(xs), max(xs)
ymin, ymax = min(ys), max(ys)
# y grows downward on screen, but tree y: larger = roots (bottom)
# map tree y so ymax (roots) → bottom of image, ymin (crown) → top

def to_px(x, y):
    nx = PAD + (x - xmin) / max(xmax - xmin, 1) * (W - 2 * PAD)
    # invert: small tree-y (crown) at top of image
    ny = PAD + (y - ymin) / max(ymax - ymin, 1) * (H - 2 * PAD)
    return nx, ny

COLS = {"str": (216, 87, 75), "agi": (124, 191, 90), "faith": (224, 165, 38)}
BARK = (90, 64, 48)

im = Image.new("RGB", (W, H), (12, 10, 11))
dr = ImageDraw.Draw(im, "RGBA")

# soft region glows near starts
for reg, cid in DATA["class_starts"].items():
    # class_starts maps class→id; use regions
    pass
for reg, sid in [("str", "s_root"), ("agi", "a_root"), ("faith", "f_root")]:
    if sid not in nodes:
        continue
    px, py = to_px(nodes[sid]["x"], nodes[sid]["y"])
    col = COLS[reg] + (28,)
    for r in (220, 140):
        dr.ellipse([px - r, py - r, px + r, py + r], fill=COLS[reg] + (18,))

# band labels
layout = META.get("layout", {})
bands = layout.get("bands", [])
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
    font_sm = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    font_lg = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)
except Exception:
    font = font_sm = font_lg = ImageFont.load_default()

for b in bands:
    _, y0 = to_px(0, b["y0"])
    _, y1 = to_px(0, b["y1"])
    mid = (y0 + y1) / 2
    dr.line([(20, y0), (20, y1)], fill=(200, 180, 100, 80), width=2)
    dr.text((28, mid - 8), b["name"], fill=(200, 180, 100, 180), font=font_sm)

# links: thickness by trunkness (near x=0 and mid y)
for a, b in DATA["links"]:
    na, nb = nodes[a], nodes[b]
    ax, ay = to_px(na["x"], na["y"])
    bx, by = to_px(nb["x"], nb["y"])
    mid_x = (na["x"] + nb["x"]) * 0.5
    mid_y = (na["y"] + nb["y"]) * 0.5
    trunkness = max(0.0, 1.0 - abs(mid_x) / 420.0)
    height_t = max(0.0, min(1.0, (2600.0 - mid_y) / 5200.0))
    w = 1.2 + 4.5 * trunkness * (1.0 - height_t * 0.55)
    ca = COLS.get(na["region"], (150, 150, 150))
    cb = COLS.get(nb["region"], (150, 150, 150))
    col = tuple(int((ca[i] + cb[i]) / 2 * 0.55 + BARK[i] * 0.45) for i in range(3)) + (200,)
    dr.line([(ax, ay), (bx, by)], fill=col, width=max(1, int(round(w))))

# nodes
RAD = {"small": 5, "notable": 10, "keystone": 13, "start": 14, "core": 16, "skill": 9}
labeled = []  # (x,y,w,h) for collision

def can_label(px, py, tw, th):
    box = (px - 4, py - th - 2, tw + 8, th + 4)
    for x, y, w, h in labeled:
        if not (box[0] + box[2] < x or x + w < box[0] or box[1] + box[3] < y or y + h < box[1]):
            return False
    return True

for n in nodes.values():
    px, py = to_px(n["x"], n["y"])
    r = RAD.get(n["type"], 5)
    col = COLS.get(n["region"], (180, 180, 180))
    if n["type"] in ("notable", "keystone", "start", "core"):
        dr.ellipse([px - r - 2, py - r - 2, px + r + 2, py + r + 2], outline=(240, 210, 140, 200), width=2)
    dr.ellipse([px - r, py - r, px + r, py + r], fill=col + (255,))

# labels for important nodes only, collision-avoided
important = [n for n in nodes.values() if n["type"] in ("start", "core", "notable", "keystone")]
important.sort(key=lambda n: (0 if n["type"] in ("core", "start") else 1, n["y"]))
for n in important:
    px, py = to_px(n["x"], n["y"])
    label = n["name"]
    if n["type"] == "notable":
        label = "Плід: " + label
    bbox = dr.textbbox((0, 0), label, font=font_sm)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    lx, ly = px - tw / 2, py - RAD.get(n["type"], 8) - th - 6
    # try offsets if collision
    placed = False
    for dx, dy in [(0, 0), (20, -8), (-20, -8), (30, 10), (-30, 10), (0, 18)]:
        if can_label(lx + dx, ly + dy, tw, th):
            dr.text((lx + dx, ly + dy), label, fill=(240, 230, 200, 230), font=font_sm)
            labeled.append((lx + dx, ly + dy, tw, th))
            placed = True
            break
    # if can't place without overlap, skip (avoid crowded strip)

# title + legend
dr.text((PAD, 18), "Древо звитяги v4 — повний огляд (коріння внизу → крона вгорі)", fill=(240, 200, 100), font=font_lg)
leg_y = H - 48
for i, (reg, name) in enumerate([("str", "Сила"), ("agi", "Спритність"), ("faith", "Віра")]):
    x = PAD + i * 180
    dr.ellipse([x, leg_y, x + 16, leg_y + 16], fill=COLS[reg])
    dr.text((x + 24, leg_y - 2), name, fill=(220, 210, 190), font=font)
dr.text((W // 2 - 80, H - 48), f"· {len(nodes)} вузлів · один стовбур", fill=(160, 150, 140), font=font_sm)

im.save(OUT)
print("wrote", OUT, "nodes", len(nodes))
